#! /bin/bash

apt update
apt install -y tcpdump fping dnsutils python3-pip python-dev wget mariadb-client-10.3
pip3 install Flask requests

wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O /usr/local/bin/cloud_sql_proxy
chmod +x /usr/local/bin/cloud_sql_proxy

sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
sysctl -w net.ipv4.conf.all.forwarding=1
sysctl -w net.ipv4.conf.all.route_localnet=1

export INT="http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/"
export PROXY_IP=$(curl -H "Metadata-Flavor: Google" $INT/0/ip)

iptables -t nat -A POSTROUTING -o ens4 -j SNAT --to-source $PROXY_IP
iptables -A PREROUTING -t nat -i ens4 -d $PROXY_IP -p tcp --dport ${PORT} -j DNAT --to-destination ${SQL_IP}:${PORT}

nohup cloud_sql_proxy -instances=${PROJECT_SQL}:${REGION}:${INSTANCE}=tcp:${PORT} > /dev/null 2>&1 &
echo $! > /var/tmp/nohup.txt

# flask-web
#-----------------------------------
mkdir /var/flaskapp
mkdir /var/flaskapp/flaskapp
mkdir /var/flaskapp/flaskapp/static
mkdir /var/flaskapp/flaskapp/templates

cat <<EOF > /var/flaskapp/flaskapp/__init__.py
import os
from flask import Flask, request
app = Flask(__name__)

@app.route("/")
def headers():
    return 'hello world!'

if __name__ == "__main__":
    app.run(host= '0.0.0.0', port=${WEB_PORT}, debug = True)
EOF

export URL="http://metadata.google.internal/computeMetadata/v1/instance/"
export ZONE_URI=$(curl -H "Metadata-Flavor: Google" $URL/zone)
export ZONE=`echo "$ZONE_URI" | awk -F/ '{print $4}'`
export VM_NAME=$(curl -H "Metadata-Flavor: Google" $URL/name)
export GATEWAY=$(curl -H "Metadata-Flavor: Google" $URL/network-interfaces/0/gateway)
export IP_ADDR_0=$(curl -H "Metadata-Flavor: Google" $URL/network-interfaces/0/ip)
nohup python3 /var/flaskapp/flaskapp/__init__.py &

cat <<EOF > /var/tmp/startup.sh
  export URL="http://metadata.google.internal/computeMetadata/v1/instance/"
  export ZONE_URI=\$(curl -H "Metadata-Flavor: Google" \$URL/zone)
  export ZONE=`echo "\$ZONE_URI" | awk -F/ '{print \$4}'`
  export VM_NAME=\$(curl -H "Metadata-Flavor: Google" \$URL/name)
  export GATEWAY=\$(curl -H "Metadata-Flavor: Google" \$URL/network-interfaces/0/gateway)
  export IP_ADDR_0=\$(curl -H "Metadata-Flavor: Google" \$URL/network-interfaces/0/ip)
  nohup python3 /var/flaskapp/flaskapp/__init__.py &
EOF

echo "@reboot source /var/tmp/startup.sh" >> /var/tmp/crontab-flask.txt
crontab /var/tmp/crontab-flask.txt

# sql_kill
#-----------------------------------
cat <<EOF > /usr/local/bin/sql_kill
ps -ef | grep cloud_sql_proxy | grep -v grep | awk '{print $2}' | xargs kill
EOF
chmod a+x /usr/local/bin/sql_kill

%{ for item in SQL_ACCESS_VIA_LOCAL_HOST ~}
# ${item.script_name}
#-----------------------------------
cat <<EOF > /usr/local/bin/${item.script_name}
cloud_sql_proxy -instances=${item.project}:${item.region}:${item.instance}=tcp:${item.port} > /dev/null 2>&1 &
echo "Show DB ${item.script_name}..."
echo mysql --host=127.0.0.1 --user=${item.user} --password=${item.password} -e \"SHOW DATABASES\"
mysql --host=127.0.0.1 --user=${item.user} --password=${item.password} -e "SHOW DATABASES"
EOF
chmod a+x /usr/local/bin/${item.script_name}
%{ endfor ~}

%{ for item in SQL_ACCESS_VIA_PROXY }
# ${item.script_name}
#-----------------------------------
cat <<EOF > /usr/local/bin/${item.script_name}
echo "Show DB ${item.script_name}..."
echo mysql --host=${item.sql_proxy_ip} --user=${item.user} --password=${item.password} -e \"SHOW DATABASES\"
mysql --host=${item.sql_proxy_ip} --user=${item.user} --password=${item.password} -e "SHOW DATABASES"
EOF
chmod a+x /usr/local/bin/${item.script_name}
%{ endfor }
