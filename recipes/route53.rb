# Recipe:: route53
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

if node['opsline-openvpn']['route53']['zone_id']
  openvpn_hostname = "#{node['opsline-openvpn']['route53']['cname_prefix']}.#{node['opsline-openvpn']['route53']['domain_name']}"

  # set the gateway to our IP address
  node.override['openvpn']['gateway'] = openvpn_hostname

  # update CNAME record upon new vpn instance launch
  route53_record 'create vpn cname' do
    name openvpn_hostname
    value node['ec2']['public_ipv4']
    type 'A'
    zone_id node['opsline-openvpn']['route53']['zone_id']
    ttl 60
    overwrite true
    action :create
  end
else
  # set the gateway to our IP address
  node.override['openvpn']['gateway'] = node['ec2']['public_ipv4']
end
