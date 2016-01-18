# Recipe:: multidaemon
#
# Author:: Opsline
#
# Copyright 2015, OpsLine, LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# make sure we've installed openvpn with a single daemon running for global user access
include_recipe 'opsline-openvpn::default'

node['opsline-openvpn']['multidaemon']['daemons'].each { |k,v|

  # clone the default server config to get common attributes for this daemon's server_*.conf template
  config = node['openvpn']['config'].dup

  # import default routes
  routes = []
  routes << node['openvpn']['push_routes']
  # get custom routes for this daemon; flatten routes array later
  routes << v['push_routes']

  # custom key dir for this daemon
  key_dir  = "/etc/openvpn/keys_#{k}"

  # restore server keys
  opsline_openvpn_server_keys 'restore #{k} openvpn server keys' do
    databag_item k
    key_dir key_dir
    action :create
  end

  config.store('dev', "#{v['device']}")
  config.store('ca', "#{key_dir}/ca.crt")
  config.store('key', "#{key_dir}/server.key")
  config.store('cert', "#{key_dir}/server.crt")
  config.store('dh', "#{key_dir}/dh#{node['openvpn']['key']['size']}.pem")
  config.store('log', "/var/log/openvpn_#{k}.log")
  config.store('server', "#{v['subnet']} #{v['netmask']}")
  config.store('port', "#{v['port']}")


  # create custom server.conf using custom opsline_openvpn_conf provider
  opsline_openvpn_conf "server_#{k}" do
    config config
    push_routes routes.flatten!.sort!
    push_options node['openvpn']['push_options']
    notifies :restart, 'service[openvpn]'
  end

  # calculate source CIDR for this openvpn daemon
  cidr_mask = IPAddr.new("#{v['netmask']}").to_i.to_s(2).count("1")
  source_cidr = "#{v['subnet']}/#{cidr_mask}"
  log "Using source CIDR: #{source_cidr} for openvpn daemon '#{k}'"

  iptables_rule "openvpn_#{k}" do
    source 'openvpn.erb'
    variables({
      :source_cidr => source_cidr
    })
  end

  opsline_openvpn_user_keys "user keys for openvpn daemon '#{k}'" do
    user_databag 'users'
    user_query "groups:#{v['allowed_group']}"
    key_dir key_dir
    instance k
    port "#{v['port']}".to_i
  end

}
