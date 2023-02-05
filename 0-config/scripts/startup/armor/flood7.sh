#! /bin/bash

apt update -y
apt install -y tcpdump fping dnsutils netsniff-ng apache2-utils wrk netcatz

# adaptive protection alert generator

cat <<EOF > /usr/local/bin/ddos7
#! /bin/bash
RANDOM=\$(date +%s)
RAND=\$(( $RANDOM % 1000 ))
wrk -t20 -c800 -d\$1 ${TARGET_URL} --header "User-Agent: wrk-DDOS\$RAND"
EOF
chmod a+x /usr/local/bin/ddos7

cat <<EOF > /tmp/crontab.txt
*/20 * * * * /usr/local/bin/ddos7 5m 2>&1 > /dev/null
*/20 * * * * /usr/local/bin/ddos7 5m 2>&1 > /dev/null
EOF
crontab /tmp/crontab.txt
