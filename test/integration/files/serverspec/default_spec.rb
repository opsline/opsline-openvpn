require 'serverspec'

set :backend, :exec

describe "files" do

  describe file('/etc/openvpn/keys/testUser.conf') do
    it { should be_file }
  end

  describe file('/etc/openvpn/keys/testUser.crt') do
    it { should be_file }
  end
  
  describe file('/etc/openvpn/keys/testUser.csr') do
    it { should be_file }
  end

  describe file('/etc/openvpn/keys/testUser.key') do
    it { should be_file }
  end

  describe file('/etc/openvpn/keys/testUser.ovpn') do
    it { should be_file }
  end

  describe "s3 testing" do
    it "should list keys uploaded to s3" do
      keys = command("aws s3 ls s3://chef-openvpn-testing").stdout
      keys.should contain 'testUser.tar.gz'
    end
  end
   
end