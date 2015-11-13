require 'serverspec'

set :backend, :exec

describe "files" do

  describe service('openvpn') do
    it { should be_running }
  end
   
end