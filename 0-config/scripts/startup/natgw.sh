#! /bin/bash

apt update
apt install -y tcpdump dnsutils conntrack

sysctl -w net.ipv4.conf.all.forwarding=1
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p

iptables -t nat -A POSTROUTING -o ens4 -j MASQUERADE
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -F
