require 'serverspec'

set :backend, :exec

describe "duo" do

  describe file("/etc/openvpn/duosecurity-duo_openvpn-4d3727c") do
    it { should be_directory }
  end

  describe file('/etc/openvpn/duo.tar.gz') do
    it { should be_file }
  end
   
end