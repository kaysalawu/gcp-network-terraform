#cloud-config

write_files:
  - path: /opt/vyatta/etc/config/scripts/vyos-postconfig-bootup.script
    owner: root:vyattacfg
    permissions: '0775'
    content: |
      #!/bin/vbash
      source /opt/vyatta/etc/functions/script-template
      configure
      #!
      set system login user vyos authentication plaintext-password Password123
      #!
      set vpn ipsec ike-group IKEv2-GROUP dead-peer-detection action 'hold'
      set vpn ipsec ike-group IKEv2-GROUP dead-peer-detection interval '30'
      set vpn ipsec ike-group IKEv2-GROUP dead-peer-detection timeout '120'
      set vpn ipsec ike-group IKEv2-GROUP ikev2-reauth 'no'
      set vpn ipsec ike-group IKEv2-GROUP key-exchange 'ikev2'
      set vpn ipsec ike-group IKEv2-GROUP lifetime '10800'
      set vpn ipsec ike-group IKEv2-GROUP mobike 'disable'
      set vpn ipsec ike-group IKEv2-GROUP proposal 10 dh-group '14'
      set vpn ipsec ike-group IKEv2-GROUP proposal 10 encryption 'aes256'
      set vpn ipsec ike-group IKEv2-GROUP proposal 10 hash 'sha256'
      #!
      set vpn ipsec ipsec-interfaces interface 'eth0'
      set vpn ipsec esp-group ESP-GROUP compression 'disable'
      set vpn ipsec esp-group ESP-GROUP lifetime '14400'
      set vpn ipsec esp-group ESP-GROUP mode 'tunnel'
      set vpn ipsec esp-group ESP-GROUP pfs 'dh-group14'
      set vpn ipsec esp-group ESP-GROUP proposal 10 encryption 'aes256'
      set vpn ipsec esp-group ESP-GROUP proposal 10 hash 'sha256'
      #!
      set interfaces loopback lo address 22.22.22.22/32
      #!

      set nat source rule 10 destination address '10.1.0.1'
      set nat source rule 10 outbound-interface 'eth0'
      set nat source rule 10 translation address '10.1.21.10'
      #!
      set interfaces vti vti0 address '169.254.102.2/30'
      set interfaces vti vti0 description 'SITE-TUN0'
      set interfaces vti vti0 mtu '1460'
      set vpn ipsec site-to-site peer 35.236.69.155 authentication id '10.1.21.10'
      set vpn ipsec site-to-site peer 35.236.69.155 authentication remote-id '10.20.1.2'
      set vpn ipsec site-to-site peer 35.236.69.155 authentication mode 'pre-shared-secret'
      set vpn ipsec site-to-site peer 35.236.69.155 authentication pre-shared-secret 'Password123'
      set vpn ipsec site-to-site peer 35.236.69.155 connection-type 'respond'
      set vpn ipsec site-to-site peer 35.236.69.155 ike-group 'IKEv2-GROUP'
      set vpn ipsec site-to-site peer 35.236.69.155 ikev2-reauth 'inherit'
      set vpn ipsec site-to-site peer 35.236.69.155 local-address '10.1.21.10'
      set vpn ipsec site-to-site peer 35.236.69.155 vti bind 'vti0'
      set vpn ipsec site-to-site peer 35.236.69.155 vti esp-group 'ESP-GROUP'
      set vpn ipsec site-to-site peer 35.236.69.155 description 'SITE-TUN0'
      #!
      #!
      set protocols bgp 65002 parameters router-id '22.22.22.22'
      set protocols bgp 65002 neighbor 169.254.102.1 remote-as '65020'
      set protocols bgp 65002 neighbor 169.254.102.1 address-family ipv4-unicast soft-reconfiguration inbound
      set protocols bgp 65002 neighbor 169.254.102.1 timers holdtime '60'
      set protocols bgp 65002 neighbor 169.254.102.1 timers keepalive '20'
      set protocols bgp 65002 neighbor 169.254.102.1 address-family ipv4-unicast route-map export 'MAP-OUT-SITE'
      set protocols bgp 65002 neighbor 169.254.102.1 address-family ipv4-unicast route-map import 'MAP-IN-SITE'
      set protocols bgp 65002 neighbor 10.1.21.20 remote-as '65022'
      set protocols bgp 65002 neighbor 10.1.21.20 address-family ipv4-unicast soft-reconfiguration inbound
      set protocols bgp 65002 neighbor 10.1.21.20 timers holdtime '60'
      set protocols bgp 65002 neighbor 10.1.21.20 timers keepalive '20'
      set protocols bgp 65002 neighbor 10.1.21.20 address-family ipv4-unicast route-map export 'MAP-OUT-CR'
      set protocols bgp 65002 neighbor 10.1.21.20 address-family ipv4-unicast route-map import 'MAP-IN-CR'
      set protocols bgp 65002 neighbor 10.1.21.20 ebgp-multihop 4
      set protocols bgp 65002 neighbor 10.1.21.30 remote-as '65022'
      set protocols bgp 65002 neighbor 10.1.21.30 address-family ipv4-unicast soft-reconfiguration inbound
      set protocols bgp 65002 neighbor 10.1.21.30 timers holdtime '60'
      set protocols bgp 65002 neighbor 10.1.21.30 timers keepalive '20'
      set protocols bgp 65002 neighbor 10.1.21.30 address-family ipv4-unicast route-map export 'MAP-OUT-CR'
      set protocols bgp 65002 neighbor 10.1.21.30 address-family ipv4-unicast route-map import 'MAP-IN-CR'
      set protocols bgp 65002 neighbor 10.1.21.30 ebgp-multihop 4
      #!
      set protocols bgp 65002 parameters graceful-restart
      #!
      #!
      set policy as-path-list AL-OUT-SITE rule 10 action 'deny'
      set policy as-path-list AL-OUT-SITE rule 10 regex '_16550_'
      set policy as-path-list AL-OUT-SITE rule 20 action 'permit'
      set policy as-path-list AL-OUT-SITE rule 20 regex '_'
      set policy as-path-list AL-IN-SITE rule 10 action 'deny'
      set policy as-path-list AL-IN-SITE rule 10 regex '_16550_'
      set policy as-path-list AL-IN-SITE rule 20 action 'permit'
      set policy as-path-list AL-IN-SITE rule 20 regex '_'
      set policy as-path-list AL-OUT-CR rule 10 action 'permit'
      set policy as-path-list AL-OUT-CR rule 10 regex '_'
      set policy as-path-list AL-IN-CR rule 10 action 'permit'
      set policy as-path-list AL-IN-CR rule 10 regex '_'
      #!
      set policy prefix-list PL-OUT-SITE rule 10 action 'permit'
      set policy prefix-list PL-OUT-SITE rule 10 prefix '10.0.0.0/8'
      set policy prefix-list PL-IN-SITE rule 10 action 'permit'
      set policy prefix-list PL-IN-SITE rule 10 prefix '10.20.0.0/16'
      set policy prefix-list PL-OUT-CR rule 10 action 'permit'
      set policy prefix-list PL-OUT-CR rule 10 prefix '10.20.0.0/16'
      set policy prefix-list PL-IN-CR rule 10 action 'permit'
      set policy prefix-list PL-IN-CR rule 10 prefix '10.0.0.0/8'
      #!
      set policy route-map MAP-OUT-SITE rule 20 action permit
      set policy route-map MAP-OUT-SITE rule 20 match ip address prefix-list 'PL-OUT-SITE'
      set policy route-map MAP-OUT-SITE rule 20 set metric '105'
      set policy route-map MAP-IN-SITE rule 20 action permit
      set policy route-map MAP-IN-SITE rule 20 match ip address prefix-list 'PL-IN-SITE'
      set policy route-map MAP-IN-SITE rule 20 set metric '105'
      set policy route-map MAP-OUT-CR rule 20 action permit
      set policy route-map MAP-OUT-CR rule 20 match ip address prefix-list 'PL-OUT-CR'
      set policy route-map MAP-OUT-CR rule 20 set metric '105'
      set policy route-map MAP-IN-CR rule 20 action permit
      set policy route-map MAP-IN-CR rule 20 match ip address prefix-list 'PL-IN-CR'
      set policy route-map MAP-IN-CR rule 20 set metric '105'
      #!
      commit
      #!
      run reset ip bgp 169.254.102.1
      run reset ip bgp 10.1.21.20
      run reset ip bgp 10.1.21.30
      save
      exit
      # Avoid manual config lock out (see e.g. https://forum.vyos.io/t/error-message-set-failed/296/5)
      chown -R root:vyattacfg /opt/vyatta/config/active/
      chown -R root:vyattacfg /opt/vyatta/etc/
