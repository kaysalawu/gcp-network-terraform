#! /bin/bash

export CLOUD_ENV=gcp
exec > /var/log/$CLOUD_ENV-startup.log 2>&1
export DEBIAN_FRONTEND=noninteractive

apt update
apt install -y python3-pip python3-dev python3-venv unzip jq tcpdump dnsutils net-tools nmap apache2-utils iperf3
apt install -y python3-flask python3-requests

# cloud-init install for docker did not work so installing manually here
apt install -y ca-certificates curl gnupg lsb-release
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
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
echo -e "\n=============================="
echo -e " ping ipv4 ..."
echo "=============================="
EOF
chmod a+x /usr/local/bin/ping-ipv4

# ping-dns4

cat <<'EOF' >/usr/local/bin/ping-dns4
echo -e "\n=============================="
echo -e " ping dns ipv4 ..."
echo "=============================="
EOF
chmod a+x /usr/local/bin/ping-dns4

# curl-ipv4

cat <<'EOF' >/usr/local/bin/curl-ipv4
echo -e "\n=============================="
echo -e " curl ipv4 ..."
echo "=============================="
EOF
chmod a+x /usr/local/bin/curl-ipv4

# curl-dns4

cat <<'EOF' >/usr/local/bin/curl-dns4
echo -e "\n=============================="
echo -e " curl dns ipv4 ..."
echo "=============================="
EOF
chmod a+x /usr/local/bin/curl-dns4

# trace-ipv4

cat <<'EOF' >/usr/local/bin/trace-ipv4
echo -e "\n=============================="
echo -e " trace ipv4 ..."
echo "=============================="
EOF
chmod a+x /usr/local/bin/trace-ipv4

# ptr-ipv4

cat <<'EOF' >/usr/local/bin/ptr-ipv4
echo -e "\n=============================="
echo -e " PTR ipv4 ..."
echo "=============================="
EOF
chmod a+x /usr/local/bin/ptr-ipv4

########################################################
# test scripts (ipv6)
########################################################

# ping-ipv6

cat <<'EOF' > /usr/local/bin/ping-ipv6
echo -e "\n ping ipv6 ...\n"
EOF
chmod a+x /usr/local/bin/ping-ipv6

# ping-dns6

cat <<'EOF' >/usr/local/bin/ping-dns6
echo -e "\n=============================="
echo -e " ping dns ipv6 ..."
echo "=============================="
EOF
chmod a+x /usr/local/bin/ping-dns6

# curl-ipv6

cat <<'EOF' > /usr/local/bin/curl-ipv6
echo -e "\n curl ipv6 ...\n"
EOF
chmod a+x /usr/local/bin/curl-ipv6

# curl-dns6

cat <<'EOF' >/usr/local/bin/curl-dns6
echo -e "\n=============================="
echo -e " curl dns ipv6 ..."
echo "=============================="
EOF
chmod a+x /usr/local/bin/curl-dns6

# trace-dns6

cat <<'EOF' >/usr/local/bin/trace-dns6
echo -e "\n=============================="
echo -e " trace ipv6 ..."
echo "=============================="
EOF
chmod a+x /usr/local/bin/trace-dns6

#########################################################
# other scripts
#########################################################

# dns-info

cat <<'EOF' >/usr/local/bin/dns-info
echo -e "\n=============================="
echo -e " resolvectl ..."
echo "=============================="
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
# systemctl services
########################################################

cat <<EOF > /etc/systemd/system/flaskapp.service
[Unit]
Description=Manage Docker Compose services for FastAPI
After=docker.service
Requires=docker.service

[Service]
Type=simple
Environment="HOSTNAME=$(hostname)"
ExecStart=/usr/bin/docker compose -f /var/lib/$CLOUD_ENV/fastapi/docker-compose-http-80.yml up -d && \
          /usr/bin/docker compose -f /var/lib/$CLOUD_ENV/fastapi/docker-compose-http-8080.yml up -d
ExecStop=/usr/bin/docker compose -f /var/lib/$CLOUD_ENV/fastapi/docker-compose-http-80.yml down && \
         /usr/bin/docker compose -f /var/lib/$CLOUD_ENV/fastapi/docker-compose-http-8080.yml down
Restart=always
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable flaskapp.service
systemctl restart flaskapp.service

########################################################
# crontabs
########################################################

cat <<'EOF' >/etc/cron.d/traffic-gen
EOF

crontab /etc/cron.d/traffic-gen
