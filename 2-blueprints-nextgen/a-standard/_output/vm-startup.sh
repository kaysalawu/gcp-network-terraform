#! /bin/bash

apt update -y
apt install -y wget tcpdump fping bind9-dnsutils apache2-utils python3-pip python3-dev
apt install -y python3-flask python3-requests

# web server
#---------------------------------------------------

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
    data_dict['name'] = hostname
    data_dict['address'] = address
    data_dict['remote'] = request.remote_addr
    data_dict['headers'] = dict(request.headers)
    return data_dict

@app.route('/healthz')
def healthz():
    return 'pass'

if __name__ == "__main__":
    app.run(host= '0.0.0.0', port=8080, debug = True)
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

# playz (curl scripts)
#---------------------------------------------------

cat <<'EOF' > /usr/local/bin/playz
echo -e "\n apps ...\n"
echo  "$(curl -kL --max-time 2.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.site1.onprem:8080/) - vm.site1.onprem:8080/"
echo  "$(curl -kL --max-time 2.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.site2.onprem:8080/) - vm.site2.onprem:8080/"
echo  "$(curl -kL --max-time 2.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb4.eu.hub.gcp:8080/) - ilb4.eu.hub.gcp:8080/"
echo  "$(curl -kL --max-time 2.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb4.us.hub.gcp:8080/) - ilb4.us.hub.gcp:8080/"
echo  "$(curl -kL --max-time 2.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb7.eu.hub.gcp/) - ilb7.eu.hub.gcp/"
echo  "$(curl -kL --max-time 2.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb7.us.hub.gcp/) - ilb7.us.hub.gcp/"
echo -e "\n psc4 ...\n"
echo -e "\n apis ...\n"
echo  "$(curl -kL --max-time 2.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null www.googleapis.com/generate_204) - www.googleapis.com/generate_204"
echo  "$(curl -kL --max-time 2.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null storage.googleapis.com/generate_204) - storage.googleapis.com/generate_204"
echo  "$(curl -kL --max-time 2.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null europe-west2-run.googleapis.com/generate_204) - europe-west2-run.googleapis.com/generate_204"
echo  "$(curl -kL --max-time 2.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null us-west2-run.googleapis.com/generate_204) - us-west2-run.googleapis.com/generate_204"
echo  "$(curl -kL --max-time 2.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null https://f-hub-us-run-httpbin-i6ankopyoa-nw.a.run.app/) - https://f-hub-us-run-httpbin-i6ankopyoa-nw.a.run.app/"
echo  "$(curl -kL --max-time 2.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null fhuball.p.googleapis.com/generate_204) - fhuball.p.googleapis.com/generate_204"
echo ""
EOF
chmod a+x /usr/local/bin/playz

# pingz
#-----------------------------------
cat <<'EOF' > /usr/local/bin/pingz
echo -e "\n ping ...\n"
echo vm.site1.onprem - $(ping -qc2 -W1 vm.site1.onprem 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')
echo vm.site2.onprem - $(ping -qc2 -W1 vm.site2.onprem 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')
echo ilb4.eu.hub.gcp - $(ping -qc2 -W1 ilb4.eu.hub.gcp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')
echo ilb4.us.hub.gcp - $(ping -qc2 -W1 ilb4.us.hub.gcp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')
echo ilb7.eu.hub.gcp - $(ping -qc2 -W1 ilb7.eu.hub.gcp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')
echo ilb7.us.hub.gcp - $(ping -qc2 -W1 ilb7.us.hub.gcp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')
EOF
chmod a+x /usr/local/bin/pingz

# bucketz (gcs bucket test script)
#---------------------------------------------------

cat <<'EOF' > /usr/local/bin/bucketz
echo ""
echo -e "hub : $(gsutil cat gs://f-hub-eu-storage-bucket)\n"
EOF
chmod a+x /usr/local/bin/bucketz

# aiz (connect to aiplatform)
#---------------------------------------------------

cat <<EOF > /usr/local/bin/aiz
echo ""
echo -e " prj-hub-x...\n"
gcloud ai models list --project=prj-hub-x --region=europe-west2
EOF
chmod a+x /usr/local/bin/aiz

# api discovery script
#---------------------------------------------------

cat <<EOF > /usr/local/bin/discoverz.py
#!/usr/bin/env python3

import os
import json
import requests
import urllib.request
from socket import timeout

response = urllib.request.urlopen("https://www.googleapis.com/discovery/v1/apis")
content = response.read()
data = json.loads(content.decode("utf8"))
googleapis = data['items']
reachable = []
unreachable = []
print("\n scanning all api endpoints ...\n")
for api in googleapis:
    name = api['name']
    version = api['version']
    title = api['title']
    url = 'https://' + name + '.googleapis.com/generate_204'
    try:
        r = requests.get(url, timeout=1)
        if r.status_code == 204:
            reachable.append([r.status_code, name, url])
            print("{} - {:<26s} {:<10s} {}".format(r.status_code, name, version, url))
        else:
            unreachable.append([r.status_code, name, url])
            print("{} - {:<26s} {:<10s} {}".format(r.status_code, name, version, url))
    except Exception as e:
        print("{} - {:<26s} {:<10s} {}".format(r.status_code, name, version, url))
        unreachable.append(['err', name, url])
print("\n reachable api endpoints ...\n")
for code, name, url in sorted(reachable):
    print("{} - {:<26s} {:<10s} {}".format(code, name, version, url))
print("\n unreachable api endpoints ...\n")
for code, name, url in sorted(unreachable):
    print("{} - {:<26s} {:<10s} {}".format(code, name, version, url))
EOF

# probe
#---------------------------------------------------

cat <<'EOF' > /usr/local/bin/probez
#! /bin/bash
i=0
while [ $i -lt 3 ]; do
    ab -n $1 -c $2 vm.site1.onprem:8080/ > /dev/null 2>&1
    ab -n $1 -c $2 vm.site2.onprem:8080/ > /dev/null 2>&1
    ab -n $1 -c $2 ilb4.eu.hub.gcp:8080/ > /dev/null 2>&1
    ab -n $1 -c $2 ilb4.us.hub.gcp:8080/ > /dev/null 2>&1
    ab -n $1 -c $2 ilb7.eu.hub.gcp/ > /dev/null 2>&1
    ab -n $1 -c $2 ilb7.us.hub.gcp/ > /dev/null 2>&1
    ab -n $1 -c $2 www.googleapis.com/generate_204 > /dev/null 2>&1
    ab -n $1 -c $2 storage.googleapis.com/generate_204 > /dev/null 2>&1
    ab -n $1 -c $2 europe-west2-run.googleapis.com/generate_204 > /dev/null 2>&1
    ab -n $1 -c $2 us-west2-run.googleapis.com/generate_204 > /dev/null 2>&1
    ab -n $1 -c $2 https://f-hub-us-run-httpbin-i6ankopyoa-nw.a.run.app/ > /dev/null 2>&1
    ab -n $1 -c $2 fhuball.p.googleapis.com/generate_204 > /dev/null 2>&1
    let i=i+1
  sleep 3
done
EOF
chmod a+x /usr/local/bin/probez

cat <<EOF > /tmp/crontab.txt
*/1 * * * * /usr/local/bin/probez 15 1 2>&1 > /dev/null
*/2 * * * * /usr/local/bin/probez 6 2 2>&1 > /dev/null
*/5 * * * * /usr/local/bin/probez 5 1 2>&1 > /dev/null
EOF
crontab /tmp/crontab.txt
