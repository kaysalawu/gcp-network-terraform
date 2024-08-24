#! /bin/bash

apt update
apt install -y tcpdump fping dnsutils python3-pip python-dev conntrack
pip3 install Flask requests

sysctl -w net.ipv4.conf.all.forwarding=1
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p

export INT="http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/"

export ENS4=$(curl -H "Metadata-Flavor: Google" $INT/0/ip)
export ENS4_MASK=$(curl -H "Metadata-Flavor: Google" $INT/0/subnetmask)
export ENS4_DGW=$(curl -H "Metadata-Flavor: Google" $INT/0/gateway)

export ENS5=$(curl -H "Metadata-Flavor: Google" $INT/1/ip)
export ENS5_MASK=$(curl -H "Metadata-Flavor: Google" $INT/1/subnetmask)
export ENS5_DGW=$(curl -H "Metadata-Flavor: Google" $INT/1/gateway)

export ENS6=$(curl -H "Metadata-Flavor: Google" $INT/2/ip)
export ENS6_MASK=$(curl -H "Metadata-Flavor: Google" $INT/2/subnetmask)
export ENS6_DGW=$(curl -H "Metadata-Flavor: Google" $INT/2/gateway)

# ip tables
#-----------------------------------

# iptable rules specific to lb
%{~ for rule in IPTABLES_RULES }
${rule}
%{~ endfor }

# ens5 (int vpc) routing
#-----------------------------------
echo "1 rt5" | sudo tee -a /etc/iproute2/rt_tables

# all traffic from/to ens5 should use rt5 for lookup
# subnet mask is used to expand entire range to include ilb vip
ip rule add from $ENS5_DGW/$ENS5_MASK table rt5
ip rule add to $ENS5_DGW/$ENS5_MASK table rt5
%{~ for RANGE in ENS5_LINKED_NETWORKS }
ip rule add to ${RANGE} table rt5
%{~ endfor }

# send return gfe-traffic via ens5
%{~ for RANGE in GOOGLE_RANGES }
ip route add ${RANGE} via $ENS5_DGW dev ens5 table rt5
%{~ endfor }

# send traffic to peered vpc via ens5
%{~ for RANGE in ENS5_LINKED_NETWORKS }
ip route add ${RANGE} via $ENS5_DGW dev ens5 table rt5
%{~ endfor }

# ens6 (mgt vpc) routing
#-----------------------------------
echo "2 rt6" | sudo tee -a /etc/iproute2/rt_tables

# all traffic from/to ens6 should use rt6 for lookup
# subnet mask is used to expand entire range to include ilb vip
ip rule add from $ENS6_DGW/$ENS6_MASK table rt6
ip rule add to $ENS6_DGW/$ENS6_MASK table rt6
%{~ for RANGE in ENS6_LINKED_NETWORKS }
ip rule add to ${RANGE} table rt6
%{~ endfor }

# send return gfe-traffic via ens6
%{~ for RANGE in GOOGLE_RANGES }
ip route add ${RANGE} via $ENS6_DGW dev ens6 table rt6
%{~ endfor }

# send traffic to remote mgt subnet
%{~ for RANGE in ENS6_LINKED_NETWORKS }
ip route add ${RANGE} via $ENS6_DGW dev ens6 table rt6
%{~ endfor }

# all other traffic go via default to ens4 (untrust vpc)

# health check web server
#-----------------------------------
mkdir /var/flaskapp
mkdir /var/flaskapp/flaskapp
mkdir /var/flaskapp/flaskapp/static
mkdir /var/flaskapp/flaskapp/templates

cat <<EOF > /var/flaskapp/flaskapp/__init__.py
from flask import Flask, request
app = Flask(__name__)
@app.route('/${HEALTH_CHECK.path}')
def ${HEALTH_CHECK.path}():
    return '${HEALTH_CHECK.response}'
if __name__ == "__main__":
    app.run(host= '0.0.0.0', port=${HEALTH_CHECK.port}, debug = True)
EOF
nohup python3 /var/flaskapp/flaskapp/__init__.py &
cat <<EOF > /var/tmp/startup.sh
nohup python3 /var/flaskapp/flaskapp/__init__.py &
EOF
echo "@reboot source /var/tmp/startup.sh" > /var/tmp/crontab.txt
crontab /var/tmp/crontab.txt

# playz script
#-----------------------------------
cat <<EOF > /usr/local/bin/playz
echo -e "\n curl ...\n"
%{ for TARGET in targets_curl_dns ~}
echo  "\$(curl -kL -H 'Cache-Control: no-cache' --connect-timeout 1 -w "%%{http_code} (%%{time_total}s) - %%{remote_ip}" -s -o /dev/null ${TARGET}) - ${TARGET}"
%{ endfor ~}
echo ""
%{ for TARGET in TARGETS_PSC ~}
echo  "\$(curl -kL -H 'Cache-Control: no-cache' --connect-timeout 1 -w "%%{http_code} (%%{time_total}s) - %%{remote_ip}" -s -o /dev/null ${TARGET}) - ${TARGET}"
%{ endfor ~}
echo ""
%{ for TARGET in TARGETS_PGA ~}
echo  "\$(curl -kL -H 'Cache-Control: no-cache' --connect-timeout 1 -w "%%{http_code} (%%{time_total}s) - %%{remote_ip}" -s -o /dev/null ${TARGET}) - ${TARGET}"
%{ endfor ~}
echo ""
EOF
chmod a+x /usr/local/bin/playz
