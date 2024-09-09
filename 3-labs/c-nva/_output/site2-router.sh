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
      set interfaces loopback lo address 2.2.2.2/32
      set protocols static route 10.20.0.0/16 next-hop 10.20.1.1
      #!
      #!
      set interfaces vti vti0 address '169.254.102.1/30'
      set interfaces vti vti0 description 'HUB-TUN0'
      set interfaces vti vti0 mtu '1460'
      set vpn ipsec site-to-site peer 35.235.71.174 authentication id '10.20.1.2'
      set vpn ipsec site-to-site peer 35.235.71.174 authentication remote-id '10.1.21.10'
      set vpn ipsec site-to-site peer 35.235.71.174 authentication mode 'pre-shared-secret'
      set vpn ipsec site-to-site peer 35.235.71.174 authentication pre-shared-secret 'Password123'
      set vpn ipsec site-to-site peer 35.235.71.174 connection-type 'initiate'
      set vpn ipsec site-to-site peer 35.235.71.174 ike-group 'IKEv2-GROUP'
      set vpn ipsec site-to-site peer 35.235.71.174 ikev2-reauth 'inherit'
      set vpn ipsec site-to-site peer 35.235.71.174 local-address '10.20.1.2'
      set vpn ipsec site-to-site peer 35.235.71.174 vti bind 'vti0'
      set vpn ipsec site-to-site peer 35.235.71.174 vti esp-group 'ESP-GROUP'
      set vpn ipsec site-to-site peer 35.235.71.174 description 'HUB-TUN0'
      #!
      #!
      set protocols bgp 65020 parameters router-id '2.2.2.2'
      set protocols bgp 65020 neighbor 169.254.102.2 remote-as '65002'
      set protocols bgp 65020 neighbor 169.254.102.2 address-family ipv4-unicast soft-reconfiguration inbound
      set protocols bgp 65020 neighbor 169.254.102.2 timers holdtime '60'
      set protocols bgp 65020 neighbor 169.254.102.2 timers keepalive '20'
      set protocols bgp 65020 neighbor 169.254.102.2 address-family ipv4-unicast route-map export 'MAP-OUT-HUB'
      set protocols bgp 65020 neighbor 169.254.102.2 address-family ipv4-unicast route-map import 'MAP-IN-HUB'
      set protocols bgp 65020 neighbor 169.254.102.2 ebgp-multihop 4
      #!
      set protocols bgp 65020 parameters graceful-restart
      set protocols bgp 65020 address-family ipv4-unicast redistribute static metric 90
      #!
      #!
      set policy as-path-list AL-OUT-HUB rule 10 action 'permit'
      set policy as-path-list AL-OUT-HUB rule 10 regex '_'
      set policy as-path-list AL-IN-HUB rule 10 action 'permit'
      set policy as-path-list AL-IN-HUB rule 10 regex '_'
      #!
      set policy prefix-list PL-OUT-HUB rule 10 action 'permit'
      set policy prefix-list PL-OUT-HUB rule 10 prefix '10.20.0.0/16'
      set policy prefix-list PL-IN-HUB rule 10 action 'permit'
      set policy prefix-list PL-IN-HUB rule 10 prefix '10.0.0.0/8'
      #!
      set policy route-map MAP-OUT-HUB rule 10 action 'permit'
      set policy route-map MAP-OUT-HUB rule 10 match as-path 'AL-OUT-HUB'
      set policy route-map MAP-OUT-HUB rule 10 set metric '100'
      set policy route-map MAP-OUT-HUB rule 20 action permit
      set policy route-map MAP-OUT-HUB rule 20 match ip address prefix-list 'PL-OUT-HUB'
      set policy route-map MAP-OUT-HUB rule 20 set metric '105'
      set policy route-map MAP-IN-HUB rule 10 action 'permit'
      set policy route-map MAP-IN-HUB rule 10 match as-path 'AL-IN-HUB'
      set policy route-map MAP-IN-HUB rule 10 set metric '100'
      set policy route-map MAP-IN-HUB rule 20 action permit
      set policy route-map MAP-IN-HUB rule 20 match ip address prefix-list 'PL-IN-HUB'
      set policy route-map MAP-IN-HUB rule 20 set metric '105'
      #!
      commit
      #!
      run reset ip bgp 169.254.102.2
      save
      exit
      # Avoid manual config lock out (see e.g. https://forum.vyos.io/t/error-message-set-failed/296/5)
      chown -R root:vyattacfg /opt/vyatta/config/active/
      chown -R root:vyattacfg /opt/vyatta/etc/
