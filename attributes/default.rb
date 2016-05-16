default['opsline-openvpn']['tls_key'] = 'ta.key'

default['opsline-openvpn']['log'] = '/var/log/syslog'

default['opsline-openvpn']['users']['s3bucket'] = nil
default['opsline-openvpn']['users']['search_key'] = 'groups'

default['opsline-openvpn']['mfa']['enabled'] = false
default['opsline-openvpn']['mfa']['type'] = 'duo'
default['opsline-openvpn']['mfa']['reneg-sec'] = '0'
default['opsline-openvpn']['mfa']['databag'] = 'openvpn_mfa'

default['opsline-openvpn']['route53']['zone_id'] = nil
default['opsline-openvpn']['route53']['domain_name'] = nil
default['opsline-openvpn']['route53']['cname_prefix'] = 'vpn'

# databag containing the client private key with restricted permissions to create/edit/delete persisted vpn data bag items
default['opsline-openvpn']['persistence']['admin_data_bag'] = nil
default['opsline-openvpn']['persistence']['admin_databag_item'] = 'chef_databag_admin'
default['opsline-openvpn']['persistence']['users_databag'] = 'openvpn_users'
default['opsline-openvpn']['persistence']['server_keys_databag'] = 'openvpn_server'

default['opsline-openvpn']['daemons'] = {}
