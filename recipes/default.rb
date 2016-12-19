#
# Cookbook Name:: opsline-openvpn
# Recipe:: default
#
# Author:: Opsline
#
# Copyright 2016, OpsLine, LLC.
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

include_recipe 'iptables'

# required for calculating source CIDR
require 'ipaddr'

# disable server.conf creation by openvpn::default recipe
# openvpn server configs will be created via opsline_openvpn_conf LWRP
node.override['openvpn']['configure_default_server'] = false

# install openvpn package
include_recipe 'openvpn::install'

# setup DNS for the openvpn host
include_recipe 'opsline-openvpn::route53'

# optional mfa setup
if node['opsline-openvpn']['mfa']['enabled']
  include_recipe "opsline-openvpn::mfa_#{node['opsline-openvpn']['mfa']['type']}"
end

# set some good-to-have parameters common to all daemons
node.set['openvpn']['config']['verb'] = '4'
node.set['openvpn']['config']['mute'] = '5'
node.set['openvpn']['config']['log'] = node['opsline-openvpn']['log']

# in the case the key size is provided as string, no integer support in metadata (CHEF-4075)
node.override['openvpn']['key']['size'] = node['openvpn']['key']['size'].to_i

# setup each openvpn server daemon
node['opsline-openvpn']['daemons'].each do |k, v|
  # clone the default server config to get common attributes for this daemon's server_*.conf template
  config = node['openvpn']['config'].dup

  # import default routes
  routes = []
  routes << node['openvpn']['push_routes']
  # get custom routes for this daemon; flatten routes array later
  routes << v['push_routes'] unless v['push_routes'] == nil

  # custom key dir for this daemon
  base_dir  = "/etc/openvpn_#{k}"
  key_dir = "#{base_dir}/keys"

  config.store('dev', "#{v['device']}")
  config.store('ca', "#{key_dir}/ca.crt")
  config.store('key', "#{key_dir}/server.key")
  config.store('cert', "#{key_dir}/server.crt")
  config.store('dh', "#{key_dir}/dh#{node['openvpn']['key']['size']}.pem")
  config.store('server', "#{v['subnet']} #{v['netmask']}")
  config.store('port', "#{v['port']}")
  config.store('ifconfig-pool-persist', "#{base_dir}/ipp.txt")
  config.store('up', "#{base_dir}/server.up.sh")
  config.store('status', "/var/log/openvpn-status_#{k}.log")

  # optional tls setup
  if node['opsline-openvpn']['tls_key']
    config.store('tls-auth', "#{key_dir}/#{node['opsline-openvpn']['tls_key']} 0")
  end

  # create custom server.conf using custom opsline_openvpn_conf provider
  opsline_openvpn_conf "server_#{k}" do
    type 'server'
    base_dir base_dir
    config config
    push_routes routes.flatten!.sort!
    push_options node['openvpn']['push_options']
    notifies :restart, 'service[openvpn]'
  end

  # restore server keys
  opsline_openvpn_server_keys "openvpn_server_keys_#{k}" do
    databag_item k
    base_dir base_dir
    action :create
  end

  # calculate source CIDR for this openvpn daemon
  cidr_mask = IPAddr.new("#{v['netmask']}").to_i.to_s(2).count("1")
  source_cidr = "#{v['subnet']}/#{cidr_mask}"
  log "Using source CIDR: #{source_cidr} for openvpn daemon: #{k}"

  # install NAT POSTROUTING iptables rule to set masquerade source CIDR for vpn clients
  iptables_rule "openvpn_#{k}" do
    source 'openvpn.erb'
    variables({
      :source_cidr => source_cidr
    })
  end

  opsline_openvpn_user_keys "openvpn_user_keys_daemon_#{k}" do
    user_databag node['opsline-openvpn']['users']['databag']
    user_query "#{node['opsline-openvpn']['users']['search_key']}:#{k}"
    base_dir base_dir
    instance k
    port "#{v['port']}".to_i
  end

  monitrc "openvpn_server_#{k}" do
    action v['monit'] ? :enable : :disable
    template_cookbook "opsline-openvpn"
    template_source "monit.conf.erb"
    variables({
      :daemon_name => "openvpn_server_#{k}",
      :pid_file => "/run/openvpn/server_#{k}.pid"
    })
  end
end

# setup each openvpn server daemon
node['opsline-openvpn']['clients'].each do |k, v|
  # clone config
  config = v.dup

  # custom key dir for this daemon
  base_dir = "/etc/openvpn_#{k}"

  config['base_dir'] = base_dir
  config['tls_key'] = node['opsline-openvpn']['tls_key']

  opsline_openvpn_conf "client_#{k}" do
    type 'client'
    base_dir base_dir
    config config
    notifies :restart, 'service[openvpn]'
  end

  opsline_openvpn_user_keys "openvpn_user_keys_client_#{k}" do
    user_databag node['opsline-openvpn']['users']['databag']
    user_query "#{node['opsline-openvpn']['users']['search_key']}:#{k}"
    base_dir base_dir
    instance config['user_instance']
    port "#{v['port']}".to_i
    create_config false
    upload_config false
  end

  monitrc "openvpn_client_#{k}" do
    action v['monit'] ? :enable : :disable
    template_cookbook "opsline-openvpn"
    template_source "monit.conf.erb"
    variables({
      :daemon_name => "openvpn_client_#{k}",
      :pid_file => "/run/openvpn/client_#{k}.pid"
    })
  end
end

include_recipe 'openvpn::service'
