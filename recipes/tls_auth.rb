# Recipe:: tls_auth
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

if node['opsline-openvpn']['tls_key']

  tls_key_file = "#{node['openvpn']['key_dir']}/#{node['opsline-openvpn']['tls_key']}"

  execute 'generate tls key' do
    command "openvpn --genkey --secret #{tls_key_file}"
    action :run
    not_if { ::File.exist?(tls_key_file) }
  end

  node.override['openvpn']['config']['tls-auth'] = [ "#{tls_key_file} 0" ]
end
