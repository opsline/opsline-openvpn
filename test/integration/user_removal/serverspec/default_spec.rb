require 'serverspec'

set :backend, :exec

describe "persistence" do

  describe file('/etc/openvpn/keys/testUser-remove.conf') do
    it { should_not be_file }
  end

  describe file('/etc/openvpn/keys/testUser-remove.crt') do
    it { should_not be_file }
  end

  describe file('/etc/openvpn/keys/testUser-remove.csr') do
    it { should_not be_file }
  end

  describe file('/etc/openvpn/keys/testUser-remove.key') do
    it { should_not be_file }
  end

end