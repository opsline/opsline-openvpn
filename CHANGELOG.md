# CHANGELOG for opsline-openvpn

## 0.1.4
* refactoring and rewrite
* locked openvpn to opsline fork
* added attribute to enable/disable persistence
* added attribute to override users data bag

## 0.1.3
* integrated multidaemon support, tls key generation, and chef-managed persistence of user and server keys into default recipe
* added iptables-based firewall restrictions configurable per openvpn daemon

## 0.1.2
* adding multidaemon support

## 0.1.1
* fixing user certs deletes
* fixing data bag scripts when json format is configured in knife

## 0.1.0
* initial release
