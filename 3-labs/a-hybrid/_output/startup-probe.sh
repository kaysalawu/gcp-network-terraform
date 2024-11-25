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
echo "site1-vm      - 10.10.1.9 -$(timeout 3 ping -4 -qc2 -W1 10.10.1.9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "hub-eu-vm     - 10.1.11.9 -$(timeout 3 ping -4 -qc2 -W1 10.1.11.9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "site2-vm      - 10.20.1.9 -$(timeout 3 ping -4 -qc2 -W1 10.20.1.9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "hub-us-vm     - 10.1.21.9 -$(timeout 3 ping -4 -qc2 -W1 10.1.21.9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
EOF
chmod a+x /usr/local/bin/ping-ipv4

# ping-dns4
cat <<'EOF' >/usr/local/bin/ping-dns4
echo -e "\n ping dns ipv4 ...\n"
echo "vm.site1.corp - $(timeout 3 dig +short vm.site1.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 vm.site1.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.eu.hub.g.corp - $(timeout 3 dig +short vm.eu.hub.g.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 vm.eu.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.site2.corp - $(timeout 3 dig +short vm.site2.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 vm.site2.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.us.hub.g.corp - $(timeout 3 dig +short vm.us.hub.g.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 vm.us.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
EOF
chmod a+x /usr/local/bin/ping-dns4

# curl-ipv4
cat <<'EOF' >/usr/local/bin/curl-ipv4
echo -e "\n curl ipv4 ...\n"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.10.1.9) - site1-vm      [10.10.1.9]"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.1.11.9) - hub-eu-vm     [10.1.11.9]"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.1.11.70) - hub-eu-ilb    [10.1.11.70]"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.1.11.80) - hub-eu-nlb    [10.1.11.80]"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.1.11.90) - hub-eu-alb    [10.1.11.90]"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.20.1.9) - site2-vm      [10.20.1.9]"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.1.21.9) - hub-us-vm     [10.1.21.9]"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.1.21.70) - hub-us-ilb    [10.1.21.70]"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.1.21.90) - hub-us-nlb    [10.1.21.90]"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.1.21.80) - hub-us-alb    [10.1.21.80]"
EOF
chmod a+x /usr/local/bin/curl-ipv4

# curl-dns4
cat <<'EOF' >/usr/local/bin/curl-dns4
echo -e "\n curl dns ipv4 ...\n"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.site1.corp) - vm.site1.corp"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.eu.hub.g.corp) - vm.eu.hub.g.corp"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb.eu.hub.g.corp) - ilb.eu.hub.g.corp"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null nlb.eu.hub.g.corp) - nlb.eu.hub.g.corp"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null alb.eu.hub.g.corp) - alb.eu.hub.g.corp"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.site2.corp) - vm.site2.corp"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.us.hub.g.corp) - vm.us.hub.g.corp"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb.us.hub.g.corp) - ilb.us.hub.g.corp"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null nlb.us.hub.g.corp) - nlb.us.hub.g.corp"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null alb.us.hub.g.corp) - alb.us.hub.g.corp"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb.geo.hub.g.corp) - ilb.geo.hub.g.corp"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null icanhazip.com) - icanhazip.com"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null www.googleapis.com) - www.googleapis.com"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null storage.googleapis.com) - storage.googleapis.com"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null europe-west2-run.googleapis.com) - europe-west2-run.googleapis.com"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null us-west2-run.googleapis.com) - us-west2-run.googleapis.com"
echo  "$(timeout 3 curl -4 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null https://a-hub-us-run-httpbin-wapotrwjpq-nw.a.run.app) - https://a-hub-us-run-httpbin-wapotrwjpq-nw.a.run.app"
EOF
chmod a+x /usr/local/bin/curl-dns4

# trace-ipv4
cat <<'EOF' >/usr/local/bin/trace-ipv4
echo -e "\n trace ipv4 ...\n"
echo -e "\nsite1-vm     "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.10.1.9
echo -e "\nhub-eu-vm    "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.1.11.9
echo -e "\nsite2-vm     "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.20.1.9
echo -e "\nhub-us-vm    "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.1.21.9
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
echo "vm.site1.corp - $(timeout 3 dig AAAA +short vm.site1.corp | tail -n1) -$(timeout 3 ping -6 -qc2 -W1 vm.site1.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.eu.hub.g.corp - $(timeout 3 dig AAAA +short vm.eu.hub.g.corp | tail -n1) -$(timeout 3 ping -6 -qc2 -W1 vm.eu.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.site2.corp - $(timeout 3 dig AAAA +short vm.site2.corp | tail -n1) -$(timeout 3 ping -6 -qc2 -W1 vm.site2.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.us.hub.g.corp - $(timeout 3 dig AAAA +short vm.us.hub.g.corp | tail -n1) -$(timeout 3 ping -6 -qc2 -W1 vm.us.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
EOF
chmod a+x /usr/local/bin/ping-dns6

