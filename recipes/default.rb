#
# Cookbook Name:: opsline-chef-client
# Recipe:: default
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

# disable server.conf creation by openvpn::default recipe
# config will be created at the end of this recipe using LWRP
node.override['openvpn']['configure_default_server'] = false

# install openvpn server
include_recipe 'openvpn::server'

# route53
include_recipe 'opsline-openvpn::route53'

# tls auth
include_recipe 'opsline-openvpn::tls_auth'

# mfa
include_recipe 'opsline-openvpn::mfa'

# restore server keys
include_recipe 'opsline-openvpn::persistence'

# set some good-to-have parameters
node.override['openvpn']['config']['up'] = '/etc/openvpn/server.up.sh'
node.override['openvpn']['config']['ifconfig-pool-persist'] = '/etc/openvpn/ipp.txt'
node.override['openvpn']['config']['status'] = '/var/log/openvpn-status.log'
node.override['openvpn']['config']['verb'] = '4'
node.override['openvpn']['config']['mute'] = '10'

# configure openvpn server
openvpn_conf 'server' do
  notifies :restart, 'service[openvpn]'
end

# configure users
include_recipe 'opsline-openvpn::users'

# iptables
include_recipe 'iptables'
iptables_rule 'openvpn' do
  variables({
    :source_cidr => node['opsline-openvpn']['source_cidr']
  })
end
