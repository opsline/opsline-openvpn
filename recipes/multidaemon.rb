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
  key_size = node['openvpn']['key']['size']

  directory key_dir do
    owner 'root'
    group 'root'
    mode  '0700'
  end

  template "#{key_dir}/openssl.cnf" do
    source 'openssl.cnf.erb'
    cookbook 'openvpn'
    owner 'root'
    group 'root'
    mode  '0644'
    variables(
      :key_dir => "#{key_dir}"
    )
  end

  file "#{key_dir}/index.txt" do
    owner 'root'
    group 'root'
    mode  '0600'
    action :create
  end

  file "#{key_dir}/serial" do
    content '01'
    not_if { ::File.exists?("#{key_dir}/serial") }
  end

  # Use unless instead of not_if otherwise OpenSSL::PKey::DH runs every time.
  unless ::File.exists?("#{key_dir}/dh#{key_size}.pem")
    require 'openssl'
    file "#{key_dir}/dh#{key_size}.pem" do
      content OpenSSL::PKey::DH.new(key_size).to_s
      owner 'root'
      group 'root'
      mode  '0600'
    end
  end

  # this should never run as default recipe has already created the CA signing cert
  bash 'openvpn-initca' do
    environment('KEY_CN' => "#{node['openvpn']['key']['org']} CA")
    code <<-EOF
      openssl req -batch -days #{node["openvpn"]["key"]["ca_expire"]} \
        -nodes -new -newkey rsa:#{key_size} -sha1 -x509 \
        -keyout #{node["openvpn"]["signing_ca_key"]} \
        -out #{node["openvpn"]["signing_ca_cert"]} \
        -config #{key_dir}/openssl.cnf
    EOF
    not_if { ::File.exists?(node['openvpn']['signing_ca_cert']) }
  end

  # create custom server cert
  bash 'openvpn-server-key' do
    environment('KEY_CN' => "server_#{k}")
    code <<-EOF
      openssl req -batch -days #{node["openvpn"]["key"]["expire"]} \
        -nodes -new -newkey rsa:#{key_size} -keyout #{key_dir}/server.key \
        -out #{key_dir}/server.csr -extensions server \
        -config #{key_dir}/openssl.cnf && \
      openssl ca -batch -days #{node["openvpn"]["key"]["ca_expire"]} \
        -out #{key_dir}/server.crt -in #{key_dir}/server.csr \
        -extensions server -md sha1 -config #{key_dir}/openssl.cnf
    EOF
    not_if { ::File.exists?("#{key_dir}/server.crt") }
  end

  # copy the CA cert to each daemon's keys dir to be included in user config tarball
  file "#{key_dir}/ca.crt" do
    content lazy { IO.read("#{node["openvpn"]["signing_ca_cert"]}") }
    action :create
    owner 'root'
    group 'root'
  end

  # copy the CA key to each daemon's keys dir for generating user keys
  file "#{key_dir}/ca.key" do
    content lazy { IO.read("#{node["openvpn"]["signing_ca_key"]}") }
    action :create
    owner 'root'
    group 'root'
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

  opsline_openvpn_user_keys "Restore user keys from databag for openvpn daemon '#{k}'" do
    user_databag 'users'
    user_query "groups:#{v['allowed_group']}"
    key_dir "#{key_dir}"
    bucket_dir "#{k}"
    port "#{v['port']}".to_i
  end

}
