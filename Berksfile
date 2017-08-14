source 'https://supermarket.chef.io'

cookbook 'openvpn', '= 2.1.1', git: 'https://github.com/opsline/openvpn.git', tag: 'v2.1.1'

cookbook 'openvpn', git: 'https://github.com/xhost-cookbooks/openvpn.git'

metadata

group :integration do
  cookbook 'prep', path: 'test/fixtures/cookbooks/prep'
end