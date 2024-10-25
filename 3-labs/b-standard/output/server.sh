#! /bin/bash

exec > /var/log/gcp-startup.log 2>&1
export DEBIAN_FRONTEND=noninteractive

apt update
apt install -y python3-pip python3-dev python3-venv unzip jq tcpdump dnsutils net-tools nmap apache2-utils iperf3
apt -y install python3-flask python3-requests
apt install -y ca-certificates curl gnupg lsb-release
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
echo ""
docker version
docker compose version

mkdir -p /var/flaskapp/flaskapp/{static,templates}

cat <<EOF >/var/flaskapp/flaskapp/__init__.py
import socket
from flask import Flask, request
app = Flask(__name__)

@app.route("/")
def default():
    hostname = socket.gethostname()
    address = socket.gethostbyname(hostname)
    data_dict = {}
    data_dict['Hostname'] = hostname
    data_dict['server-ipv4'] = address
    data_dict['Remote-IP'] = request.remote_addr
    data_dict['Headers'] = dict(request.headers)
    return data_dict

@app.route("/path1")
def path1():
    hostname = socket.gethostname()
    address = socket.gethostbyname(hostname)
    data_dict = {}
    data_dict['app'] = 'PATH1-APP'
    data_dict['Hostname'] = hostname
    data_dict['server-ipv4'] = address
    data_dict['Remote-IP'] = request.remote_addr
    data_dict['Headers'] = dict(request.headers)
    return data_dict

@app.route("/path2")
def path2():
    hostname = socket.gethostname()
    address = socket.gethostbyname(hostname)
    data_dict = {}
    data_dict['app'] = 'PATH2-APP'
    data_dict['Hostname'] = hostname
    data_dict['server-ipv4'] = address
    data_dict['Remote-IP'] = request.remote_addr
    data_dict['Headers'] = dict(request.headers)
    return data_dict

if __name__ == "__main__":
    app.run(host= '0.0.0.0', port=80, debug = True)
EOF

cat <<EOF >/etc/systemd/system/flaskapp.service
[Unit]
Description=Script for flaskapp service

[Service]
Type=simple
ExecStart=/usr/bin/python3 /var/flaskapp/flaskapp/__init__.py
ExecStop=/usr/bin/pkill -f /var/flaskapp/flaskapp/__init__.py
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable flaskapp.service
systemctl restart flaskapp.service

########################################################
# test scripts (ipv4)
########################################################

# ping-ipv4

