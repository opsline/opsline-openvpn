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
    server_keys = Chef::EncryptedDataBagItem.load(node['opsline-openvpn']['keys_databag'], new_resource.databag_item).to_hash
  rescue
    log "Missing #{node['opsline-openvpn']['keys_databag']}:#{new_resource.databag_item} databag item"
    return
  end

  key_size = node['openvpn']['key']['size']

  directory new_resource.key_dir do
    owner 'root'
    group 'root'
    mode  '0700'
  end

  template "#{new_resource.key_dir}/openssl.cnf" do
    source 'openssl.cnf.erb'
    cookbook 'opsline-openvpn'
    owner 'root'
    group 'root'
    mode  '0644'
    variables(
      :key_dir => new_resource.key_dir
    )
    not_if { ::File.exists?("#{new_resource.key_dir}/openssl.cnf") }
  end

  file "#{new_resource.key_dir}/index.txt" do
    owner 'root'
    group 'root'
    mode  '0600'
    action :create
  end

  file "#{new_resource.key_dir}/serial" do
    content '01'
    not_if { ::File.exists?("#{new_resource.key_dir}/serial") }
  end

  unless server_keys.nil? # after initial run, we should have each daemons server keys persisted to a data bag

    log "using #{node['opsline-openvpn']['keys_databag']}:#{new_resource.databag_item} databag item to restore openvpn server keys"

    # we only persist the ca.key and ca.crt for the default daemon, else we copy them into the new daemons keys dir
    if new_resource.databag_item == 'default'
      log "restoring ca.crt from #{node['opsline-openvpn']['keys_databag']}:#{new_resource.databag_item}"
      file "#{new_resource.key_dir}/ca.crt" do
        content server_keys['ca_crt']
        owner 'root'
        group 'root'
        mode  '0644'
      end
      log "restoring ca.key from #{node['opsline-openvpn']['keys_databag']}:#{new_resource.databag_item}"
      file "#{new_resource.key_dir}/ca.key" do
        content server_keys['ca_key']
        owner 'root'
        group 'root'
        mode  '0644'
      end
    else
      # copy the CA cert/key from the default keys dir to each daemons keys dir to be included in user keys tarball
      log "copying ca.crt from #{node['openvpn']['signing_ca_cert']} since this is a non-default daemon"
      file "#{new_resource.key_dir}/ca.crt" do
        content lazy { IO.read("#{node["openvpn"]["signing_ca_cert"]}") }
        action :create
        owner 'root'
        group 'root'
      end

      # copy the CA key to each daemon's keys dir for generating user keys
      log "copying ca.key from #{node['openvpn']['signing_ca_key']} since this is a non-default daemon"
      file "#{new_resource.key_dir}/ca.key" do
        content lazy { IO.read("#{node["openvpn"]["signing_ca_key"]}") }
        action :create
        owner 'root'
        group 'root'
      end
    end

    log "restoring dh#{node['openvpn']['key']['size']}.pem from #{node['opsline-openvpn']['keys_databag']}:#{new_resource.databag_item}"
    file "#{new_resource.key_dir}/dh#{node['openvpn']['key']['size']}.pem" do
      content server_keys['dh']
      owner 'root'
      group 'root'
      mode  '0600'
    end
    log "restoring server.crt from #{node['opsline-openvpn']['keys_databag']}:#{new_resource.databag_item}"
    file "#{new_resource.key_dir}/server.crt" do
      content server_keys['server_crt']
      owner 'root'
      group 'root'
      mode  '0644'
    end
    log "restoring server.csr from #{node['opsline-openvpn']['keys_databag']}:#{new_resource.databag_item}"    
    file "#{new_resource.key_dir}/server.csr" do
      content server_keys['server_csr']
      owner 'root'
      group 'root'
      mode  '0644'
    end
    log "restoring server.key from #{node['opsline-openvpn']['keys_databag']}:#{new_resource.databag_item}"
    file "#{new_resource.key_dir}/server.key" do
      content server_keys['server_key']
      owner 'root'
      group 'root'
      mode  '0600'
    end
    log "restoring #{node['opsline-openvpn']['tls_key']} from #{node['opsline-openvpn']['keys_databag']}:#{new_resource.databag_item}"
    file "#{new_resource.key_dir}/#{node['opsline-openvpn']['tls_key']}" do
      content server_keys['tls_key']
      owner 'root'
      group 'root'
      mode  '0600'
      only_if { server_keys.has_key?('tls_key') }
    end

  else # create new server keys to initialize this openvpn daemon instance

    log "NO EXISTING DATABAG FOR RESTORING SERVER KEYS - New server keys must be generated"
    # if this is for the default/first daemon, then openvpn::server has already generated new server keys
    unless new_resource.databag_item == 'default'
      
      # Use unless instead of not_if otherwise OpenSSL::PKey::DH runs every time.
      unless ::File.exists?("#{new_resource.key_dir}/dh#{key_size}.pem")
        log "generating new dh#{key_size}.pem"
        require 'openssl'
        file "#{new_resource.key_dir}/dh#{key_size}.pem" do
          content OpenSSL::PKey::DH.new(key_size).to_s
          owner 'root'
          group 'root'
          mode  '0600'
        end
      end

      # create custom server cert
      log "generating new server.key, server.csr and server.crt based on #{new_resource.key_dir}/openssl.cnf"
      bash 'openvpn-server-key' do
        environment('KEY_CN' => "server_#{k}")
        code <<-EOF
          openssl req -batch -days #{node["openvpn"]["key"]["expire"]} \
            -nodes -new -newkey rsa:#{key_size} -keyout #{new_resource.key_dir}/server.key \
            -out #{new_resource.key_dir}/server.csr -extensions server \
            -config #{new_resource.key_dir}/openssl.cnf && \
          openssl ca -batch -days #{node["openvpn"]["key"]["ca_expire"]} \
            -out #{new_resource.key_dir}/server.crt -in #{new_resource.key_dir}/server.csr \
            -extensions server -md sha1 -config #{new_resource.key_dir}/openssl.cnf
        EOF
        not_if { ::File.exists?("#{new_resource.key_dir}/server.crt") }
      end

    end
  end
end
