#! /bin/bash

apt update
apt install -y tcpdump fping dnsutils netsniff-ng apache2-utils wrk netcat

# adaptive protection alert generator

cat <<EOF > /usr/local/bin/adaptive
#! /bin/bash
wrk -t20 -c1000 -d\$1  ${TARGET_URL} --header "User-Agent: wrk-DDOS"
EOF
chmod a+x /usr/local/bin/adaptive

cat <<EOF > /tmp/crontab.txt
*/30 * * * * /usr/local/bin/adaptive 2m 2>&1 > /dev/null
*/30 * * * * /usr/local/bin/adaptive 2m 2>&1 > /dev/null
*/30 * * * * /usr/local/bin/adaptive 2m 2>&1 > /dev/null
EOF
crontab /tmp/crontab.txt
