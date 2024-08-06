configure

set deviceconfig system timezone Europe/London
set deviceconfig system hostname ${HOST_NAME}
set deviceconfig system dns-setting servers primary 8.8.8.8
set deviceconfig system dns-setting servers secondary 8.8.4.4

set network profiles interface-management-profile allow-management https yes
set network profiles interface-management-profile allow-management ssh yes
set network profiles interface-management-profile allow-management ping yes

set network interface ethernet ethernet1/1 layer3 dhcp-client
set network interface ethernet ethernet1/1 layer3 mtu 1460
set network interface ethernet ethernet1/1 layer3 adjust-tcp-mss enable yes
set network interface ethernet ethernet1/1 layer3 interface-management-profile allow-management

set network interface ethernet ethernet1/2 layer3 dhcp-client create-default-route no
set network interface ethernet ethernet1/2 layer3 mtu 1460
set network interface ethernet ethernet1/2 layer3 adjust-tcp-mss enable yes
set network interface ethernet ethernet1/2 layer3 interface-management-profile allow-management

set network virtual-router default interface ethernet1/1
set network virtual-router default interface ethernet1/2
%{~ for k,v in STATIC_ROUTES }
set network virtual-router default routing-table ip static-route ${k} destination ${v.destination}
set network virtual-router default routing-table ip static-route ${k} nexthop ip-address ${v.next_hop}
set network virtual-router default routing-table ip static-route ${k} interface ${v.interface}
%{~ endfor }

set zone untrust network layer3 ethernet1/1
set zone trust network layer3 ethernet1/2

%{~ for k,v in SERVICES }
set service ${k} protocol tcp port ${v.port}
%{~ endfor }

%{~ for k,v in NAT_RULES }
set rulebase nat rules ${k} service ${v.service}
set rulebase nat rules ${k} from ${v.zone_from}
set rulebase nat rules ${k} to ${v.zone_to}
set rulebase nat rules ${k} source ${v.source}
set rulebase nat rules ${k} destination ${v.destination}
%{~ if v.snat.enable }
set rulebase nat rules ${k} source-translation dynamic-ip-and-port interface-address ${v.snat.interface}
%{~ endif }
%{~ if v.dnat.enable }
set rulebase nat rules ${k} destination-translation translated-address ${v.dnat.translated_address}
%{~ endif }
%{ endfor }

%{~ for k,v in APPLICATIONS }
set application ${k} default port ${v.port}
set application ${k} signature ${k}-sig and-condition "And Condition 1" or-condition "Or Condition 1" operator pattern-match pattern ${v.host}
set application ${k} signature ${k}-sig and-condition "And Condition 1" or-condition "Or Condition 1" operator pattern-match context http-req-host-header
set application ${k} category networking
set application ${k} subcategory infrastructure
set application ${k} technology browser-based
set application ${k} risk 1
%{ endfor }

%{~ for k,v in SECURITY_RULES }
set rulebase security rules ${k} from ${v.from}
set rulebase security rules ${k} to ${v.to}
set rulebase security rules ${k} source ${v.source}
set rulebase security rules ${k} destination ${v.destination}
set rulebase security rules ${k} source-user ${v.source_user}
set rulebase security rules ${k} category ${v.category}
set rulebase security rules ${k} application ${v.application}
set rulebase security rules ${k} service ${v.service}
set rulebase security rules ${k} hip-profiles ${v.hip_profiles}
set rulebase security rules ${k} action ${v.action}
%{ endfor }

set import network interface ethernet1/2

commit

set mgt-config users admin password
