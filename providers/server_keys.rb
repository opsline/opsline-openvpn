#
# Cookbook Name:: opsline-openvpn
# Provider:: server_keys
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

use_inline_resources

action :create do

  begin
    server_keys_databag_item = Chef::EncryptedDataBagItem.load(node['opsline-openvpn']['keys_databag'], new_resource.databag_item).to_hash
    log "using #{node['opsline-openvpn']['keys_databag']}:#{new_resource.databag_item} databag item for openvpn server keys"
  rescue
    Chef::Log.warn("Missing #{node['opsline-openvpn']['keys_databag']}:#{new_resource.databag_item} databag item")
    return
  end

  key_dir = new_resource.key_dir

  file "#{key_dir}/ca.crt" do
    content server_keys_databag_item['ca_crt']
    owner 'root'
    group 'root'
    mode  '0644'
  end
  file "#{key_dir}/ca.key" do
    content server_keys_databag_item['ca_key']
    owner 'root'
    group 'root'
    mode  '0644'
  end
  file "#{key_dir}/dh#{node['openvpn']['key']['size']}.pem" do
    content server_keys_databag_item['dh']
    owner 'root'
    group 'root'

    mode  '0600'
  end
  file "#{key_dir}/server.crt" do
    content server_keys_databag_item['server_crt']
    owner 'root'
    group 'root'
    mode  '0644'
  end
  file "#{key_dir}/server.csr" do
    content server_keys_databag_item['server_csr']
    owner 'root'
    group 'root'
    mode  '0644'
  end
  file "#{key_dir}/server.key" do
    content server_keys_databag_item['server_key']
    owner 'root'
    group 'root'
    mode  '0600'
  end
  file "#{key_dir}/#{node['opsline-openvpn']['tls_key']}" do
    content server_keys_databag_item['tls_key']
    owner 'root'
    group 'root'
    mode  '0600'
    only_if { server_keys_databag_item.has_key?('tls_key') }
  end

end
