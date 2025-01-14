#! /bin/bash

export CLOUD_ENV=gcp
exec >/var/log/$CLOUD_ENV-startup.log 2>&1
export DEBIAN_FRONTEND=noninteractive

apt update
apt install -y python3-pip python3-dev python3-venv
apt install -y unzip jq tcpdump dnsutils net-tools nmap apache2-utils iperf3

# Create application directory accessible to all users
mkdir -p /var/lib/$CLOUD_ENV/neo4j
chmod 755 /var/lib/$CLOUD_ENV/neo4j
cd /var/lib/$CLOUD_ENV/neo4j

# Create virtual environment and install dependencies
python3 -m venv env
source env/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
deactivate

# dns-info script
cat <<'EOF' >/usr/local/bin/dns-info
echo -e "\n resolvectl ...\n"
resolvectl status
EOF
chmod a+x /usr/local/bin/dns-info

# systemctl services
cat <<EOF >/etc/systemd/system/neo4j-client.service
[Unit]
Description=Run Neo4j client
After=network.target

[Service]
Type=simple
User=nobody
WorkingDirectory=/var/lib/$CLOUD_ENV/neo4j
Environment="HOSTNAME=$(hostname)"
ExecStart=/var/lib/$CLOUD_ENV/neo4j/env/bin/python3 /var/lib/$CLOUD_ENV/neo4j/client.py
ExecStop=/bin/kill -TERM $MAINPID
Restart=always
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable neo4j-client.service
systemctl restart neo4j-client.service
