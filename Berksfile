source "https://supermarket.chef.io"

cookbook 'openvpn', git: 'https://github.com/xhost-cookbooks/openvpn.git'

metadata

group :integration do
  cookbook 'prep', path: 'test/fixtures/cookbooks/prep'
end