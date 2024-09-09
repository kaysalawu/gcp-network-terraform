#! /bin/bash

exec > /var/log/gcp-startup.log
export DEBIAN_FRONTEND=noninteractive

apt update
apt install -y python3-pip python3-dev python3-venv unzip jq tcpdump dnsutils net-tools nmap apache2-utils iperf3
apt -y install python3-flask python3-requests

mkdir -p /var/flaskapp/flaskapp/{static,templates}

cat <<EOF > /var/flaskapp/flaskapp/__init__.py
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

cat <<EOF > /etc/systemd/system/flaskapp.service
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

cat <<'EOF' > /usr/local/bin/ping-ipv4
echo -e "\n ping ipv4 ...\n"
echo "site1-vm       - 10.10.1.9 -$(timeout 5 ping -4 -qc2 -W1 10.10.1.9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "hub-eu-vm      - 10.1.11.9 -$(timeout 5 ping -4 -qc2 -W1 10.1.11.9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke1-eu-vm   - 10.11.11.9 -$(timeout 5 ping -4 -qc2 -W1 10.11.11.9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke2-eu-vm   - 10.22.11.9 -$(timeout 5 ping -4 -qc2 -W1 10.22.11.9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "hub-eu-ilb4    - 10.1.11.70 -$(timeout 5 ping -4 -qc2 -W1 10.1.11.70 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "hub-eu-ilb7    - 10.1.11.80 -$(timeout 5 ping -4 -qc2 -W1 10.1.11.80 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke1-eu-ilb4 - 10.11.11.30 -$(timeout 5 ping -4 -qc2 -W1 10.11.11.30 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke1-eu-ilb7 - 10.11.11.40 -$(timeout 5 ping -4 -qc2 -W1 10.11.11.40 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "site2-vm       - 10.20.1.9 -$(timeout 5 ping -4 -qc2 -W1 10.20.1.9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "hub-us-vm      - 10.1.21.9 -$(timeout 5 ping -4 -qc2 -W1 10.1.21.9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke2-us-vm   - 10.22.21.9 -$(timeout 5 ping -4 -qc2 -W1 10.22.21.9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "hub-us-ilb4    - 10.1.21.70 -$(timeout 5 ping -4 -qc2 -W1 10.1.21.70 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "hub-us-ilb7    - 10.1.21.80 -$(timeout 5 ping -4 -qc2 -W1 10.1.21.80 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke2-us-ilb4 - 10.22.21.30 -$(timeout 5 ping -4 -qc2 -W1 10.22.21.30 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke2-us-ilb7 - 10.22.21.40 -$(timeout 5 ping -4 -qc2 -W1 10.22.21.40 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "internet - icanhazip.com -$(timeout 5 ping -4 -qc2 -W1 icanhazip.com 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
EOF
chmod a+x /usr/local/bin/ping-ipv4

# ping-dns4

cat <<'EOF' > /usr/local/bin/ping-dns4
echo -e "\n ping dns ipv4 ...\n"
echo "vm.site1.corp - $(timeout 5 dig +short vm.site1.corp | tail -n1) -$(timeout 5 ping -4 -qc2 -W1 vm.site1.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.eu.hub.g.corp - $(timeout 5 dig +short vm.eu.hub.g.corp | tail -n1) -$(timeout 5 ping -4 -qc2 -W1 vm.eu.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.eu.spoke1.g.corp - $(timeout 5 dig +short vm.eu.spoke1.g.corp | tail -n1) -$(timeout 5 ping -4 -qc2 -W1 vm.eu.spoke1.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.eu.spoke2.g.corp - $(timeout 5 dig +short vm.eu.spoke2.g.corp | tail -n1) -$(timeout 5 ping -4 -qc2 -W1 vm.eu.spoke2.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "ilb4.eu.hub.g.corp - $(timeout 5 dig +short ilb4.eu.hub.g.corp | tail -n1) -$(timeout 5 ping -4 -qc2 -W1 ilb4.eu.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "ilb7.eu.hub.g.corp - $(timeout 5 dig +short ilb7.eu.hub.g.corp | tail -n1) -$(timeout 5 ping -4 -qc2 -W1 ilb7.eu.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "ilb4.eu.spoke1.g.corp - $(timeout 5 dig +short ilb4.eu.spoke1.g.corp | tail -n1) -$(timeout 5 ping -4 -qc2 -W1 ilb4.eu.spoke1.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "ilb7.eu.spoke1.g.corp - $(timeout 5 dig +short ilb7.eu.spoke1.g.corp | tail -n1) -$(timeout 5 ping -4 -qc2 -W1 ilb7.eu.spoke1.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.site2.corp - $(timeout 5 dig +short vm.site2.corp | tail -n1) -$(timeout 5 ping -4 -qc2 -W1 vm.site2.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.us.hub.g.corp - $(timeout 5 dig +short vm.us.hub.g.corp | tail -n1) -$(timeout 5 ping -4 -qc2 -W1 vm.us.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.us.spoke2.g.corp - $(timeout 5 dig +short vm.us.spoke2.g.corp | tail -n1) -$(timeout 5 ping -4 -qc2 -W1 vm.us.spoke2.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "ilb4.us.hub.g.corp - $(timeout 5 dig +short ilb4.us.hub.g.corp | tail -n1) -$(timeout 5 ping -4 -qc2 -W1 ilb4.us.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "ilb7.us.hub.g.corp - $(timeout 5 dig +short ilb7.us.hub.g.corp | tail -n1) -$(timeout 5 ping -4 -qc2 -W1 ilb7.us.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "ilb4.us.spoke2.g.corp - $(timeout 5 dig +short ilb4.us.spoke2.g.corp | tail -n1) -$(timeout 5 ping -4 -qc2 -W1 ilb4.us.spoke2.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "ilb7.us.spoke2.g.corp - $(timeout 5 dig +short ilb7.us.spoke2.g.corp | tail -n1) -$(timeout 5 ping -4 -qc2 -W1 ilb7.us.spoke2.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "icanhazip.com - $(timeout 5 dig +short icanhazip.com | tail -n1) -$(timeout 5 ping -4 -qc2 -W1 icanhazip.com 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
EOF
chmod a+x /usr/local/bin/ping-dns4

# curl-ipv4

cat <<'EOF' > /usr/local/bin/curl-ipv4
echo -e "\n curl ipv4 ...\n"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.10.1.9) - site1-vm       [10.10.1.9]"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.1.11.9) - hub-eu-vm      [10.1.11.9]"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.11.11.9) - spoke1-eu-vm   [10.11.11.9]"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.22.11.9) - spoke2-eu-vm   [10.22.11.9]"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.1.11.70) - hub-eu-ilb4    [10.1.11.70]"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.1.11.80) - hub-eu-ilb7    [10.1.11.80]"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.11.11.30) - spoke1-eu-ilb4 [10.11.11.30]"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.11.11.40) - spoke1-eu-ilb7 [10.11.11.40]"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.20.1.9) - site2-vm       [10.20.1.9]"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.1.21.9) - hub-us-vm      [10.1.21.9]"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.22.21.9) - spoke2-us-vm   [10.22.21.9]"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.1.21.70) - hub-us-ilb4    [10.1.21.70]"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.1.21.80) - hub-us-ilb7    [10.1.21.80]"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.22.21.30) - spoke2-us-ilb4 [10.22.21.30]"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.22.21.40) - spoke2-us-ilb7 [10.22.21.40]"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null icanhazip.com) - internet [icanhazip.com]"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null www.googleapis.com) - www [www.googleapis.com]"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null storage.googleapis.com) - storage [storage.googleapis.com]"
EOF
chmod a+x /usr/local/bin/curl-ipv4

# curl-dns4

cat <<'EOF' > /usr/local/bin/curl-dns4
echo -e "\n curl dns ipv4 ...\n"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.site1.corp) - vm.site1.corp"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.eu.hub.g.corp) - vm.eu.hub.g.corp"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.eu.spoke1.g.corp) - vm.eu.spoke1.g.corp"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.eu.spoke2.g.corp) - vm.eu.spoke2.g.corp"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb4.eu.hub.g.corp) - ilb4.eu.hub.g.corp"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb7.eu.hub.g.corp) - ilb7.eu.hub.g.corp"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb4.eu.spoke1.g.corp) - ilb4.eu.spoke1.g.corp"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb7.eu.spoke1.g.corp) - ilb7.eu.spoke1.g.corp"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.site2.corp) - vm.site2.corp"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.us.hub.g.corp) - vm.us.hub.g.corp"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.us.spoke2.g.corp) - vm.us.spoke2.g.corp"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb4.us.hub.g.corp) - ilb4.us.hub.g.corp"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb7.us.hub.g.corp) - ilb7.us.hub.g.corp"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb4.us.spoke2.g.corp) - ilb4.us.spoke2.g.corp"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb7.us.spoke2.g.corp) - ilb7.us.spoke2.g.corp"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb4.geo.hub.g.corp) - ilb4.geo.hub.g.corp"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null icanhazip.com) - icanhazip.com"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null www.googleapis.com) - www.googleapis.com"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null storage.googleapis.com) - storage.googleapis.com"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null europe-west2-run.googleapis.com) - europe-west2-run.googleapis.com"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null us-west2-run.googleapis.com) - us-west2-run.googleapis.com"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null https://c-hub-us-run-httpbin-wapotrwjpq-nw.a.run.app) - https://c-hub-us-run-httpbin-wapotrwjpq-nw.a.run.app"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null https://c-spoke1-eu-run-httpbin-expmorqqnq-nw.a.run.app) - https://c-spoke1-eu-run-httpbin-expmorqqnq-nw.a.run.app"
echo  "$(timeout 5 curl -4 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null https://c-spoke2-us-run-httpbin-4e4skt6nna-wl.a.run.app) - https://c-spoke2-us-run-httpbin-4e4skt6nna-wl.a.run.app"
EOF
chmod a+x /usr/local/bin/curl-dns4

