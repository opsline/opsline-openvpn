# Recipe:: users
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

def chef_solo_search_installed?
  klass = ::Search.const_get('Helper')
  return klass.is_a?(Class)
rescue NameError
  return false
end

if Chef::Config[:solo] && !chef_solo_search_installed?
  Chef::Log.warn('This recipe uses search. Chef-Solo does not support search unless '\
    'you install the chef-solo-search cookbook.')
else
  search('users', node['openvpn']['user_query']) do |u|

    if u.has_key?('action') and u['action'] == "remove"
      user_action = :delete
    else
      user_action = :create
    end

    execute "generate-openvpn-#{u['id']}" do
      command "./pkitool #{u['id']}"
      cwd '/etc/openvpn/easy-rsa'
      environment(
        'EASY_RSA'     => '/etc/openvpn/easy-rsa',
        'KEY_CONFIG'   => '/etc/openvpn/easy-rsa/openssl.cnf',
        'KEY_DIR'      => node['openvpn']['key_dir'],
        'CA_EXPIRE'    => node['openvpn']['key']['ca_expire'].to_s,
        'KEY_EXPIRE'   => node['openvpn']['key']['expire'].to_s,
        'KEY_SIZE'     => node['openvpn']['key']['size'].to_s,
        'KEY_COUNTRY'  => node['openvpn']['key']['country'],
        'KEY_PROVINCE' => node['openvpn']['key']['province'],
        'KEY_CITY'     => node['openvpn']['key']['city'],
        'KEY_ORG'      => node['openvpn']['key']['org'],
        'KEY_EMAIL'    => node['openvpn']['key']['email']
      )
      not_if { ::File.exist?("#{node['openvpn']['key_dir']}/#{u['id']}.crt") or user_action == :delete }
    end

    begin
      user_cert = Chef::EncryptedDataBagItem.load(node['opsline-openvpn']['persistence']['users_databag'], u['id'])
    rescue
      Chef::Log.warn("Missing #{node['opsline-openvpn']['persistence']['users_databag']}:#{u['id']} databag item")
    else
      file "#{node['openvpn']['key_dir']}/#{u['id']}.crt" do
        content "#{user_cert['crt']}"
        owner 'root'
        group 'root'
        mode  '0644'
        action user_action
      end
      file "#{node['openvpn']['key_dir']}/#{u['id']}.csr" do
        content "#{user_cert['csr']}"
        owner 'root'
        group 'root'
        mode  '0644'
        action user_action
      end
      file "#{node['openvpn']['key_dir']}/#{u['id']}.key" do
        content "#{user_cert['key']}"
        owner 'root'
        group 'root'
        mode  '0600'
        action user_action
      end
    end

    %w(conf ovpn).each do |ext|
      template "#{node['openvpn']['key_dir']}/#{u['id']}.#{ext}" do
        source 'client.conf.erb'
        variables(username: u['id'])
        action user_action
      end
    end

    tar_file = "#{u['id']}.tar.gz"
    tar_cmd = "tar zcf #{tar_file} ca.crt #{u['id']}.crt #{u['id']}.key #{u['id']}.conf #{u['id']}.ovpn"
    if node['opsline-openvpn']['tls_key']
      tar_cmd += " #{node['opsline-openvpn']['tls_key']}"
    end
    execute "create-openvpn-tar-#{u['id']}" do
      cwd node['openvpn']['key_dir']
      command tar_cmd
      action :run
      not_if { user_action == :delete  }
    end
    file tar_file do
      action :delete
      only_if { user_action == :delete }
    end
  end

  # sync users' vpn keysets to s3 for easy distribution
  execute "sync-openvpn-keys-to-s3" do
    cwd node['openvpn']['key_dir']
    command "aws s3 sync #{node['openvpn']['key_dir']} s3://#{node['opsline-openvpn']['users']['s3bucket']} --sse --delete --exclude '*' --include '*.tar.gz'"
    not_if { node['opsline-openvpn']['users']['s3bucket'].nil? }
  end
end
