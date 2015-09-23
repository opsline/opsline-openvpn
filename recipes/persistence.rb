# Recipe:: persistence
#
# Author:: Opsline
#
# Copyright 2014, OpsLine, LLC.
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

begin
  openvpn_conf = Chef::EncryptedDataBagItem.load(node['opsline-openvpn']['persistence']['keys_databag'], 'default')
rescue
  Chef::Log.warn("Missing #{node['opsline-openvpn']['persistence']['keys_databag']}:default databag item")
  return
end

key_dir = node['openvpn']['key_dir']

file "#{key_dir}/ca.crt" do
  content openvpn_conf['ca_crt']
  owner 'root'
  group 'root'
  mode  '0644'
end
file "#{key_dir}/ca.key" do
  content openvpn_conf['ca_key']
  owner 'root'
  group 'root'
  mode  '0644'
end
file "#{key_dir}/dh#{node[openvpn][key][size]}.pem" do
  content openvpn_conf['dh']
  owner 'root'
  group 'root'
  mode  '0600'
end
file "#{key_dir}/server.crt" do
  content openvpn_conf['server_crt']
  owner 'root'
  group 'root'
  mode  '0644'
end
file "#{key_dir}/server.csr" do
  content openvpn_conf['server_csr']
  owner 'root'
  group 'root'
  mode  '0644'
end
file "#{key_dir}/server.key" do
  content openvpn_conf['server_key']
  owner 'root'
  group 'root'
  mode  '0600'
end
file "#{key_dir}/#{node['opsline-openvpn']['tls_key']}" do
  content openvpn_conf['tls_key']
  owner 'root'
  group 'root'
  mode  '0600'
  only_if { openvpn_conf.has_key?('tls_key') }
end