# trace-ipv4

cat <<'EOF' > /usr/local/bin/trace-ipv4
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
echo -e "\nspoke2-eu-vm  "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.22.11.9
echo -e "\nhub-eu-ilb4   "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.1.11.70
echo -e "\nhub-eu-ilb7   "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.1.11.80
echo -e "\nspoke1-eu-ilb4"
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.11.11.30
echo -e "\nspoke1-eu-ilb7"
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.11.11.40
echo -e "\nsite2-vm      "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.20.1.9
echo -e "\nhub-us-vm     "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.1.21.9
echo -e "\nspoke2-us-vm  "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.22.21.9
echo -e "\nhub-us-ilb4   "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.1.21.70
echo -e "\nhub-us-ilb7   "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.1.21.80
echo -e "\nspoke2-us-ilb4"
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.22.21.30
echo -e "\nspoke2-us-ilb7"
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.22.21.40
echo -e "\ninternet"
echo -e "-------------------------------------"
timeout 9 tracepath -4 icanhazip.com
EOF
chmod a+x /usr/local/bin/trace-ipv4

# ptr-ipv4

cat <<'EOF' > /usr/local/bin/ptr-ipv4
echo -e "\n PTR ipv4 ...\n"
arpa_zone=$(dig -x 10.11.11.30 | grep "QUESTION SECTION" -A 1 | tail -n 1 | awk '{print $1}')
ptr_record=$(timeout 5 dig -x 10.11.11.30 +short)
echo "spoke1-eu-ilb4 - 10.11.11.30 --> $ptr_record [$arpa_zone]"
arpa_zone=$(dig -x 10.11.11.40 | grep "QUESTION SECTION" -A 1 | tail -n 1 | awk '{print $1}')
ptr_record=$(timeout 5 dig -x 10.11.11.40 +short)
echo "spoke1-eu-ilb7 - 10.11.11.40 --> $ptr_record [$arpa_zone]"
arpa_zone=$(dig -x 10.22.21.30 | grep "QUESTION SECTION" -A 1 | tail -n 1 | awk '{print $1}')
ptr_record=$(timeout 5 dig -x 10.22.21.30 +short)
echo "spoke2-us-ilb4 - 10.22.21.30 --> $ptr_record [$arpa_zone]"
arpa_zone=$(dig -x 10.22.21.40 | grep "QUESTION SECTION" -A 1 | tail -n 1 | awk '{print $1}')
ptr_record=$(timeout 5 dig -x 10.22.21.40 +short)
echo "spoke2-us-ilb7 - 10.22.21.40 --> $ptr_record [$arpa_zone]"
EOF
chmod a+x /usr/local/bin/ptr-ipv4

