#! /bin/bash

apt update -y
apt install -y stress tcpdump procps

nohup stress -c ${VCPU} &
echo $! > /tmp/stress_pid.txt

cat <<EOF > /tmp/stress_kill.sh
kill -9 `cat /tmp/stress_pid.txt`
rm /tmp/stress_pid.txt
EOF

iptables-legacy -t nat -A POSTROUTING -j RETURN -d ${VM_IP} -p udp --dport ${PORT}
iptables-legacy -t nat -A PREROUTING -d ${NLB_VIP} -p udp --dport ${PORT} -j DNAT --to-destination ${VM_IP}

# https://cloud.google.com/architecture/udp-with-network-load-balancing
