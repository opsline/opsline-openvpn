#
# Sample of multidaemon config hash. This should normally go in your vpn server role.
# Valid keys in the 'destinations' hash are role, environment, ip (specific ip, ip range or CIDR), protocol and port
# You must include either the 'ip' key, 'url' key OR use 'role' and/or 'environment' keys to lookup the valid ips
# If you want to specify 'protocol' or 'port', you must use both together
#
# 'opsline-openvpn' => {
#   'daemons' => {
#     'admin' => {
#       'device' => 'tun0',
#       'subnet' => '10.4.0.0',
#       'netmask' => '255.255.255.0',
#       'port' => 1194,
#       'firewall' => {
#         'type' => 'whitelist',
#         'destinations' => [
#           { 
#             'environment' => 'production',
#             'role' => 'elk',
#             'protocol' => 'tcp',
#             'port' => '80'
#           }
#         ]
#       }
#     },
#     'dev' => {
#       'device' => 'tun1',
#       'subnet' => '10.5.0.0',
#       'netmask' => '255.255.255.0',
#       'port' => 1195,
#       'firewall' => {
#         'type' => 'whitelist',
#         'destinations' => [
#           { 
#             'environment' => 'development',
#             'role' => 'elk',
#             'protocol' => 'tcp',
#             'port' => '80'
#           }
#         ]
#       }
#     }
#   }
# }

# setup each openvpn server daemon's firewall rules
node['opsline-openvpn']['daemons'].each do |k,v|
  rules = []

  # calculate source CIDR for this openvpn daemon
  cidr_mask = IPAddr.new("#{v['netmask']}").to_i.to_s(2).count("1")
  source_cidr = "#{v['subnet']}/#{cidr_mask}"
  log "using source_cidr #{source_cidr} for firewall rules for #{k} daemon"

  if v.has_key?('firewall') && v['firewall'].has_key?('type')

    type = v['firewall']['type'].downcase
    case type
      when "whitelist"
        permission = "ACCEPT"
        inverse_permission = "DROP"
      when "blacklist"
        permission = "DROP"
        inverse_permission = "ACCEPT"
      else
        log "Invalid firewall type specified: #{v['firewall']['type']}"
        return
    end

    v['firewall']['destinations'].each do |d|
      
      rule = {}

      # optional, but must be both used together
      if d.has_key?('port') && d.has_key?('protocol')
        rule['port'] = d['port']
        rule['protocol'] = d['protocol']
        port_msg = " on #{rule['protocol']} port #{rule['port']}"
      end

      query = ''

      if d.has_key?('ip')
        query = nil # no need to run chef search query
        rule['ip'] = d['ip']
        rules << rule.dup
        log "creating firewall rule to #{permission} traffic from #{source_cidr} to #{rule['ip']}#{port_msg}"
      
      elsif d.has_key?('url')
        query = nil # no need to run chef search query
        ips = []
        log "resolve url #{d['url']} to private ip address(es) for firewall rule"
        require 'resolv'
        ips = Resolv::DNS.new.getaddresses('admin.getbread.com').map(&:to_s).sort
        
        ips.each do |ip|
          rule['ip'] = ip
          rules << rule.dup
          log "creating firewall rule to #{permission} traffic from #{source_cidr} to #{rule['ip']}#{port_msg}"
        end

      else
        # need to lookup the ip(s) using chef search
        if d.has_key?('role')
          query += "roles:#{d['role']}"
        end
        if d.has_key?('environment')
          if query.size > 0
            query += ' AND '
          end
          query += "chef_environment:#{d['environment']}"
        end

        log "Searching for destination ips using chef search query: #{query}"
        search(:node, query) do |node|
          if node.has_key?('ipaddress')
            rule['ip'] = node['ipaddress']
            rules << rule.dup
            log "creating firewall rule to #{permission} traffic from #{source_cidr} to #{rule['ip']}#{port_msg}"
          end
        end
      end
    end

    log "rules: #{rules}"

    rules_action = :enable

  else
    log "No valid firewall specification for vpn daemon: #{k}"
    rules_action = :disable
  end

  iptables_rule "openvpn_#{k}_firewall" do
    source 'firewall_rules.erb'
    variables({
      :rules => rules,
      :source_cidr => source_cidr,
      :permission => permission,
      :inverse_permission => inverse_permission
    })
    action rules_action
  end
end

    