########################################################
# test scripts (ipv6)
########################################################

# ping-ipv6

cat <<'EOF' > /usr/local/bin/ping-ipv6
echo -e "\n ping ipv6 ...\n"
echo "site1-vm       - fd00:10:10:1::9 -$(timeout 5 ping -6 -qc2 -W1 fd00:10:10:1::9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "hub-eu-vm      - fd00:10:1:11::9 -$(timeout 5 ping -6 -qc2 -W1 fd00:10:1:11::9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke1-eu-vm   - fd00:10:11:11::9 -$(timeout 5 ping -6 -qc2 -W1 fd00:10:11:11::9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke2-eu-vm   - fd00:10:22:11::9 -$(timeout 5 ping -6 -qc2 -W1 fd00:10:22:11::9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "hub-eu-ilb4    - fd00:10:1:11::46 -$(timeout 5 ping -6 -qc2 -W1 fd00:10:1:11::46 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "hub-eu-ilb7    - fd00:10:1:11::50 -$(timeout 5 ping -6 -qc2 -W1 fd00:10:1:11::50 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke1-eu-ilb4 - fd00:10:11:11::1e -$(timeout 5 ping -6 -qc2 -W1 fd00:10:11:11::1e 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke1-eu-ilb7 - fd00:10:11:11::28 -$(timeout 5 ping -6 -qc2 -W1 fd00:10:11:11::28 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "site2-vm       - fd00:10:20:1::9 -$(timeout 5 ping -6 -qc2 -W1 fd00:10:20:1::9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "hub-us-vm      - fd00:10:1:21::9 -$(timeout 5 ping -6 -qc2 -W1 fd00:10:1:21::9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke2-us-vm   - fd00:10:22:21::9 -$(timeout 5 ping -6 -qc2 -W1 fd00:10:22:21::9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "hub-us-ilb4    - fd00:10:1:21::46 -$(timeout 5 ping -6 -qc2 -W1 fd00:10:1:21::46 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "hub-us-ilb7    - fd00:10:1:21::50 -$(timeout 5 ping -6 -qc2 -W1 fd00:10:1:21::50 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke2-us-ilb4 - fd00:10:22:21::1e -$(timeout 5 ping -6 -qc2 -W1 fd00:10:22:21::1e 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke2-us-ilb7 - fd00:10:22:21::28 -$(timeout 5 ping -6 -qc2 -W1 fd00:10:22:21::28 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "internet - icanhazip.com -$(timeout 5 ping -6 -qc2 -W1 icanhazip.com 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
EOF
chmod a+x /usr/local/bin/ping-ipv6

# ping-dns6

cat <<'EOF' > /usr/local/bin/ping-dns6
echo -e "\n ping dns ipv6 ...\n"
echo "vm.site1.corp - $(timeout 5 dig AAAA +short vm.site1.corp | tail -n1) -$(timeout 5 ping -6 -qc2 -W1 vm.site1.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.eu.hub.g.corp - $(timeout 5 dig AAAA +short vm.eu.hub.g.corp | tail -n1) -$(timeout 5 ping -6 -qc2 -W1 vm.eu.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.eu.spoke1.g.corp - $(timeout 5 dig AAAA +short vm.eu.spoke1.g.corp | tail -n1) -$(timeout 5 ping -6 -qc2 -W1 vm.eu.spoke1.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.eu.spoke2.g.corp - $(timeout 5 dig AAAA +short vm.eu.spoke2.g.corp | tail -n1) -$(timeout 5 ping -6 -qc2 -W1 vm.eu.spoke2.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "ilb4.eu.hub.g.corp - $(timeout 5 dig AAAA +short ilb4.eu.hub.g.corp | tail -n1) -$(timeout 5 ping -6 -qc2 -W1 ilb4.eu.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "ilb7.eu.hub.g.corp - $(timeout 5 dig AAAA +short ilb7.eu.hub.g.corp | tail -n1) -$(timeout 5 ping -6 -qc2 -W1 ilb7.eu.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "ilb4.eu.spoke1.g.corp - $(timeout 5 dig AAAA +short ilb4.eu.spoke1.g.corp | tail -n1) -$(timeout 5 ping -6 -qc2 -W1 ilb4.eu.spoke1.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "ilb7.eu.spoke1.g.corp - $(timeout 5 dig AAAA +short ilb7.eu.spoke1.g.corp | tail -n1) -$(timeout 5 ping -6 -qc2 -W1 ilb7.eu.spoke1.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.site2.corp - $(timeout 5 dig AAAA +short vm.site2.corp | tail -n1) -$(timeout 5 ping -6 -qc2 -W1 vm.site2.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.us.hub.g.corp - $(timeout 5 dig AAAA +short vm.us.hub.g.corp | tail -n1) -$(timeout 5 ping -6 -qc2 -W1 vm.us.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.us.spoke2.g.corp - $(timeout 5 dig AAAA +short vm.us.spoke2.g.corp | tail -n1) -$(timeout 5 ping -6 -qc2 -W1 vm.us.spoke2.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "ilb4.us.hub.g.corp - $(timeout 5 dig AAAA +short ilb4.us.hub.g.corp | tail -n1) -$(timeout 5 ping -6 -qc2 -W1 ilb4.us.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "ilb7.us.hub.g.corp - $(timeout 5 dig AAAA +short ilb7.us.hub.g.corp | tail -n1) -$(timeout 5 ping -6 -qc2 -W1 ilb7.us.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "ilb4.us.spoke2.g.corp - $(timeout 5 dig AAAA +short ilb4.us.spoke2.g.corp | tail -n1) -$(timeout 5 ping -6 -qc2 -W1 ilb4.us.spoke2.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "ilb7.us.spoke2.g.corp - $(timeout 5 dig AAAA +short ilb7.us.spoke2.g.corp | tail -n1) -$(timeout 5 ping -6 -qc2 -W1 ilb7.us.spoke2.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "icanhazip.com - $(timeout 5 dig AAAA +short icanhazip.com | tail -n1) -$(timeout 5 ping -6 -qc2 -W1 icanhazip.com 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
EOF
chmod a+x /usr/local/bin/ping-dns6

# curl-ipv6

cat <<'EOF' > /usr/local/bin/curl-ipv6
echo -e "\n curl ipv6 ...\n"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null [fd00:10:10:1::9]) - site1-vm       [fd00:10:10:1::9]"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null [fd00:10:1:11::9]) - hub-eu-vm      [fd00:10:1:11::9]"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null [fd00:10:11:11::9]) - spoke1-eu-vm   [fd00:10:11:11::9]"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null [fd00:10:22:11::9]) - spoke2-eu-vm   [fd00:10:22:11::9]"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null [fd00:10:1:11::46]) - hub-eu-ilb4    [fd00:10:1:11::46]"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null [fd00:10:1:11::50]) - hub-eu-ilb7    [fd00:10:1:11::50]"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null [fd00:10:11:11::1e]) - spoke1-eu-ilb4 [fd00:10:11:11::1e]"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null [fd00:10:11:11::28]) - spoke1-eu-ilb7 [fd00:10:11:11::28]"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null [fd00:10:20:1::9]) - site2-vm       [fd00:10:20:1::9]"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null [fd00:10:1:21::9]) - hub-us-vm      [fd00:10:1:21::9]"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null [fd00:10:22:21::9]) - spoke2-us-vm   [fd00:10:22:21::9]"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null [fd00:10:1:21::46]) - hub-us-ilb4    [fd00:10:1:21::46]"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null [fd00:10:1:21::50]) - hub-us-ilb7    [fd00:10:1:21::50]"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null [fd00:10:22:21::1e]) - spoke2-us-ilb4 [fd00:10:22:21::1e]"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null [fd00:10:22:21::28]) - spoke2-us-ilb7 [fd00:10:22:21::28]"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null [icanhazip.com]) - internet [icanhazip.com]"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null [www.googleapis.com]) - www [www.googleapis.com]"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null [storage.googleapis.com]) - storage [storage.googleapis.com]"
EOF
chmod a+x /usr/local/bin/curl-ipv6

# curl-dns6

cat <<'EOF' > /usr/local/bin/curl-dns6
echo -e "\n curl dns ipv6 ...\n"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.site1.corp) - vm.site1.corp"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.eu.hub.g.corp) - vm.eu.hub.g.corp"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.eu.spoke1.g.corp) - vm.eu.spoke1.g.corp"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.eu.spoke2.g.corp) - vm.eu.spoke2.g.corp"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb4.eu.hub.g.corp) - ilb4.eu.hub.g.corp"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb7.eu.hub.g.corp) - ilb7.eu.hub.g.corp"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb4.eu.spoke1.g.corp) - ilb4.eu.spoke1.g.corp"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb7.eu.spoke1.g.corp) - ilb7.eu.spoke1.g.corp"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.site2.corp) - vm.site2.corp"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.us.hub.g.corp) - vm.us.hub.g.corp"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.us.spoke2.g.corp) - vm.us.spoke2.g.corp"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb4.us.hub.g.corp) - ilb4.us.hub.g.corp"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb7.us.hub.g.corp) - ilb7.us.hub.g.corp"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb4.us.spoke2.g.corp) - ilb4.us.spoke2.g.corp"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb7.us.spoke2.g.corp) - ilb7.us.spoke2.g.corp"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb4.geo.hub.g.corp) - ilb4.geo.hub.g.corp"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null icanhazip.com) - icanhazip.com"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null www.googleapis.com) - www.googleapis.com"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null storage.googleapis.com) - storage.googleapis.com"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null europe-west2-run.googleapis.com) - europe-west2-run.googleapis.com"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null us-west2-run.googleapis.com) - us-west2-run.googleapis.com"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null https://c-hub-us-run-httpbin-wapotrwjpq-nw.a.run.app) - https://c-hub-us-run-httpbin-wapotrwjpq-nw.a.run.app"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null https://c-spoke1-eu-run-httpbin-expmorqqnq-nw.a.run.app) - https://c-spoke1-eu-run-httpbin-expmorqqnq-nw.a.run.app"
echo  "$(timeout 5 curl -6 -kL --max-time 5.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null https://c-spoke2-us-run-httpbin-4e4skt6nna-wl.a.run.app) - https://c-spoke2-us-run-httpbin-4e4skt6nna-wl.a.run.app"
EOF
chmod a+x /usr/local/bin/curl-dns6