cat <<'EOF' >/usr/local/bin/ping-ipv4
echo -e "\n ping ipv4 ...\n"
echo "site1-vm       - 10.10.1.9 -$(timeout 3 ping -4 -qc2 -W1 10.10.1.9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "hub-eu-vm      - 10.1.11.9 -$(timeout 3 ping -4 -qc2 -W1 10.1.11.9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke1-eu-vm   - 10.11.11.9 -$(timeout 3 ping -4 -qc2 -W1 10.11.11.9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "hub-eu-ilb    - 10.1.11.70 -$(timeout 3 ping -4 -qc2 -W1 10.1.11.70 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "hub-eu-nlb    - 10.1.11.80 -$(timeout 3 ping -4 -qc2 -W1 10.1.11.80 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "hub-eu-alb    - 10.1.11.90 -$(timeout 3 ping -4 -qc2 -W1 10.1.11.90 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke1-eu-ilb - 10.11.11.30 -$(timeout 3 ping -4 -qc2 -W1 10.11.11.30 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke1-eu-nlb - 10.11.11.40 -$(timeout 3 ping -4 -qc2 -W1 10.11.11.40 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke1-eu-alb - 10.11.11.50 -$(timeout 3 ping -4 -qc2 -W1 10.11.11.50 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke1-eu-psc-ilb - 10.22.11.60 -$(timeout 3 ping -4 -qc2 -W1 10.22.11.60 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke1-eu-psc-nlb - 10.22.11.70 -$(timeout 3 ping -4 -qc2 -W1 10.22.11.70 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke1-eu-psc-alb - 10.22.11.80 -$(timeout 3 ping -4 -qc2 -W1 10.22.11.80 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "site2-vm       - 10.20.1.9 -$(timeout 3 ping -4 -qc2 -W1 10.20.1.9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "hub-us-vm      - 10.1.21.9 -$(timeout 3 ping -4 -qc2 -W1 10.1.21.9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke2-us-vm   - 10.22.21.9 -$(timeout 3 ping -4 -qc2 -W1 10.22.21.9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "hub-us-ilb    - 10.1.21.70 -$(timeout 3 ping -4 -qc2 -W1 10.1.21.70 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "hub-us-nlb    - 10.1.21.90 -$(timeout 3 ping -4 -qc2 -W1 10.1.21.90 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "hub-us-alb    - 10.1.21.80 -$(timeout 3 ping -4 -qc2 -W1 10.1.21.80 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke2-us-ilb - 10.22.21.30 -$(timeout 3 ping -4 -qc2 -W1 10.22.21.30 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke2-us-nlb - 10.22.21.40 -$(timeout 3 ping -4 -qc2 -W1 10.22.21.40 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke2-us-alb - 10.22.21.50 -$(timeout 3 ping -4 -qc2 -W1 10.22.21.50 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "internet - icanhazip.com -$(timeout 3 ping -4 -qc2 -W1 icanhazip.com 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "www - www.googleapis.com -$(timeout 3 ping -4 -qc2 -W1 www.googleapis.com 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "storage - storage.googleapis.com -$(timeout 3 ping -4 -qc2 -W1 storage.googleapis.com 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
EOF
chmod a+x /usr/local/bin/ping-ipv4

# ping-dns4

cat <<'EOF' >/usr/local/bin/ping-dns4
echo -e "\n ping dns ipv4 ...\n"
echo "vm.site1.corp - $(timeout 3 dig +short vm.site1.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 vm.site1.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.eu.hub.g.corp - $(timeout 3 dig +short vm.eu.hub.g.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 vm.eu.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.eu.spoke1.g.corp - $(timeout 3 dig +short vm.eu.spoke1.g.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 vm.eu.spoke1.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "ilb.eu.hub.g.corp - $(timeout 3 dig +short ilb.eu.hub.g.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 ilb.eu.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "nlb.eu.hub.g.corp - $(timeout 3 dig +short nlb.eu.hub.g.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 nlb.eu.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "alb.eu.hub.g.corp - $(timeout 3 dig +short alb.eu.hub.g.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 alb.eu.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "ilb.eu.spoke1.g.corp - $(timeout 3 dig +short ilb.eu.spoke1.g.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 ilb.eu.spoke1.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "nlb.eu.spoke1.g.corp - $(timeout 3 dig +short nlb.eu.spoke1.g.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 nlb.eu.spoke1.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "alb.eu.spoke1.g.corp - $(timeout 3 dig +short alb.eu.spoke1.g.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 alb.eu.spoke1.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "ep.eu.spoke1-eu-ilb.spoke2.g.corp - $(timeout 3 dig +short ep.eu.spoke1-eu-ilb.spoke2.g.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 ep.eu.spoke1-eu-ilb.spoke2.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "ep.eu.spoke1-eu-nlb.spoke2.g.corp - $(timeout 3 dig +short ep.eu.spoke1-eu-nlb.spoke2.g.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 ep.eu.spoke1-eu-nlb.spoke2.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "ep.eu.spoke1-eu-alb.spoke2.g.corp - $(timeout 3 dig +short ep.eu.spoke1-eu-alb.spoke2.g.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 ep.eu.spoke1-eu-alb.spoke2.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.site2.corp - $(timeout 3 dig +short vm.site2.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 vm.site2.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.us.hub.g.corp - $(timeout 3 dig +short vm.us.hub.g.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 vm.us.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.us.spoke2.g.corp - $(timeout 3 dig +short vm.us.spoke2.g.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 vm.us.spoke2.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "ilb.us.hub.g.corp - $(timeout 3 dig +short ilb.us.hub.g.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 ilb.us.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "nlb.us.hub.g.corp - $(timeout 3 dig +short nlb.us.hub.g.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 nlb.us.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "alb.us.hub.g.corp - $(timeout 3 dig +short alb.us.hub.g.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 alb.us.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "ilb.us.spoke2.g.corp - $(timeout 3 dig +short ilb.us.spoke2.g.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 ilb.us.spoke2.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "nlb.us.spoke2.g.corp - $(timeout 3 dig +short nlb.us.spoke2.g.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 nlb.us.spoke2.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "alb.us.spoke2.g.corp - $(timeout 3 dig +short alb.us.spoke2.g.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 alb.us.spoke2.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "icanhazip.com - $(timeout 3 dig +short icanhazip.com | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 icanhazip.com 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "www.googleapis.com - $(timeout 3 dig +short www.googleapis.com | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 www.googleapis.com 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "storage.googleapis.com - $(timeout 3 dig +short storage.googleapis.com | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 storage.googleapis.com 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
EOF
chmod a+x /usr/local/bin/ping-dns4

# curl-ipv4

cat <<'EOF' >/usr/local/bin/curl-ipv4
echo -e "\n curl ipv4 ...\n"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.10.1.9) - site1-vm       [10.10.1.9]"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.1.11.9) - hub-eu-vm      [10.1.11.9]"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.11.11.9) - spoke1-eu-vm   [10.11.11.9]"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.11.11.30) - spoke1-eu-ilb [10.11.11.30]"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.11.11.40) - spoke1-eu-nlb [10.11.11.40]"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.11.11.50) - spoke1-eu-alb [10.11.11.50]"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.22.11.60) - spoke1-eu-psc-ilb [10.22.11.60]"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.22.11.70) - spoke1-eu-psc-nlb [10.22.11.70]"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.22.11.80) - spoke1-eu-psc-alb [10.22.11.80]"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.20.1.9) - site2-vm       [10.20.1.9]"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.1.21.9) - hub-us-vm      [10.1.21.9]"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.22.21.9) - spoke2-us-vm   [10.22.21.9]"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.22.21.30) - spoke2-us-ilb [10.22.21.30]"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.22.21.40) - spoke2-us-nlb [10.22.21.40]"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.22.21.50) - spoke2-us-alb [10.22.21.50]"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null icanhazip.com) - internet [icanhazip.com]"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null www.googleapis.com) - www [www.googleapis.com]"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null storage.googleapis.com) - storage [storage.googleapis.com]"
EOF
chmod a+x /usr/local/bin/curl-ipv4

# curl-dns4

cat <<'EOF' >/usr/local/bin/curl-dns4
echo -e "\n curl dns ipv4 ...\n"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.site1.corp) - vm.site1.corp"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.eu.hub.g.corp) - vm.eu.hub.g.corp"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.eu.spoke1.g.corp) - vm.eu.spoke1.g.corp"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb.eu.spoke1.g.corp) - ilb.eu.spoke1.g.corp"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null nlb.eu.spoke1.g.corp) - nlb.eu.spoke1.g.corp"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null alb.eu.spoke1.g.corp) - alb.eu.spoke1.g.corp"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ep.eu.spoke1-eu-ilb.spoke2.g.corp) - ep.eu.spoke1-eu-ilb.spoke2.g.corp"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ep.eu.spoke1-eu-nlb.spoke2.g.corp) - ep.eu.spoke1-eu-nlb.spoke2.g.corp"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ep.eu.spoke1-eu-alb.spoke2.g.corp) - ep.eu.spoke1-eu-alb.spoke2.g.corp"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.site2.corp) - vm.site2.corp"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.us.hub.g.corp) - vm.us.hub.g.corp"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.us.spoke2.g.corp) - vm.us.spoke2.g.corp"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb.us.spoke2.g.corp) - ilb.us.spoke2.g.corp"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null nlb.us.spoke2.g.corp) - nlb.us.spoke2.g.corp"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null alb.us.spoke2.g.corp) - alb.us.spoke2.g.corp"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb.geo.hub.g.corp) - ilb.geo.hub.g.corp"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null icanhazip.com) - icanhazip.com"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null www.googleapis.com) - www.googleapis.com"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null storage.googleapis.com) - storage.googleapis.com"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null europe-west2-run.googleapis.com) - europe-west2-run.googleapis.com"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null us-west2-run.googleapis.com) - us-west2-run.googleapis.com"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null https://b-hub-us-run-httpbin-wapotrwjpq-nw.a.run.app) - https://b-hub-us-run-httpbin-wapotrwjpq-nw.a.run.app"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null https://b-spoke1-eu-run-httpbin-expmorqqnq-nw.a.run.app) - https://b-spoke1-eu-run-httpbin-expmorqqnq-nw.a.run.app"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null https://b-spoke2-us-run-httpbin-4e4skt6nna-wl.a.run.app) - https://b-spoke2-us-run-httpbin-4e4skt6nna-wl.a.run.app"
EOF
chmod a+x /usr/local/bin/curl-dns4

# trace-ipv4

cat <<'EOF' >/usr/local/bin/trace-ipv4
echo -e "\n trace ipv4 ...\n"
echo -e "\nsite1-vm      "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.10.1.9
echo -e "\nhub-eu-vm     "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.1.11.9
echo -e "\nspoke1-eu-vm  "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.11.11.9
echo -e "\nhub-eu-ilb   "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.1.11.70
echo -e "\nhub-eu-nlb   "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.1.11.80
echo -e "\nhub-eu-alb   "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.1.11.90
echo -e "\nspoke1-eu-ilb"
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.11.11.30
echo -e "\nspoke1-eu-nlb"
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.11.11.40
echo -e "\nspoke1-eu-alb"
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.11.11.50
echo -e "\nspoke1-eu-psc-ilb"
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.22.11.60
echo -e "\nspoke1-eu-psc-nlb"
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.22.11.70
echo -e "\nspoke1-eu-psc-alb"
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.22.11.80
echo -e "\nsite2-vm      "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.20.1.9
echo -e "\nhub-us-vm     "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.1.21.9
echo -e "\nspoke2-us-vm  "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.22.21.9
echo -e "\nhub-us-ilb   "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.1.21.70
echo -e "\nhub-us-nlb   "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.1.21.90
echo -e "\nhub-us-alb   "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.1.21.80
echo -e "\nspoke2-us-ilb"
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.22.21.30
echo -e "\nspoke2-us-nlb"
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.22.21.40
echo -e "\nspoke2-us-alb"
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.22.21.50
echo -e "\ninternet"
echo -e "-------------------------------------"
timeout 9 tracepath -4 icanhazip.com
echo -e "\nwww"
echo -e "-------------------------------------"
timeout 9 tracepath -4 www.googleapis.com
echo -e "\nstorage"
echo -e "-------------------------------------"
timeout 9 tracepath -4 storage.googleapis.com
EOF
chmod a+x /usr/local/bin/trace-ipv4

# ptr-ipv4

cat <<'EOF' >/usr/local/bin/ptr-ipv4
echo -e "\n PTR ipv4 ...\n"
arpa_zone=$(dig -x 10.11.11.30 | grep "QUESTION SECTION" -A 1 | tail -n 1 | awk '{print $1}')
ptr_record=$(timeout 3 dig -x 10.11.11.30 +short)
echo "spoke1-eu-ilb - 10.11.11.30 --> $ptr_record [$arpa_zone]"
arpa_zone=$(dig -x 10.11.11.40 | grep "QUESTION SECTION" -A 1 | tail -n 1 | awk '{print $1}')
ptr_record=$(timeout 3 dig -x 10.11.11.40 +short)
echo "spoke1-eu-nlb - 10.11.11.40 --> $ptr_record [$arpa_zone]"
arpa_zone=$(dig -x 10.11.11.50 | grep "QUESTION SECTION" -A 1 | tail -n 1 | awk '{print $1}')
ptr_record=$(timeout 3 dig -x 10.11.11.50 +short)
echo "spoke1-eu-alb - 10.11.11.50 --> $ptr_record [$arpa_zone]"
arpa_zone=$(dig -x 10.22.21.30 | grep "QUESTION SECTION" -A 1 | tail -n 1 | awk '{print $1}')
ptr_record=$(timeout 3 dig -x 10.22.21.30 +short)
echo "spoke2-us-ilb - 10.22.21.30 --> $ptr_record [$arpa_zone]"
arpa_zone=$(dig -x 10.22.21.40 | grep "QUESTION SECTION" -A 1 | tail -n 1 | awk '{print $1}')
ptr_record=$(timeout 3 dig -x 10.22.21.40 +short)
echo "spoke2-us-nlb - 10.22.21.40 --> $ptr_record [$arpa_zone]"
arpa_zone=$(dig -x 10.22.21.50 | grep "QUESTION SECTION" -A 1 | tail -n 1 | awk '{print $1}')
ptr_record=$(timeout 3 dig -x 10.22.21.50 +short)
echo "spoke2-us-alb - 10.22.21.50 --> $ptr_record [$arpa_zone]"
EOF
chmod a+x /usr/local/bin/ptr-ipv4

########################################################
# test scripts (ipv6)
########################################################

# ping-ipv6

cat <<'EOF' >/usr/local/bin/ping-ipv6
echo -e "\n ping ipv6 ...\n"
echo "hub-eu-nlb    - false -$(timeout 3 ping -6 -qc2 -W1 false 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "hub-eu-alb    - false -$(timeout 3 ping -6 -qc2 -W1 false 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke1-eu-nlb - false -$(timeout 3 ping -6 -qc2 -W1 false 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke1-eu-alb - false -$(timeout 3 ping -6 -qc2 -W1 false 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke1-eu-psc-nlb - false -$(timeout 3 ping -6 -qc2 -W1 false 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke1-eu-psc-alb - false -$(timeout 3 ping -6 -qc2 -W1 false 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "hub-us-nlb    - false -$(timeout 3 ping -6 -qc2 -W1 false 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "hub-us-alb    - false -$(timeout 3 ping -6 -qc2 -W1 false 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke2-us-nlb - false -$(timeout 3 ping -6 -qc2 -W1 false 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke2-us-alb - false -$(timeout 3 ping -6 -qc2 -W1 false 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
EOF
chmod a+x /usr/local/bin/ping-ipv6

# ping-dns6

cat <<'EOF' >/usr/local/bin/ping-dns6
echo -e "\n ping dns ipv6 ...\n"
echo "nlb.eu.hub.g.corp - $(timeout 3 dig AAAA +short nlb.eu.hub.g.corp | tail -n1) -$(timeout 3 ping -6 -qc2 -W1 nlb.eu.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "alb.eu.hub.g.corp - $(timeout 3 dig AAAA +short alb.eu.hub.g.corp | tail -n1) -$(timeout 3 ping -6 -qc2 -W1 alb.eu.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "nlb.eu.spoke1.g.corp - $(timeout 3 dig AAAA +short nlb.eu.spoke1.g.corp | tail -n1) -$(timeout 3 ping -6 -qc2 -W1 nlb.eu.spoke1.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "alb.eu.spoke1.g.corp - $(timeout 3 dig AAAA +short alb.eu.spoke1.g.corp | tail -n1) -$(timeout 3 ping -6 -qc2 -W1 alb.eu.spoke1.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "ep.eu.spoke1-eu-nlb.spoke2.g.corp - $(timeout 3 dig AAAA +short ep.eu.spoke1-eu-nlb.spoke2.g.corp | tail -n1) -$(timeout 3 ping -6 -qc2 -W1 ep.eu.spoke1-eu-nlb.spoke2.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "ep.eu.spoke1-eu-alb.spoke2.g.corp - $(timeout 3 dig AAAA +short ep.eu.spoke1-eu-alb.spoke2.g.corp | tail -n1) -$(timeout 3 ping -6 -qc2 -W1 ep.eu.spoke1-eu-alb.spoke2.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "nlb.us.hub.g.corp - $(timeout 3 dig AAAA +short nlb.us.hub.g.corp | tail -n1) -$(timeout 3 ping -6 -qc2 -W1 nlb.us.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "alb.us.hub.g.corp - $(timeout 3 dig AAAA +short alb.us.hub.g.corp | tail -n1) -$(timeout 3 ping -6 -qc2 -W1 alb.us.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "nlb.us.spoke2.g.corp - $(timeout 3 dig AAAA +short nlb.us.spoke2.g.corp | tail -n1) -$(timeout 3 ping -6 -qc2 -W1 nlb.us.spoke2.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "alb.us.spoke2.g.corp - $(timeout 3 dig AAAA +short alb.us.spoke2.g.corp | tail -n1) -$(timeout 3 ping -6 -qc2 -W1 alb.us.spoke2.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
EOF
chmod a+x /usr/local/bin/ping-dns6

# curl-ipv6

cat <<'EOF' >/usr/local/bin/curl-ipv6
echo -e "\n curl ipv6 ...\n"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null [false]) - spoke1-eu-nlb [false]"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null [false]) - spoke1-eu-alb [false]"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null [false]) - spoke1-eu-psc-nlb [false]"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null [false]) - spoke1-eu-psc-alb [false]"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null [false]) - spoke2-us-nlb [false]"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null [false]) - spoke2-us-alb [false]"
EOF
chmod a+x /usr/local/bin/curl-ipv6

# curl-dns6

cat <<'EOF' >/usr/local/bin/curl-dns6
echo -e "\n curl dns ipv6 ...\n"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.site1.corp) - vm.site1.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.eu.hub.g.corp) - vm.eu.hub.g.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.eu.spoke1.g.corp) - vm.eu.spoke1.g.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb.eu.spoke1.g.corp) - ilb.eu.spoke1.g.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null nlb.eu.spoke1.g.corp) - nlb.eu.spoke1.g.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null alb.eu.spoke1.g.corp) - alb.eu.spoke1.g.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ep.eu.spoke1-eu-ilb.spoke2.g.corp) - ep.eu.spoke1-eu-ilb.spoke2.g.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ep.eu.spoke1-eu-nlb.spoke2.g.corp) - ep.eu.spoke1-eu-nlb.spoke2.g.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ep.eu.spoke1-eu-alb.spoke2.g.corp) - ep.eu.spoke1-eu-alb.spoke2.g.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.site2.corp) - vm.site2.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.us.hub.g.corp) - vm.us.hub.g.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.us.spoke2.g.corp) - vm.us.spoke2.g.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb.us.spoke2.g.corp) - ilb.us.spoke2.g.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null nlb.us.spoke2.g.corp) - nlb.us.spoke2.g.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null alb.us.spoke2.g.corp) - alb.us.spoke2.g.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb.geo.hub.g.corp) - ilb.geo.hub.g.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null icanhazip.com) - icanhazip.com"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null www.googleapis.com) - www.googleapis.com"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null storage.googleapis.com) - storage.googleapis.com"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null europe-west2-run.googleapis.com) - europe-west2-run.googleapis.com"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null us-west2-run.googleapis.com) - us-west2-run.googleapis.com"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null https://b-hub-us-run-httpbin-wapotrwjpq-nw.a.run.app) - https://b-hub-us-run-httpbin-wapotrwjpq-nw.a.run.app"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null https://b-spoke1-eu-run-httpbin-expmorqqnq-nw.a.run.app) - https://b-spoke1-eu-run-httpbin-expmorqqnq-nw.a.run.app"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null https://b-spoke2-us-run-httpbin-4e4skt6nna-wl.a.run.app) - https://b-spoke2-us-run-httpbin-4e4skt6nna-wl.a.run.app"
EOF
chmod a+x /usr/local/bin/curl-dns6

