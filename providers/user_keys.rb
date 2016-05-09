#
# Cookbook Name:: opsline-openvpn
# Provider:: user_keys
#
# Author:: Opsline
#
# Copyright 2016, OpsLine, LLC.
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

  # create client.pem from databag and save it to disk
  client_key_file = "/etc/chef/#{node['opsline-openvpn']['persistence']['admin_client_name']}.pem"

  creds = Chef::EncryptedDataBagItem.load(node['opsline-openvpn']['persistence']['admin_data_bag'], node['opsline-openvpn']['persistence']['admin_client_name'])
  client_username = creds['username']
  file client_key_file do
    content creds['private_key']
    owner 'root'
    group 'root'
    mode 0600
  end

  key_dir = "#{new_resource.base_dir}/keys"

  log "Searching for users with query filter #{new_resource.user_query} in data bag #{new_resource.user_databag}"
  search(new_resource.user_databag, new_resource.user_query) do |u|

    if u.has_key?('action') and u['action'] == "remove"
      user_action = :delete
    else
      user_action = :create
    end

    log "Found user #{u} with action:#{user_action}"

    username = u['id'] # client CN must match user data bag name to successfully authenticate with Duo MFA auth

    if new_resource.instance.nil?
      databag_item = username
    else
      databag_item = "#{new_resource.instance}_#{username}"
    end

    begin
      log "searching for persisted user keys in #{node['opsline-openvpn']['persistence']['users_databag']}:#{databag_item} databag item"
      persisted_certs = Chef::EncryptedDataBagItem.load(node['opsline-openvpn']['persistence']['users_databag'], databag_item)
    rescue
      persisted_certs = nil
      log "Persisted openvpn user keys do not exist in #{node['opsline-openvpn']['persistence']['users_databag']}:#{databag_item} databag item"
      log "New openvpn user keys will be generated and saved to #{node['opsline-openvpn']['persistence']['users_databag']}:#{databag_item} databag item"

      # generate new user keys
      log "generating new openvpn user keys for #{username} for #{new_resource.instance} openvpn daemon"
      execute "generate-openvpn-#{databag_item}" do
        command "./pkitool #{username}"
        cwd "#{new_resource.base_dir}/easy-rsa"
        environment(
          'KEY_CN'       => "#{node['openvpn']['key']['org']} #{new_resource.instance} CA",
          'EASY_RSA'     => "#{new_resource.base_dir}/easy-rsa",
          'KEY_CONFIG'   => "#{new_resource.base_dir}/easy-rsa/openssl.cnf",
          'KEY_DIR'      => key_dir,
          'CA_EXPIRE'    => node['openvpn']['key']['ca_expire'].to_s,
          'KEY_EXPIRE'   => node['openvpn']['key']['expire'].to_s,
          'KEY_SIZE'     => node['openvpn']['key']['size'].to_s,
          'KEY_COUNTRY'  => node['openvpn']['key']['country'],
          'KEY_PROVINCE' => node['openvpn']['key']['province'],
          'KEY_CITY'     => node['openvpn']['key']['city'],
          'KEY_ORG'      => node['openvpn']['key']['org'],
          'KEY_EMAIL'    => node['openvpn']['key']['email']
        )
        not_if { ::File.exist?("#{key_dir}/#{username}.crt") }
      end

      log "building #{databag_item}.json file to be uploaded to data bag #{node['opsline-openvpn']['persistence']['users_databag']}"
      ruby_block "read keys" do
        block do
          ::File.open("#{key_dir}/#{databag_item}.json", "w") do |f|
            f.puts ("{ \"id\": \"#{databag_item}\",")
            f.puts ("\"crt\": \"#{::File.open("#{key_dir}/#{username}.crt", "r").read().gsub(/\n/,"\\n")}\",")
            f.puts ("\"csr\": \"#{::File.open("#{key_dir}/#{username}.csr", "r").read().gsub(/\n/,"\\n")}\",")
            f.puts ("\"key\": \"#{::File.open("#{key_dir}/#{username}.key", "r").read().gsub(/\n/,"\\n")}\"}")
          end
        end
      end
    
      require 'chef/knife' # for executing below knife command to upload data bag items

      execute "persisting #{databag_item}.json to data bag item #{node['opsline-openvpn']['persistence']['users_databag']}:#{databag_item}" do
        command "knife data bag from file #{node['opsline-openvpn']['persistence']['users_databag']} #{key_dir}/#{databag_item}.json --secret-file /etc/chef/encrypted_data_bag_secret -c /etc/chef/client.rb -u #{client_username} -k #{client_key_file}"
      end

      # delete the json file just created
      file "#{key_dir}/#{databag_item}.json" do
        action :delete
      end
    end # end of rescue block

    unless persisted_certs.nil?
      log "Restoring persisted user keys found in #{node['opsline-openvpn']['persistence']['users_databag']}:#{databag_item} databag item"
      file "#{key_dir}/#{username}.crt" do
        content persisted_certs['crt']
        owner 'root'
        group 'root'
        mode  '0644'
        action user_action
      end
      file "#{key_dir}/#{username}.csr" do
        content persisted_certs['csr']
        owner 'root'
        group 'root'
        mode  '0644'
        action user_action
      end
      file "#{key_dir}/#{username}.key" do
        content persisted_certs['key']
        owner 'root'
        group 'root'
        mode  '0600'
        action user_action
      end
    else
      if user_action == :delete
        %w(crt csr key).each do |ext|
          file "#{key_dir}/#{username}.#{ext}" do
            action user_action
          end
        end

        # delete the persisted user keys from the data bag
        execute "deleting persisted #{node['opsline-openvpn']['persistence']['users_databag']}:#{databag_item} data bag item" do
          command "knife data bag delete #{node['opsline-openvpn']['persistence']['users_databag']} #{databag_item} --secret-file /etc/chef/encrypted_data_bag_secret  -c /etc/chef/client.rb -u #{node['opsline-openvpn']['persistence']['admin_client_name']} -k #{client_key_file}"
        end
      end
    end

    %w(conf ovpn).each do |ext|
      template "#{key_dir}/#{username}.#{ext}" do
        source 'client.conf.erb'
        variables(
          username: username,
          port: new_resource.port
        )
        action user_action
      end
    end

    tar_file = "#{databag_item}.tar.gz"
    tar_cmd = "tar zcf #{tar_file} ca.crt #{username}.crt #{username}.key #{username}.conf #{username}.ovpn"
    if node['opsline-openvpn']['tls_key']
      tar_cmd += " #{node['opsline-openvpn']['tls_key']}"
    end
    execute "create-openvpn-tar-#{databag_item}" do
      cwd key_dir
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
  execute "sync-openvpn-keys-to-s3" do
    cwd key_dir
    command "aws s3 sync #{key_dir} s3://#{node['opsline-openvpn']['users']['s3bucket']}/ --sse --exclude '*' --include '*.tar.gz'"
    not_if { node['opsline-openvpn']['users']['s3bucket'].nil? }
  end

end