# trace-ipv6

cat <<'EOF' > /usr/local/bin/trace-ipv6
echo -e "\n trace ipv6 ...\n"
echo -e "\nsite1-vm      "
echo -e "-------------------------------------"
timeout 9 tracepath -6 fd00:10:10:1::9
echo -e "\nhub-eu-vm     "
echo -e "-------------------------------------"
timeout 9 tracepath -6 fd00:10:1:11::9
echo -e "\nspoke1-eu-vm  "
echo -e "-------------------------------------"
timeout 9 tracepath -6 fd00:10:11:11::9
echo -e "\nspoke2-eu-vm  "
echo -e "-------------------------------------"
timeout 9 tracepath -6 fd00:10:22:11::9
echo -e "\nhub-eu-ilb4   "
echo -e "-------------------------------------"
timeout 9 tracepath -6 fd00:10:1:11::46
echo -e "\nhub-eu-ilb7   "
echo -e "-------------------------------------"
timeout 9 tracepath -6 fd00:10:1:11::50
echo -e "\nspoke1-eu-ilb4"
echo -e "-------------------------------------"
timeout 9 tracepath -6 fd00:10:11:11::1e
echo -e "\nspoke1-eu-ilb7"
echo -e "-------------------------------------"
timeout 9 tracepath -6 fd00:10:11:11::28
echo -e "\nsite2-vm      "
echo -e "-------------------------------------"
timeout 9 tracepath -6 fd00:10:20:1::9
echo -e "\nhub-us-vm     "
echo -e "-------------------------------------"
timeout 9 tracepath -6 fd00:10:1:21::9
echo -e "\nspoke2-us-vm  "
echo -e "-------------------------------------"
timeout 9 tracepath -6 fd00:10:22:21::9
echo -e "\nhub-us-ilb4   "
echo -e "-------------------------------------"
timeout 9 tracepath -6 fd00:10:1:21::46
echo -e "\nhub-us-ilb7   "
echo -e "-------------------------------------"
timeout 9 tracepath -6 fd00:10:1:21::50
echo -e "\nspoke2-us-ilb4"
echo -e "-------------------------------------"
timeout 9 tracepath -6 fd00:10:22:21::1e
echo -e "\nspoke2-us-ilb7"
echo -e "-------------------------------------"
timeout 9 tracepath -6 fd00:10:22:21::28
echo -e "\ninternet"
echo -e "-------------------------------------"
timeout 9 tracepath -6 icanhazip.com
EOF
chmod a+x /usr/local/bin/trace-ipv6

#########################################################
# other scripts
#########################################################

# dns-info

cat <<'EOF' > /usr/local/bin/dns-info
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

cat <<'EOF' > /etc/cron.d/traffic-gen
EOF

crontab /etc/cron.d/traffic-gen
