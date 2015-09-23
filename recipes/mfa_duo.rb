# Recipe:: mfa_duo
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

# install Duo Security MFA plugin
execute "install-duo-mfa-plugin" do
  cwd '/etc/openvpn'
  command <<-EOH
    wget https://github.com/duosecurity/duo_openvpn/tarball/master -O duo.tar.gz
    tar zxf duo.tar.gz
    cd duosecurity-duo_openvpn*
    make && make install
  EOH
  not_if { ::File.exist?("/etc/openvpn/duo.tar.gz") }
end

plugin_file = '/opt/duo/duo_openvpn.so'
duo_params = Chef::EncryptedDataBagItem.load(node['opsline-openvpn']['mfa']['databag'], 'duo').to_hash

node.override['openvpn']['config']['plugin'] = [ "#{plugin_file} #{duo_params['integration_key']} #{duo_params['secret_key']} #{duo_params['api_host']}" ]
node.override['openvpn']['config']['reneg-sec'] = node['opsline-openvpn']['mfa']['reneg-sec']
