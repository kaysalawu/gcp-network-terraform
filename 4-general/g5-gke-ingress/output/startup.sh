#! /bin/bash

export CLOUD_ENV=gcp
exec > /var/log/$CLOUD_ENV-startup.log 2>&1
export DEBIAN_FRONTEND=noninteractive

apt update
apt install -y unzip jq tcpdump dnsutils net-tools nmap apache2-utils iperf3

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

# test scripts (ipv4)
#---------------------------

# ping-ipv4
cat <<'EOF' >/usr/local/bin/ping-ipv4
echo -e "\n ping ipv4 ...\n"
EOF
chmod a+x /usr/local/bin/ping-ipv4

# ping-dns4
cat <<'EOF' >/usr/local/bin/ping-dns4
echo -e "\n ping dns ipv4 ...\n"
EOF
chmod a+x /usr/local/bin/ping-dns4

# curl-ipv4
cat <<'EOF' >/usr/local/bin/curl-ipv4
echo -e "\n curl ipv4 ...\n"
EOF
chmod a+x /usr/local/bin/curl-ipv4

# curl-dns4
cat <<'EOF' >/usr/local/bin/curl-dns4
echo -e "\n curl dns ipv4 ...\n"
EOF
chmod a+x /usr/local/bin/curl-dns4

# trace-ipv4
cat <<'EOF' >/usr/local/bin/trace-ipv4
echo -e "\n trace ipv4 ...\n"
EOF
chmod a+x /usr/local/bin/trace-ipv4

# ptr-ipv4
cat <<'EOF' >/usr/local/bin/ptr-ipv4
echo -e "\n PTR ipv4 ...\n"
EOF
chmod a+x /usr/local/bin/ptr-ipv4

# test scripts (ipv6)
#---------------------------

# ping-dns6
cat <<'EOF' >/usr/local/bin/ping-dns6
echo -e\n " ping dns ipv6 ...\n"
EOF
chmod a+x /usr/local/bin/ping-dns6

# curl-dns6
cat <<'EOF' >/usr/local/bin/curl-dns6
echo -e "\n curl dns ipv6 ...\n"
EOF
chmod a+x /usr/local/bin/curl-dns6

# trace-dns6
cat <<'EOF' >/usr/local/bin/trace-dns6
echo -e "\n trace ipv6 ...\n"
EOF
chmod a+x /usr/local/bin/trace-dns6

# other scripts
#---------------------------

# dns-info
cat <<'EOF' >/usr/local/bin/dns-info
echo -e "\n resolvectl ...\n"
resolvectl status
EOF
chmod a+x /usr/local/bin/dns-info

# traffic generators (ipv4)
#---------------------------

# light-traffic generator

# heavy-traffic generator

# traffic generators (ipv6)
#---------------------------

# light-traffic generator

# systemctl services
#---------------------------

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

# crontabs
#---------------------------

cat <<'EOF' >/etc/cron.d/traffic-gen
EOF

crontab /etc/cron.d/traffic-gen
