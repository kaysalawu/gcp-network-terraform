#! /bin/bash

apt update -y
apt install -y stress tcpdump procps

nohup stress -c ${VCPU} &
echo $! > /tmp/stress_pid.txt

cat <<EOF > /tmp/stress_kill.sh
kill -9 `cat /tmp/stress_pid.txt`
rm /tmp/stress_pid.txt
EOF