# trace-ipv6

cat <<'EOF' >/usr/local/bin/trace-ipv6
echo -e "\n trace ipv6 ...\n"
echo -e "\nhub-eu-nlb   "
echo -e "-------------------------------------"
timeout 9 tracepath -6 false
echo -e "\nhub-eu-alb   "
echo -e "-------------------------------------"
timeout 9 tracepath -6 false
echo -e "\nspoke1-eu-nlb"
echo -e "-------------------------------------"
timeout 9 tracepath -6 false
echo -e "\nspoke1-eu-alb"
echo -e "-------------------------------------"
timeout 9 tracepath -6 false
echo -e "\nspoke1-eu-psc-nlb"
echo -e "-------------------------------------"
timeout 9 tracepath -6 false
echo -e "\nspoke1-eu-psc-alb"
echo -e "-------------------------------------"
timeout 9 tracepath -6 false
echo -e "\nhub-us-nlb   "
echo -e "-------------------------------------"
timeout 9 tracepath -6 false
echo -e "\nhub-us-alb   "
echo -e "-------------------------------------"
timeout 9 tracepath -6 false
echo -e "\nspoke2-us-nlb"
echo -e "-------------------------------------"
timeout 9 tracepath -6 false
echo -e "\nspoke2-us-alb"
echo -e "-------------------------------------"
timeout 9 tracepath -6 false
EOF
chmod a+x /usr/local/bin/trace-ipv6

#########################################################
# other scripts
#########################################################

# dns-info

cat <<'EOF' >/usr/local/bin/dns-info
echo -e "\n resolvectl ...\n"
resolvectl status
EOF
chmod a+x /usr/local/bin/dns-info

########################################################
# traffic generators (ipv4)
########################################################

# light-traffic generator


# heavy-traffic generator


########################################################
# traffic generators (ipv6)
########################################################

# light-traffic generator


# heavy-traffic generator


########################################################
# crontabs
########################################################

cat <<'EOF' >/etc/cron.d/traffic-gen
EOF

crontab /etc/cron.d/traffic-gen
