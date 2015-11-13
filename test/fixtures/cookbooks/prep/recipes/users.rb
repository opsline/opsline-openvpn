directory '/etc/openvpn/keys' do 
  recursive true
end

file '/etc/openvpn/keys/testUser-remove.conf' do
  content 'conf'
  mode '0644'
  owner 'root'
  group 'root'
end

file '/etc/openvpn/keys/testUser-remove.crt' do
  content 'crt'
  mode '0644'
  owner 'root'
  group 'root'
end

file '/etc/openvpn/keys/testUser-remove.csr' do
  content 'csr'
  mode '0644'
  owner 'root'
  group 'root'
end

file '/etc/openvpn/keys/testUser-remove.key' do
  content 'key'
  mode '0644'
  owner 'root'
  group 'root'
end

file '/etc/openvpn/keys/testUser-remove.ovpn' do
  content 'ovpn'
  mode '0644'
  owner 'root'
  group 'root'
end