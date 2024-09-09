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
      set system login user vyos authentication plaintext-password ${PASSWORD}
      #!
      %{~ if IPSEC_CONFIG.enable ~}
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
      set vpn ipsec ipsec-interfaces interface '${IPSEC_CONFIG.interface}'
      set vpn ipsec esp-group ESP-GROUP compression 'disable'
      set vpn ipsec esp-group ESP-GROUP lifetime '14400'
      set vpn ipsec esp-group ESP-GROUP mode 'tunnel'
      set vpn ipsec esp-group ESP-GROUP pfs 'dh-group14'
      set vpn ipsec esp-group ESP-GROUP proposal 10 encryption 'aes256'
      set vpn ipsec esp-group ESP-GROUP proposal 10 hash 'sha256'
      %{~ endif ~}
      #!
      set interfaces loopback lo address ${LOOPBACK_IP}/32
      %{~ for route in STATIC_ROUTES ~}
      set protocols static route ${route.destination} next-hop ${route.next_hop}
      %{~ endfor ~}
      #!
      %{~ for item in DNAT_CONFIG ~}
      %{~ if item.enable }
      set nat source rule ${item.rule} destination address '${item.destination_address}'
      set nat source rule ${item.rule} outbound-interface '${item.outbound_interface}'
      set nat source rule ${item.rule} translation address '${item.translation_address}'
      %{~ endif ~}
      %{~ endfor ~}
      #!
      %{~ for tunnel in VPN_TUNNELS ~}
      %{~ if tunnel.enable ~}
      set interfaces vti ${tunnel.local_vti} address '${tunnel.local_vti_ip}/${tunnel.local_vti_mask}'
      set interfaces vti ${tunnel.local_vti} description '${tunnel.name}'
      set interfaces vti ${tunnel.local_vti} mtu '1460'
      set vpn ipsec site-to-site peer ${tunnel.peer_nat_ip} authentication id '${tunnel.local_auth_id}'
      set vpn ipsec site-to-site peer ${tunnel.peer_nat_ip} authentication remote-id '${tunnel.peer_auth_id}'
      set vpn ipsec site-to-site peer ${tunnel.peer_nat_ip} authentication mode 'pre-shared-secret'
      set vpn ipsec site-to-site peer ${tunnel.peer_nat_ip} authentication pre-shared-secret '${tunnel.psk}'
      set vpn ipsec site-to-site peer ${tunnel.peer_nat_ip} connection-type '${tunnel.local_type}'
      set vpn ipsec site-to-site peer ${tunnel.peer_nat_ip} ike-group 'IKEv2-GROUP'
      set vpn ipsec site-to-site peer ${tunnel.peer_nat_ip} ikev2-reauth 'inherit'
      set vpn ipsec site-to-site peer ${tunnel.peer_nat_ip} local-address '${tunnel.local_address}'
      set vpn ipsec site-to-site peer ${tunnel.peer_nat_ip} vti bind '${tunnel.local_vti}'
      set vpn ipsec site-to-site peer ${tunnel.peer_nat_ip} vti esp-group 'ESP-GROUP'
      set vpn ipsec site-to-site peer ${tunnel.peer_nat_ip} description '${tunnel.name}'
      %{~ endif ~}
      %{~ endfor ~}
      #!
      %{~ for tunnel in TUNNELS ~}
      %{~ if tunnel.enable ~}
      set interfaces tunnel ${tunnel.name} address ${tunnel.tunnel_addr}/${tunnel.tunnel_mask}
      set interfaces tunnel ${tunnel.name} encapsulation ${tunnel.encapsulation}
      set interfaces tunnel ${tunnel.name} source-address ${tunnel.local_ip}
      set interfaces tunnel ${tunnel.name} remote ${tunnel.remote_ip}
      %{~ endif ~}
      %{~ endfor ~}
      #!
      %{~ if ENABLE_BGP ~}
      %{~ if BGP_USE_LOOPBACK ~}
      set protocols bgp ${LOCAL_ASN} parameters router-id '${LOOPBACK_IP}'
      %{~ endif ~}
      %{~ for session in BGP_SESSIONS ~}
      set protocols bgp ${LOCAL_ASN} neighbor ${session.peer_ip} remote-as '${session.peer_asn}'
      set protocols bgp ${LOCAL_ASN} neighbor ${session.peer_ip} address-family ipv4-unicast soft-reconfiguration inbound
      set protocols bgp ${LOCAL_ASN} neighbor ${session.peer_ip} timers holdtime '60'
      set protocols bgp ${LOCAL_ASN} neighbor ${session.peer_ip} timers keepalive '20'
      %{~ if session.route_map_export.enable ~}
      set protocols bgp ${LOCAL_ASN} neighbor ${session.peer_ip} address-family ipv4-unicast route-map export '${session.route_map_export.map}'
      %{~ endif ~}
      %{~ if session.route_map_import.enable ~}
      set protocols bgp ${LOCAL_ASN} neighbor ${session.peer_ip} address-family ipv4-unicast route-map import '${session.route_map_import.map}'
      %{~ endif ~}
      %{~ if session.multihop.enable ~}
      set protocols bgp ${LOCAL_ASN} neighbor ${session.peer_ip} ebgp-multihop ${session.multihop.ttl}
      %{~ endif ~}
      %{~ endfor ~}
      #!
      set protocols bgp ${LOCAL_ASN} parameters graceful-restart
      %{~ if BGP_REDISTRIBUTE_STATIC.enable ~}
      set protocols bgp ${LOCAL_ASN} address-family ipv4-unicast redistribute static metric ${BGP_REDISTRIBUTE_STATIC.metric}
      %{~ endif ~}
      #!
      %{~ for network in BGP_ADVERTISED_NETWORKS ~}
      set protocols bgp ${LOCAL_ASN} address-family ipv4-unicast network ${network}
      %{~ endfor ~}
      %{~ endif ~}
      #!
      %{~ for item in AS_LISTS ~}
      %{~ if item.enable ~}
      set policy as-path-list ${item.name} rule ${item.rule} action '${item.action}'
      set policy as-path-list ${item.name} rule ${item.rule} regex '${item.regex}'
      %{~ endif ~}
      %{~ endfor ~}
      #!
      %{~ for item in PREFIX_LISTS ~}
      %{~ if item.enable ~}
      set policy prefix-list ${item.name} rule ${item.rule} action '${item.action}'
      set policy prefix-list ${item.name} rule ${item.rule} prefix '${item.prefix}'
      %{~ endif ~}
      %{~ endfor ~}
      #!
      %{~ for item in ROUTE_MAPS ~}
      %{~ if item.enable && item.type == "as-list" ~}
      set policy route-map ${item.name} rule ${item.rule} action 'permit'
      set policy route-map ${item.name} rule ${item.rule} match as-path '${item.list}'
      set policy route-map ${item.name} rule ${item.rule} set metric '${item.set_metric}'
      %{~ endif ~}
      %{~ if item.enable && item.type == "pf-list" ~}
      set policy route-map ${item.name} rule ${item.rule} action ${item.action}
      set policy route-map ${item.name} rule ${item.rule} match ip address prefix-list '${item.list}'
      set policy route-map ${item.name} rule ${item.rule} set metric '${item.set_metric}'
      %{~ endif ~}
      %{~ endfor ~}
      #!
      commit
      #!
      %{~ if ENABLE_BGP ~}
      %{~ for session in BGP_SESSIONS ~}
      run reset ip bgp ${session.peer_ip}
      %{~ endfor ~}
      %{~ endif ~}
      save
      exit
      # Avoid manual config lock out (see e.g. https://forum.vyos.io/t/error-message-set-failed/296/5)
      chown -R root:vyattacfg /opt/vyatta/config/active/
      chown -R root:vyattacfg /opt/vyatta/etc/
