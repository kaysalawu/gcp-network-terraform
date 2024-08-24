#! /bin/bash

apt update
apt install -y tcpdump

wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O /usr/local/bin/cloud_sql_proxy
chmod +x /usr/local/bin/cloud_sql_proxy

sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
sysctl -w net.ipv4.conf.all.forwarding=1
sysctl -w net.ipv4.conf.all.route_localnet=1

export INT="http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/"
export ENS4_ADDR=$(curl -H "Metadata-Flavor: Google" $INT/0/ip)

%{~ for item in DNS_TARGETS }
iptables -t nat -A POSTROUTING -p udp --dport 53 -j SNAT --to-source $ENS4_ADDR
iptables -t nat -A POSTROUTING -p tcp --dport 53 -j SNAT --to-source $ENS4_ADDR
%{~ endfor }
