#
# Cookbook Name:: opsline-openvpn
# Provider:: user_keys
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

  search(new_resource.user_databag, new_resource.user_query) do |u|

    if u.has_key?('action') and u['action'] == "remove"
      user_action = :delete
    else
      user_action = :create
    end

    if new_resource.instance.nil?
      databag_item_name = u['id']
    else
      databag_item_name = "#{new_resource.instance}_#{u['id']}"
    end

    begin
      persisted_certs = Chef::EncryptedDataBagItem.load(node['opsline-openvpn']['users_databag'], databag_item_name)
    rescue
      Chef::Log.warn("Missing #{node['opsline-openvpn']['users_databag']}:#{databag_item_name} databag item")
      persisted_certs = nil
    end

    unless persisted_certs.nil?
      log "restoring user keys for #{databag_item_name}"
      file "#{new_resource.key_dir}/#{databag_item_name}.crt" do
        content "#{persisted_certs['crt']}"
        owner 'root'
        group 'root'
        mode  '0644'
        action user_action
      end
      file "#{new_resource.key_dir}/#{databag_item_name}.csr" do
        content "#{persisted_certs['csr']}"
        owner 'root'
        group 'root'
        mode  '0644'
        action user_action
      end
      file "#{new_resource.key_dir}/#{databag_item_name}.key" do
        content "#{persisted_certs['key']}"
        owner 'root'
        group 'root'
        mode  '0600'
        action user_action
      end
    else
      if user_action == :delete
        log "deleting user keys for #{databag_item_name}"
        %w(crt csr key).each do |ext|
          file "#{new_resource.key_dir}/#{databag_item_name}.#{ext}" do
            action user_action
          end
        end
      else
        log "generating new user keys for #{databag_item_name}"
        execute "generate-openvpn-#{databag_item_name}" do
          command "./pkitool #{databag_item_name}"
          cwd '/etc/openvpn/easy-rsa'
          environment(
            'EASY_RSA'     => '/etc/openvpn/easy-rsa',
            'KEY_CONFIG'   => '/etc/openvpn/easy-rsa/openssl.cnf',
            'KEY_DIR'      => new_resource.key_dir,
            'CA_EXPIRE'    => node['openvpn']['key']['ca_expire'].to_s,
            'KEY_EXPIRE'   => node['openvpn']['key']['expire'].to_s,
            'KEY_SIZE'     => node['openvpn']['key']['size'].to_s,
            'KEY_COUNTRY'  => node['openvpn']['key']['country'],
            'KEY_PROVINCE' => node['openvpn']['key']['province'],
            'KEY_CITY'     => node['openvpn']['key']['city'],
            'KEY_ORG'      => node['openvpn']['key']['org'],
            'KEY_EMAIL'    => node['openvpn']['key']['email']
          )
          not_if { ::File.exist?("#{new_resource.key_dir}/#{databag_item_name}.crt") }
        end
      end
    end

    %w(conf ovpn).each do |ext|
      log "generating new user config files for #{databag_item_name}"
      template "#{new_resource.key_dir}/#{databag_item_name}.#{ext}" do
        source 'client.conf.erb'
        variables(
          username: databag_item_name,
          port: new_resource.port
        )
        action user_action
      end
    end

    tar_file = "#{databag_item_name}.tar.gz"
    tar_cmd = "tar zcf #{tar_file} ca.crt #{databag_item_name}.crt #{databag_item_name}.key #{databag_item_name}.conf #{databag_item_name}.ovpn"
    if node['opsline-openvpn']['tls_key']
      tar_cmd += " #{node['opsline-openvpn']['tls_key']}"
    end
    execute "create-openvpn-tar-#{databag_item_name}" do
      cwd new_resource.key_dir
      command tar_cmd
      action :run
      not_if { user_action == :delete }
    end
    file tar_file do
      action :delete
      only_if { user_action == :delete }
    end
  end

  # sync users' vpn keysets to s3 for easy distribution
  s3_dir = new_resource.instance.nil? ? '' : new_resource.instance
  execute "sync-openvpn-keys-to-s3" do
    cwd new_resource.key_dir
    command "aws s3 sync #{new_resource.key_dir} s3://#{node['opsline-openvpn']['users']['s3bucket']}/#{s3_dir} --sse --delete --exclude '*' --include '*.tar.gz'"
    not_if { node['opsline-openvpn']['users']['s3bucket'].nil? }
  end

end
