# Recipe:: multidaemon
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

# make sure we've installed openvpn with a single daemon running for global user access
include_recipe 'opsline-openvpn::default'

node['opsline-openvpn']['multidaemon']['daemons'].each { |k,v|

  # clone the default server config to get common attributes for this daemon's server_*.conf template
  config = node['openvpn']['config'].dup

  # import default routes
  routes = []
  routes << node['openvpn']['push_routes']
  # get custom routes for this daemon; flatten routes array later
  routes << v['push_routes']

  # custom key dir for this daemon
  key_dir  = "/etc/openvpn/keys_#{k}"
  key_size = node['openvpn']['key']['size']

  directory key_dir do
    owner 'root'
    group 'root'
    mode  '0700'
  end

  template "#{key_dir}/openssl.cnf" do
    source 'openssl.cnf.erb'
    cookbook 'openvpn'
    owner 'root'
    group 'root'
    mode  '0644'
    variables(
      :key_dir => "#{key_dir}"
    )
  end

  file "#{key_dir}/index.txt" do
    owner 'root'
    group 'root'
    mode  '0600'
    action :create
  end

  file "#{key_dir}/serial" do
    content '01'
    not_if { ::File.exists?("#{key_dir}/serial") }
  end

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

  # this should never run as default recipe has already created the CA signing cert
  bash 'openvpn-initca' do
    environment('KEY_CN' => "#{node['openvpn']['key']['org']} CA")
    code <<-EOF
      openssl req -batch -days #{node["openvpn"]["key"]["ca_expire"]} \
        -nodes -new -newkey rsa:#{key_size} -sha1 -x509 \
        -keyout #{node["openvpn"]["signing_ca_key"]} \
        -out #{node["openvpn"]["signing_ca_cert"]} \
        -config #{key_dir}/openssl.cnf
    EOF
    not_if { ::File.exists?(node['openvpn']['signing_ca_cert']) }
  end

  # create custom server cert
  bash 'openvpn-server-key' do
    environment('KEY_CN' => "server_#{k}")
    code <<-EOF
      openssl req -batch -days #{node["openvpn"]["key"]["expire"]} \
        -nodes -new -newkey rsa:#{key_size} -keyout #{key_dir}/server.key \
        -out #{key_dir}/server.csr -extensions server \
        -config #{key_dir}/openssl.cnf && \
      openssl ca -batch -days #{node["openvpn"]["key"]["ca_expire"]} \
        -out #{key_dir}/server.crt -in #{key_dir}/server.csr \
        -extensions server -md sha1 -config #{key_dir}/openssl.cnf
    EOF
    not_if { ::File.exists?("#{key_dir}/server.crt") }
  end

  # copy the CA cert to each daemon's keys dir to be included in user config tarball
  file "#{key_dir}/ca.crt" do
    content lazy { IO.read("#{node["openvpn"]["signing_ca_cert"]}") }
    action :create
    owner 'root'
    group 'root'
  end

  # copy the CA key to each daemon's keys dir for generating user keys
  file "#{key_dir}/ca.key" do
    content lazy { IO.read("#{node["openvpn"]["signing_ca_key"]}") }
    action :create
    owner 'root'
    group 'root'
  end

  config.store('dev', "#{v['device']}")
  config.store('ca', "#{key_dir}/ca.crt")
  config.store('key', "#{key_dir}/server.key")
  config.store('cert', "#{key_dir}/server.crt")
  config.store('dh', "#{key_dir}/dh#{node['openvpn']['key']['size']}.pem")
  config.store('log', "/var/log/openvpn_#{k}.log")
  config.store('server', "#{v['subnet']} #{v['netmask']}")
  config.store('port', "#{v['port']}")


  # create custom server.conf using custom opsline_openvpn_conf provider
  opsline_openvpn_conf "server_#{k}" do
    config config
    push_routes routes.flatten!.sort!
    push_options node['openvpn']['push_options']
    notifies :restart, 'service[openvpn]'
  end

  # calculate source CIDR for this openvpn daemon
  cidr_mask = IPAddr.new("#{v['netmask']}").to_i.to_s(2).count("1")
  source_cidr = "#{v['subnet']}/#{cidr_mask}"
  log "Using source CIDR: #{source_cidr} for openvpn daemon '#{k}'"

  iptables_rule "openvpn_#{k}" do
    source 'openvpn.erb'
    variables({
      :source_cidr => source_cidr
    })
  end

  # create client configs for each user in the relevant allowed group for this daemon
  search('users', "groups:#{v['allowed_group']}") do |u|

     if u.has_key?('action') and u['action'] == "remove"
      user_action = :delete
    else
      user_action = :create
    end

    begin
      persisted_certs = Chef::EncryptedDataBagItem.load(node['opsline-openvpn']['persistence']['users_databag'], u['id'])
    rescue
      Chef::Log.warn("Missing #{node['opsline-openvpn']['persistence']['users_databag']}:#{u['id']} databag item")
      persisted_certs = nil
    end

    unless persisted_certs.nil?
      file "#{key_dir}/#{u['id']}.crt" do
        content "#{persisted_certs['crt']}"
        owner 'root'
        group 'root'
        mode  '0644'
        action user_action
      end
      file "#{key_dir}/#{u['id']}.csr" do
        content "#{persisted_certs['csr']}"
        owner 'root'
        group 'root'
        mode  '0644'
        action user_action
      end
      file "#{key_dir}/#{u['id']}.key" do
        content "#{persisted_certs['key']}"
        owner 'root'
        group 'root'
        mode  '0600'
        action user_action
      end
    else
      if user_action == :delete
        %w(crt csr key).each do |ext|
          file "#{key_dir}/#{u['id']}.#{ext}" do
            action user_action
          end
        end
      else
        execute "generate-openvpn-#{u['id']}" do
          command "./pkitool #{u['id']}"
          cwd '/etc/openvpn/easy-rsa'
          environment(
            'EASY_RSA'     => '/etc/openvpn/easy-rsa',
            'KEY_CONFIG'   => "#{key_dir}/openssl.cnf",
            'KEY_DIR'      => "#{key_dir}",
            'CA_EXPIRE'    => node['openvpn']['key']['ca_expire'].to_s,
            'KEY_EXPIRE'   => node['openvpn']['key']['expire'].to_s,
            'KEY_SIZE'     => node['openvpn']['key']['size'].to_s,
            'KEY_COUNTRY'  => node['openvpn']['key']['country'],
            'KEY_PROVINCE' => node['openvpn']['key']['province'],
            'KEY_CITY'     => node['openvpn']['key']['city'],
            'KEY_ORG'      => node['openvpn']['key']['org'],
            'KEY_EMAIL'    => node['openvpn']['key']['email']
          )
          not_if { ::File.exist?("#{key_dir}/#{u['id']}.crt") }
        end
      end
    end

    %w(conf ovpn).each do |ext|
      template "#{key_dir}/#{u['id']}.#{ext}" do
        source 'client.conf.erb'
        variables(
          username: u['id'],
          port: v['port']
        )
        action user_action
      end
    end

    tar_file = "#{u['id']}-#{k}.tar.gz"
    tar_cmd = "tar zcf #{tar_file} ca.crt #{u['id']}.crt #{u['id']}.key #{u['id']}.conf #{u['id']}.ovpn"
    
    if node['opsline-openvpn']['tls_key']
      # copy the TLS key to each daemon's keys dir
      file "#{key_dir}/#{node['opsline-openvpn']['tls_key']}" do
        content lazy { IO.read("#{node['openvpn']['key_dir']}/#{node['opsline-openvpn']['tls_key']}") }
        action :create
        owner 'root'
        group 'root'
      end
      tar_cmd += " #{node['opsline-openvpn']['tls_key']}"
    end

    execute "create-openvpn-tar-#{u['id']}" do
      cwd "#{key_dir}"
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
    cwd "#{key_dir}"
    command "aws s3 sync #{key_dir} s3://#{node['opsline-openvpn']['users']['s3bucket']}/#{k} --sse --delete --exclude '*' --include '*.tar.gz'"
    not_if { node['opsline-openvpn']['users']['s3bucket'].nil? }
  end

}
