#! /bin/bash

apt update
apt install -y tcpdump fping dnsutils netsniff-ng apache2-utils wrk netcat

# base-line generator

cat <<EOF > /usr/local/bin/probez
#! /bin/bash
i=0
while [ \$i -lt 6 ]; do
  ab -H "Referer: http://cloud.google.com" -n \$1 -c \$2 ${TARGET_URL} > /dev/null 2>&1
  let i=i+1
  sleep 3
done
EOF
chmod a+x /usr/local/bin/probez

cat <<EOF > /tmp/crontab.txt
*/1 * * * * /usr/local/bin/probez 50 1 2>&1 > /dev/null
*/2 * * * * /usr/local/bin/probez 8 2 2>&1 > /dev/null
*/3 * * * * /usr/local/bin/probez 20 4 2>&1 > /dev/null
*/5 * * * * /usr/local/bin/probez 15 2 2>&1 > /dev/null
EOF
crontab /tmp/crontab.txt
