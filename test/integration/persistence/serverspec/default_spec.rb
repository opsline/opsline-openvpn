require 'serverspec'

set :backend, :exec

describe "persistence" do

  describe file('/etc/openvpn/keys/testUser.crt') do
    its(:content) { should match /crt/ }
  end

  describe file('/etc/openvpn/keys/testUser.csr') do
    its(:content) { should match /csr/ }
  end

  describe file('/etc/openvpn/keys/testUser.key') do
    its(:content) { should match /key/ }
  end

  describe file('/etc/openvpn/keys/server.crt') do
    its(:content) { should contain /Certificate/ }
  end

  describe file('/etc/openvpn/keys/server.csr') do
    its(:content) { should contain /MIIB1TCCAT4CAQAwgZQxCzAJBgNVBAYTAlVTMQswCQYDVQQIEwJDQTEWMBQGA1UE/ }
  end

  describe file('/etc/openvpn/keys/server.key') do
    its(:content) { should contain /MIICdwIBADANBgkqhkiG9w0BAQEFAASCAmEwggJdAgEAAoGBAMnqSz0GfN5H9WT6/ }
  end

  describe file('/etc/openvpn/keys/ta.key') do
    its(:content) { should contain /cdcb8a4da642dc90f25380e99f3b42c7/ }
  end

  describe file('/etc/openvpn/keys/ca.crt') do
    its(:content) { should contain /MIIDwjCCAyugAwIBAgIJALjjPmAldsw3MA0GCSqGSIb3DQEBBQUAMIGdMQswCQYD/ }
  end

  describe file('/etc/openvpn/keys/ca.key') do
    its(:content) { should contain /MIICeAIBADANBgkqhkiG9w0BAQEFAASCAmIwggJeAgEAAoGBAOAVODPzfaKCuBN2/ }
  end

end