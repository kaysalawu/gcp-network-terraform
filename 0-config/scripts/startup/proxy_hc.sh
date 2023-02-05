#! /bin/bash

apt update
apt install -y tcpdump

sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
sysctl -w net.ipv4.conf.all.forwarding=1
sysctl -w net.ipv4.conf.all.route_localnet=1

export INT="http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/"
export PROXY_IP=$(curl -H "Metadata-Flavor: Google" $INT/0/ip)
iptables -t nat -A POSTROUTING -o ens4 -j SNAT --to-source $PROXY_IP
%{~ for range in GFE_RANGES }
iptables -A PREROUTING -t nat -i ens4 -s ${range} -d $PROXY_IP -j DNAT --to-destination ${DNAT_IP}
%{~ endfor ~}