# curl-dns6
cat <<'EOF' >/usr/local/bin/curl-dns6
echo -e "\n curl dns ipv6 ...\n"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.site1.corp) - vm.site1.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.eu.hub.g.corp) - vm.eu.hub.g.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb.eu.hub.g.corp) - ilb.eu.hub.g.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null nlb.eu.hub.g.corp) - nlb.eu.hub.g.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null alb.eu.hub.g.corp) - alb.eu.hub.g.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.site2.corp) - vm.site2.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.us.hub.g.corp) - vm.us.hub.g.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb.us.hub.g.corp) - ilb.us.hub.g.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null nlb.us.hub.g.corp) - nlb.us.hub.g.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null alb.us.hub.g.corp) - alb.us.hub.g.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb.geo.hub.g.corp) - ilb.geo.hub.g.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null icanhazip.com) - icanhazip.com"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null www.googleapis.com) - www.googleapis.com"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null storage.googleapis.com) - storage.googleapis.com"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null europe-west2-run.googleapis.com) - europe-west2-run.googleapis.com"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null us-west2-run.googleapis.com) - us-west2-run.googleapis.com"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null https://a-hub-us-run-httpbin-wapotrwjpq-nw.a.run.app) - https://a-hub-us-run-httpbin-wapotrwjpq-nw.a.run.app"
EOF
chmod a+x /usr/local/bin/curl-dns6

# trace-dns6
cat <<'EOF' >/usr/local/bin/trace-dns6
echo -e "\n trace ipv6 ...\n"
echo -e "\nsite1-vm     "
echo -e "-------------------------------------"
timeout 9 tracepath -6 vm.site1.corp
echo -e "\nhub-eu-vm    "
echo -e "-------------------------------------"
timeout 9 tracepath -6 vm.eu.hub.g.corp
echo -e "\nsite2-vm     "
echo -e "-------------------------------------"
timeout 9 tracepath -6 vm.site2.corp
echo -e "\nhub-us-vm    "
echo -e "-------------------------------------"
timeout 9 tracepath -6 vm.us.hub.g.corp
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
cat <<'EOF' >/usr/local/bin/light-traffic
nping -c 5 --tcp-connect -p 80,8080 vm.site1.corp > /dev/null 2>&1
nping -c 5 --tcp-connect -p 80,8080 vm.eu.hub.g.corp > /dev/null 2>&1
nping -c 5 --tcp-connect -p 80,8080 vm.site2.corp > /dev/null 2>&1
nping -c 5 --tcp-connect -p 80,8080 vm.us.hub.g.corp > /dev/null 2>&1
nping -c 5 --tcp-connect -p 80,8080 icanhazip.com > /dev/null 2>&1
nping -c 5 --tcp-connect -p 80,8080 www.googleapis.com > /dev/null 2>&1
nping -c 5 --tcp-connect -p 80,8080 storage.googleapis.com > /dev/null 2>&1
nping -c 5 --tcp-connect -p 80,8080 https://a-hub-us-run-httpbin-wapotrwjpq-nw.a.run.app > /dev/null 2>&1
EOF
chmod a+x /usr/local/bin/light-traffic

# heavy-traffic generator
cat <<'EOF' >/usr/local/bin/heavy-traffic
#! /bin/bash
i=0
while [ $i -lt 5 ]; do
    ab -n $1 -c $2 vm.site1.corp > /dev/null 2>&1
    ab -n $1 -c $2 vm.eu.hub.g.corp > /dev/null 2>&1
    ab -n $1 -c $2 vm.site2.corp > /dev/null 2>&1
    ab -n $1 -c $2 vm.us.hub.g.corp > /dev/null 2>&1
    ab -n $1 -c $2 icanhazip.com > /dev/null 2>&1
    ab -n $1 -c $2 www.googleapis.com > /dev/null 2>&1
    ab -n $1 -c $2 storage.googleapis.com > /dev/null 2>&1
    ab -n $1 -c $2 https://a-hub-us-run-httpbin-wapotrwjpq-nw.a.run.app > /dev/null 2>&1
    let i=i+1
  sleep 5
done
EOF
chmod a+x /usr/local/bin/heavy-traffic

# traffic generators (ipv6)
#---------------------------

# light-traffic generator
cat <<'EOF' >/usr/local/bin/light-traffic-ipv6
nping -c 5 -6 --tcp-connect -p 80,8080 vm.site1.corp > /dev/null 2>&1
nping -c 5 -6 --tcp-connect -p 80,8080 vm.eu.hub.g.corp > /dev/null 2>&1
nping -c 5 -6 --tcp-connect -p 80,8080 vm.site2.corp > /dev/null 2>&1
nping -c 5 -6 --tcp-connect -p 80,8080 vm.us.hub.g.corp > /dev/null 2>&1
nping -c 5 -6 --tcp-connect -p 80,8080 icanhazip.com > /dev/null 2>&1
nping -c 5 -6 --tcp-connect -p 80,8080 www.googleapis.com > /dev/null 2>&1
nping -c 5 -6 --tcp-connect -p 80,8080 storage.googleapis.com > /dev/null 2>&1
nping -c 5 -6 --tcp-connect -p 80,8080 https://a-hub-us-run-httpbin-wapotrwjpq-nw.a.run.app > /dev/null 2>&1
EOF
chmod a+x /usr/local/bin/light-traffic-ipv6

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
*/1 * * * * /usr/local/bin/light-traffic 2>&1 > /dev/null
*/1 * * * * /usr/local/bin/heavy-traffic 15 1 2>&1 > /dev/null
*/2 * * * * /usr/local/bin/heavy-traffic 3 1 2>&1 > /dev/null
*/3 * * * * /usr/local/bin/heavy-traffic 8 2 2>&1 > /dev/null
*/5 * * * * /usr/local/bin/heavy-traffic 5 1 2>&1 > /dev/null
EOF

crontab /etc/cron.d/traffic-gen
