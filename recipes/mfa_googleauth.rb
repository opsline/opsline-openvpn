# Recipe:: mfa_googleauth
#
# Author:: Opsline
#
# Copyright 2017, OpsLine, LLC.
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

package 'libpam-google-authenticator'
node.override['openvpn']['config']['plugin'] = ['/usr/lib/openvpn/openvpn-plugin-auth-pam.so openvpn']
cookbook_file '/etc/pam.d/openvpn' do
  source 'openvpn'
  mode 0644
  action :create
end

directory '/etc/ga' do
  owner 'root'
  group 'root'
  mode 0777
  action :create
end
