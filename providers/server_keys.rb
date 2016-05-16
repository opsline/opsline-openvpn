#
# Cookbook Name:: opsline-openvpn
# Provider:: server_keys
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
  # override default key_dir attribute for templates generated below
  node.override['openvpn']['key_dir'] = key_dir
  node.override['openvpn']['signing_ca_key']  = "#{node['openvpn']['key_dir']}/ca.key"
  node.override['openvpn']['signing_ca_cert'] = "#{node['openvpn']['key_dir']}/ca.crt"

  key_size = node['openvpn']['key']['size']

  directory key_dir do
    owner 'root'
    group 'root'
    mode  '0700'
    recursive true
  end

  directory "#{new_resource.base_dir}/easy-rsa" do
    owner 'root'
    group 'root'
    mode  '0755'
  end

  %w(openssl.cnf pkitool vars Rakefile).each do |f|
    template "#{new_resource.base_dir}/easy-rsa/#{f}" do
      cookbook 'openvpn'
      source "#{f}.erb"
      owner 'root'
      group 'root'
      mode  '0755'
    end
  end

  template "#{new_resource.base_dir}/server.up.sh" do
    cookbook 'openvpn'
    source 'server.up.sh.erb'
    owner 'root'
    group 'root'
    mode  '0755'
  end

  directory "#{new_resource.base_dir}/server.up.d" do
    owner 'root'
    group 'root'
    mode  '0755'
  end

  file "#{key_dir}/index.txt" do
    owner 'root'
    group 'root'
    mode  '0600'
    action :create
  end

  file "#{key_dir}/serial" do
    content '01'
    not_if { ::File.exist?("#{key_dir}/serial") }
  end

  begin
    log "Searching #{node['opsline-openvpn']['persistence']['server_keys_databag']}:#{new_resource.databag_item} databag item for openvpn server keys"
    server_keys = Chef::EncryptedDataBagItem.load(node['opsline-openvpn']['persistence']['server_keys_databag'], new_resource.databag_item)
    log "using #{node['opsline-openvpn']['persistence']['server_keys_databag']}:#{new_resource.databag_item} databag item for openvpn server keys"
  rescue StandardError => e
    log "Caught exception #{e} while searching #{node['opsline-openvpn']['persistence']['server_keys_databag']}:#{new_resource.databag_item} databag item"
    log "Persisted openvpn server keys do not exist in #{node['opsline-openvpn']['persistence']['server_keys_databag']}:#{new_resource.databag_item} databag item"
    log "New openvpn server keys will be generated and saved to #{node['opsline-openvpn']['persistence']['server_keys_databag']}:#{new_resource.databag_item} databag item"
    server_keys = nil

    # Use unless instead of not_if otherwise OpenSSL::PKey::DH runs every time.
    unless ::File.exists?("#{key_dir}/dh#{key_size}.pem")
      require 'openssl'
      file "#{key_dir}/dh#{key_size}.pem" do
        content OpenSSL::PKey::DH.new(key_size).to_s
        owner 'root'
        group 'root'
        mode  '0600'
      end
    end

    # generate a new CA cert and CA key for each openvpn server daemon
    # NOTE: the CA cert is bundled with the client keys and is the only 
    #       method used to authenticate client connections to openvpn
    bash 'openvpn-initca' do
      environment('KEY_CN' => "#{node['openvpn']['key']['org']} #{new_resource.databag_item} CA")
      code <<-EOF
        openssl req -batch -days #{node['openvpn']['key']['ca_expire']} \
          -nodes -new -newkey rsa:#{key_size} -sha1 -x509 \
          -keyout #{key_dir}/ca.key \
          -out #{key_dir}/ca.crt \
          -config #{new_resource.base_dir}/easy-rsa/openssl.cnf
      EOF
      not_if { ::File.exist?("#{key_dir}/ca.crt") }
    end

    # create custom server cert
    bash 'openvpn-server-key' do
      environment('KEY_CN' => "#{node['openvpn']['key']['org']} #{new_resource.databag_item} CA")
      code <<-EOF
        openssl req -batch -days #{node['openvpn']['key']['expire']} \
          -nodes -new -newkey rsa:#{key_size} -keyout #{key_dir}/server.key \
          -out #{key_dir}/server.csr -extensions server \
          -config #{new_resource.base_dir}/easy-rsa/openssl.cnf && \
        openssl ca -batch -days #{node['openvpn']['key']['ca_expire']} \
          -out #{key_dir}/server.crt -in #{key_dir}/server.csr \
          -extensions server -md sha1 -config #{new_resource.base_dir}/easy-rsa/openssl.cnf
      EOF
      not_if { ::File.exists?("#{key_dir}/server.crt") }
    end

    # create optional tls key
    if node['opsline-openvpn']['tls_key']
      execute 'generate tls key' do
        cwd key_dir
        command "openvpn --genkey --secret #{key_dir}/#{node['opsline-openvpn']['tls_key']}"
        action :run
        not_if { ::File.exist?("#{key_dir}/#{node['opsline-openvpn']['tls_key']}") }
      end
    end

    log "building #{new_resource.databag_item}.json file to be uploaded to data bag #{node['opsline-openvpn']['persistence']['server_keys_databag']}"
    ruby_block "read keys" do
      block do
        ::File.open("#{key_dir}/#{new_resource.databag_item}.json", "w") do |f|
          f.puts ("{ \"id\": \"#{new_resource.databag_item}\",")
          f.puts ("\"server_crt\": \"#{::File.open("#{key_dir}/server.crt", "r").read().gsub(/\n/,"\\n")}\",")
          f.puts ("\"server_csr\": \"#{::File.open("#{key_dir}/server.csr", "r").read().gsub(/\n/,"\\n")}\",")
          f.puts ("\"server_key\": \"#{::File.open("#{key_dir}/server.key", "r").read().gsub(/\n/,"\\n")}\",")
          f.puts ("\"ca_crt\": \"#{::File.open("#{key_dir}/ca.crt", "r").read().gsub(/\n/,"\\n")}\",")
          f.puts ("\"ca_key\": \"#{::File.open("#{key_dir}/ca.key", "r").read().gsub(/\n/,"\\n")}\",")
          f.puts ("\"dh\": \"#{::File.open("#{key_dir}/dh#{key_size}.pem", "r").read().gsub(/\n/,"\\n")}\"")
          if node['opsline-openvpn']['tls_key']
            f.puts (",")
            f.puts ("\"tls_key\": \"#{::File.open("#{key_dir}/#{node['opsline-openvpn']['tls_key']}", "r").read().gsub(/\n/,"\\n")}\"")
          end
          f.puts ("}")
        end
      end
    end
    
    require 'chef/knife' # for executing below knife command to upload data bag items

    execute "persisting #{new_resource.databag_item}.json to data bag item #{node['opsline-openvpn']['persistence']['server_keys_databag']}:#{new_resource.databag_item}" do
      command "knife data bag from file #{node['opsline-openvpn']['persistence']['server_keys_databag']} #{key_dir}/#{new_resource.databag_item}.json --secret-file /etc/chef/encrypted_data_bag_secret -c /etc/chef/client.rb -u #{client_username} -k #{client_key_file}"
    end

    # delete the json file just created
    file "#{key_dir}/#{new_resource.databag_item}.json" do
      action :delete
    end
  end

  unless server_keys.nil? # after initial run, we should have each daemons server keys persisted to a data bag

    file "#{key_dir}/ca.crt" do
      content server_keys['ca_crt']
      owner 'root'
      group 'root'
      mode  '0644'
    end
    file "#{key_dir}/ca.key" do
      content server_keys['ca_key']
      owner 'root'
      group 'root'
      mode  '0600'
    end
    file "#{key_dir}/dh#{key_size}.pem" do
      content server_keys['dh']
      owner 'root'
      group 'root'
      mode  '0600'
    end
    file "#{key_dir}/server.crt" do
      content server_keys['server_crt']
      owner 'root'
      group 'root'
      mode  '0644'
    end
    file "#{key_dir}/server.csr" do
      content server_keys['server_csr']
      owner 'root'
      group 'root'
      mode  '0644'
    end
    file "#{key_dir}/server.key" do
      content server_keys['server_key']
      owner 'root'
      group 'root'
      mode  '0600'
    end
    file "#{key_dir}/#{node['opsline-openvpn']['tls_key']}" do
      content server_keys['tls_key']
      owner 'root'
      group 'root'
      mode  '0600'
      only_if { server_keys.to_hash().has_key?('tls_key') }
    end
    
  end
end
