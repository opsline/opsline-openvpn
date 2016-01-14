default['opsline-openvpn']['tls_key'] = 'ta.key'

default['opsline-openvpn']['users']['s3bucket'] = nil

default['opsline-openvpn']['keys_databag'] = 'openvpn_server'
default['opsline-openvpn']['users_databag'] = 'openvpn_users'

default['opsline-openvpn']['mfa']['enabled'] = false
default['opsline-openvpn']['mfa']['type'] = 'duo'
default['opsline-openvpn']['mfa']['reneg-sec'] = '0'
default['opsline-openvpn']['mfa']['databag'] = 'openvpn_mfa'

default['opsline-openvpn']['route53']['zone_id'] = nil
default['opsline-openvpn']['route53']['domain_name'] = nil
default['opsline-openvpn']['route53']['cname_prefix'] = 'vpn'

default['opsline-openvpn']['multidaemon']['daemons'] = {}

