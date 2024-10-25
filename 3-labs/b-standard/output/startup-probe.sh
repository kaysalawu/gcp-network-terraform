#! /bin/bash

exec > /var/log/gcp-startup.log 2>&1
export DEBIAN_FRONTEND=noninteractive

apt update
apt install -y unzip jq tcpdump dnsutils net-tools nmap apache2-utils iperf3
apt install -y ca-certificates curl gnupg lsb-release
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
docker version
docker compose version

########################################################
# test scripts (ipv4)
########################################################

# ping-ipv4

cat <<'EOF' >/usr/local/bin/ping-ipv4
echo -e "\n=============================="
echo -e " ping ipv4 ..."
echo "=============================="
echo "site1-vm       - 10.10.1.9 -$(timeout 3 ping -4 -qc2 -W1 10.10.1.9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "hub-eu-vm      - 10.1.11.9 -$(timeout 3 ping -4 -qc2 -W1 10.1.11.9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke1-eu-vm   - 10.11.11.9 -$(timeout 3 ping -4 -qc2 -W1 10.11.11.9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke1-eu-ilb - 10.11.11.30 -$(timeout 3 ping -4 -qc2 -W1 10.11.11.30 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "site2-vm       - 10.20.1.9 -$(timeout 3 ping -4 -qc2 -W1 10.20.1.9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "hub-us-vm      - 10.1.21.9 -$(timeout 3 ping -4 -qc2 -W1 10.1.21.9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke2-us-vm   - 10.22.21.9 -$(timeout 3 ping -4 -qc2 -W1 10.22.21.9 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "spoke2-us-ilb - 10.22.21.30 -$(timeout 3 ping -4 -qc2 -W1 10.22.21.30 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
EOF
chmod a+x /usr/local/bin/ping-ipv4

# ping-dns4

cat <<'EOF' >/usr/local/bin/ping-dns4
echo -e "\n=============================="
echo -e " ping dns ipv4 ..."
echo "=============================="
echo "vm.site1.corp - $(timeout 3 dig +short vm.site1.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 vm.site1.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.eu.hub.g.corp - $(timeout 3 dig +short vm.eu.hub.g.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 vm.eu.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.eu.spoke1.g.corp - $(timeout 3 dig +short vm.eu.spoke1.g.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 vm.eu.spoke1.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "ilb.eu.spoke1.g.corp - $(timeout 3 dig +short ilb.eu.spoke1.g.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 ilb.eu.spoke1.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.site2.corp - $(timeout 3 dig +short vm.site2.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 vm.site2.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.us.hub.g.corp - $(timeout 3 dig +short vm.us.hub.g.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 vm.us.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.us.spoke2.g.corp - $(timeout 3 dig +short vm.us.spoke2.g.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 vm.us.spoke2.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "ilb.us.spoke2.g.corp - $(timeout 3 dig +short ilb.us.spoke2.g.corp | tail -n1) -$(timeout 3 ping -4 -qc2 -W1 ilb.us.spoke2.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
EOF
chmod a+x /usr/local/bin/ping-dns4

# curl-ipv4

cat <<'EOF' >/usr/local/bin/curl-ipv4
echo -e "\n=============================="
echo -e " curl ipv4 ..."
echo "=============================="
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
echo -e "\n=============================="
echo -e " curl dns ipv4 ..."
echo "=============================="
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
echo -e "\n=============================="
echo -e " trace ipv4 ..."
echo "=============================="
echo -e "\nsite1-vm      "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.10.1.9
echo -e "\nhub-eu-vm     "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.1.11.9
echo -e "\nspoke1-eu-vm  "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.11.11.9
echo -e "\nspoke1-eu-ilb"
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.11.11.30
echo -e "\nsite2-vm      "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.20.1.9
echo -e "\nhub-us-vm     "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.1.21.9
echo -e "\nspoke2-us-vm  "
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.22.21.9
echo -e "\nspoke2-us-ilb"
echo -e "-------------------------------------"
timeout 9 tracepath -4 10.22.21.30
EOF
chmod a+x /usr/local/bin/trace-ipv4

# ptr-ipv4

cat <<'EOF' >/usr/local/bin/ptr-ipv4
echo -e "\n=============================="
echo -e " PTR ipv4 ..."
echo "=============================="
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

# ping-dns6

cat <<'EOF' >/usr/local/bin/ping-dns6
echo -e "\n=============================="
echo -e " ping dns ipv6 ..."
echo "=============================="
echo "vm.site1.corp - $(timeout 3 dig AAAA +short vm.site1.corp | tail -n1) -$(timeout 3 ping -6 -qc2 -W1 vm.site1.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.eu.hub.g.corp - $(timeout 3 dig AAAA +short vm.eu.hub.g.corp | tail -n1) -$(timeout 3 ping -6 -qc2 -W1 vm.eu.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.eu.spoke1.g.corp - $(timeout 3 dig AAAA +short vm.eu.spoke1.g.corp | tail -n1) -$(timeout 3 ping -6 -qc2 -W1 vm.eu.spoke1.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "ilb.eu.spoke1.g.corp - $(timeout 3 dig AAAA +short ilb.eu.spoke1.g.corp | tail -n1) -$(timeout 3 ping -6 -qc2 -W1 ilb.eu.spoke1.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.site2.corp - $(timeout 3 dig AAAA +short vm.site2.corp | tail -n1) -$(timeout 3 ping -6 -qc2 -W1 vm.site2.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.us.hub.g.corp - $(timeout 3 dig AAAA +short vm.us.hub.g.corp | tail -n1) -$(timeout 3 ping -6 -qc2 -W1 vm.us.hub.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "vm.us.spoke2.g.corp - $(timeout 3 dig AAAA +short vm.us.spoke2.g.corp | tail -n1) -$(timeout 3 ping -6 -qc2 -W1 vm.us.spoke2.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
echo "ilb.us.spoke2.g.corp - $(timeout 3 dig AAAA +short ilb.us.spoke2.g.corp | tail -n1) -$(timeout 3 ping -6 -qc2 -W1 ilb.us.spoke2.g.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "$5" ms":"NA") }')"
EOF
chmod a+x /usr/local/bin/ping-dns6

# curl-dns6

cat <<'EOF' >/usr/local/bin/curl-dns6
echo -e "\n=============================="
echo -e " curl dns ipv6 ..."
echo "=============================="
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.site1.corp) - vm.site1.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.eu.hub.g.corp) - vm.eu.hub.g.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.eu.spoke1.g.corp) - vm.eu.spoke1.g.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb.eu.spoke1.g.corp) - ilb.eu.spoke1.g.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ep.eu.spoke1-eu-ilb.spoke2.g.corp) - ep.eu.spoke1-eu-ilb.spoke2.g.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.site2.corp) - vm.site2.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.us.hub.g.corp) - vm.us.hub.g.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.us.spoke2.g.corp) - vm.us.spoke2.g.corp"
echo  "$(timeout 3 curl -6 -kL --max-time 3.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null ilb.us.spoke2.g.corp) - ilb.us.spoke2.g.corp"
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

# trace-dns6

cat <<'EOF' >/usr/local/bin/trace-dns6
echo -e "\n=============================="
echo -e " trace ipv6 ..."
echo "=============================="
echo -e "\nsite1-vm      "
echo -e "-------------------------------------"
timeout 9 tracepath -6 vm.site1.corp
echo -e "\nhub-eu-vm     "
echo -e "-------------------------------------"
timeout 9 tracepath -6 vm.eu.hub.g.corp
echo -e "\nspoke1-eu-vm  "
echo -e "-------------------------------------"
timeout 9 tracepath -6 vm.eu.spoke1.g.corp
echo -e "\nspoke1-eu-ilb"
echo -e "-------------------------------------"
timeout 9 tracepath -6 ilb.eu.spoke1.g.corp
echo -e "\nsite2-vm      "
echo -e "-------------------------------------"
timeout 9 tracepath -6 vm.site2.corp
echo -e "\nhub-us-vm     "
echo -e "-------------------------------------"
timeout 9 tracepath -6 vm.us.hub.g.corp
echo -e "\nspoke2-us-vm  "
echo -e "-------------------------------------"
timeout 9 tracepath -6 vm.us.spoke2.g.corp
echo -e "\nspoke2-us-ilb"
echo -e "-------------------------------------"
timeout 9 tracepath -6 ilb.us.spoke2.g.corp
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

cat <<'EOF' >/usr/local/bin/light-traffic
nping -c 5 --tcp-connect -p 80,8080 vm.site1.corp > /dev/null 2>&1
nping -c 5 --tcp-connect -p 80,8080 vm.eu.hub.g.corp > /dev/null 2>&1
nping -c 5 --tcp-connect -p 80,8080 vm.eu.spoke1.g.corp > /dev/null 2>&1
nping -c 5 --tcp-connect -p 80,8080 vm.site2.corp > /dev/null 2>&1
nping -c 5 --tcp-connect -p 80,8080 vm.us.hub.g.corp > /dev/null 2>&1
nping -c 5 --tcp-connect -p 80,8080 vm.us.spoke2.g.corp > /dev/null 2>&1
nping -c 5 --tcp-connect -p 80,8080 icanhazip.com > /dev/null 2>&1
nping -c 5 --tcp-connect -p 80,8080 www.googleapis.com > /dev/null 2>&1
nping -c 5 --tcp-connect -p 80,8080 storage.googleapis.com > /dev/null 2>&1
nping -c 5 --tcp-connect -p 80,8080 https://b-hub-us-run-httpbin-wapotrwjpq-nw.a.run.app > /dev/null 2>&1
nping -c 5 --tcp-connect -p 80,8080 https://b-spoke1-eu-run-httpbin-expmorqqnq-nw.a.run.app > /dev/null 2>&1
nping -c 5 --tcp-connect -p 80,8080 https://b-spoke2-us-run-httpbin-4e4skt6nna-wl.a.run.app > /dev/null 2>&1
EOF
chmod a+x /usr/local/bin/light-traffic

# heavy-traffic generator

cat <<'EOF' >/usr/local/bin/heavy-traffic
#! /bin/bash
i=0
while [ $i -lt 5 ]; do
    ab -n $1 -c $2 vm.site1.corp > /dev/null 2>&1
    ab -n $1 -c $2 vm.eu.hub.g.corp > /dev/null 2>&1
    ab -n $1 -c $2 vm.eu.spoke1.g.corp > /dev/null 2>&1
    ab -n $1 -c $2 vm.site2.corp > /dev/null 2>&1
    ab -n $1 -c $2 vm.us.hub.g.corp > /dev/null 2>&1
    ab -n $1 -c $2 vm.us.spoke2.g.corp > /dev/null 2>&1
    ab -n $1 -c $2 icanhazip.com > /dev/null 2>&1
    ab -n $1 -c $2 www.googleapis.com > /dev/null 2>&1
    ab -n $1 -c $2 storage.googleapis.com > /dev/null 2>&1
    ab -n $1 -c $2 https://b-hub-us-run-httpbin-wapotrwjpq-nw.a.run.app > /dev/null 2>&1
    ab -n $1 -c $2 https://b-spoke1-eu-run-httpbin-expmorqqnq-nw.a.run.app > /dev/null 2>&1
    ab -n $1 -c $2 https://b-spoke2-us-run-httpbin-4e4skt6nna-wl.a.run.app > /dev/null 2>&1
    let i=i+1
  sleep 5
done
EOF
chmod a+x /usr/local/bin/heavy-traffic

########################################################
# traffic generators (ipv6)
########################################################

# light-traffic generator

cat <<'EOF' >/usr/local/bin/light-traffic-ipv6
nping -c 5 -6 --tcp-connect -p 80,8080 vm.site1.corp > /dev/null 2>&1
nping -c 5 -6 --tcp-connect -p 80,8080 vm.eu.hub.g.corp > /dev/null 2>&1
nping -c 5 -6 --tcp-connect -p 80,8080 vm.eu.spoke1.g.corp > /dev/null 2>&1
nping -c 5 -6 --tcp-connect -p 80,8080 vm.site2.corp > /dev/null 2>&1
nping -c 5 -6 --tcp-connect -p 80,8080 vm.us.hub.g.corp > /dev/null 2>&1
nping -c 5 -6 --tcp-connect -p 80,8080 vm.us.spoke2.g.corp > /dev/null 2>&1
nping -c 5 -6 --tcp-connect -p 80,8080 icanhazip.com > /dev/null 2>&1
nping -c 5 -6 --tcp-connect -p 80,8080 www.googleapis.com > /dev/null 2>&1
nping -c 5 -6 --tcp-connect -p 80,8080 storage.googleapis.com > /dev/null 2>&1
nping -c 5 -6 --tcp-connect -p 80,8080 https://b-hub-us-run-httpbin-wapotrwjpq-nw.a.run.app > /dev/null 2>&1
nping -c 5 -6 --tcp-connect -p 80,8080 https://b-spoke1-eu-run-httpbin-expmorqqnq-nw.a.run.app > /dev/null 2>&1
nping -c 5 -6 --tcp-connect -p 80,8080 https://b-spoke2-us-run-httpbin-4e4skt6nna-wl.a.run.app > /dev/null 2>&1
EOF
chmod a+x /usr/local/bin/light-traffic-ipv6

# heavy-traffic generator

cat <<'EOF' >/usr/local/bin/heavy-traffic-ipv6
#! /bin/bash

get_ipv6() {
  ipv6=$(host -t AAAA $1 | awk '/has IPv6 address/ {print $5}')
  if [ -z "$ipv6" ]; then
    echo $1
  else
    echo $ipv6
  fi
}

i=0
while [ $i -lt 8 ]; do
    ab -s 3 -n $1 -c $2 [$(get_ipv6 vm.site1.corp)]/ > /dev/null 2>&1
  # check if ab command was successful
  if [ $? -ne 0 ]; then
    echo "target: vm.site1.corp failed"
    exit 1
  else
    echo "target: vm.site1.corp passed"
  fi
    ab -s 3 -n $1 -c $2 [$(get_ipv6 vm.eu.hub.g.corp)]/ > /dev/null 2>&1
  # check if ab command was successful
  if [ $? -ne 0 ]; then
    echo "target: vm.eu.hub.g.corp failed"
    exit 1
  else
    echo "target: vm.eu.hub.g.corp passed"
  fi
    ab -s 3 -n $1 -c $2 [$(get_ipv6 vm.eu.spoke1.g.corp)]/ > /dev/null 2>&1
  # check if ab command was successful
  if [ $? -ne 0 ]; then
    echo "target: vm.eu.spoke1.g.corp failed"
    exit 1
  else
    echo "target: vm.eu.spoke1.g.corp passed"
  fi
    ab -s 3 -n $1 -c $2 [$(get_ipv6 vm.site2.corp)]/ > /dev/null 2>&1
  # check if ab command was successful
  if [ $? -ne 0 ]; then
    echo "target: vm.site2.corp failed"
    exit 1
  else
    echo "target: vm.site2.corp passed"
  fi
    ab -s 3 -n $1 -c $2 [$(get_ipv6 vm.us.hub.g.corp)]/ > /dev/null 2>&1
  # check if ab command was successful
  if [ $? -ne 0 ]; then
    echo "target: vm.us.hub.g.corp failed"
    exit 1
  else
    echo "target: vm.us.hub.g.corp passed"
  fi
    ab -s 3 -n $1 -c $2 [$(get_ipv6 vm.us.spoke2.g.corp)]/ > /dev/null 2>&1
  # check if ab command was successful
  if [ $? -ne 0 ]; then
    echo "target: vm.us.spoke2.g.corp failed"
    exit 1
  else
    echo "target: vm.us.spoke2.g.corp passed"
  fi
    ab -s 3 -n $1 -c $2 [$(get_ipv6 icanhazip.com)]/ > /dev/null 2>&1
  # check if ab command was successful
  if [ $? -ne 0 ]; then
    echo "target: icanhazip.com failed"
    exit 1
  else
    echo "target: icanhazip.com passed"
  fi
    ab -s 3 -n $1 -c $2 [$(get_ipv6 www.googleapis.com)]/ > /dev/null 2>&1
  # check if ab command was successful
  if [ $? -ne 0 ]; then
    echo "target: www.googleapis.com failed"
    exit 1
  else
    echo "target: www.googleapis.com passed"
  fi
    ab -s 3 -n $1 -c $2 [$(get_ipv6 storage.googleapis.com)]/ > /dev/null 2>&1
  # check if ab command was successful
  if [ $? -ne 0 ]; then
    echo "target: storage.googleapis.com failed"
    exit 1
  else
    echo "target: storage.googleapis.com passed"
  fi
    ab -s 3 -n $1 -c $2 [$(get_ipv6 https://b-hub-us-run-httpbin-wapotrwjpq-nw.a.run.app)]/ > /dev/null 2>&1
  # check if ab command was successful
  if [ $? -ne 0 ]; then
    echo "target: https://b-hub-us-run-httpbin-wapotrwjpq-nw.a.run.app failed"
    exit 1
  else
    echo "target: https://b-hub-us-run-httpbin-wapotrwjpq-nw.a.run.app passed"
  fi
    ab -s 3 -n $1 -c $2 [$(get_ipv6 https://b-spoke1-eu-run-httpbin-expmorqqnq-nw.a.run.app)]/ > /dev/null 2>&1
  # check if ab command was successful
  if [ $? -ne 0 ]; then
    echo "target: https://b-spoke1-eu-run-httpbin-expmorqqnq-nw.a.run.app failed"
    exit 1
  else
    echo "target: https://b-spoke1-eu-run-httpbin-expmorqqnq-nw.a.run.app passed"
  fi
    ab -s 3 -n $1 -c $2 [$(get_ipv6 https://b-spoke2-us-run-httpbin-4e4skt6nna-wl.a.run.app)]/ > /dev/null 2>&1
  # check if ab command was successful
  if [ $? -ne 0 ]; then
    echo "target: https://b-spoke2-us-run-httpbin-4e4skt6nna-wl.a.run.app failed"
    exit 1
  else
    echo "target: https://b-spoke2-us-run-httpbin-4e4skt6nna-wl.a.run.app passed"
  fi
    let i=i+1
  sleep 5
done
EOF
chmod a+x /usr/local/bin/heavy-traffic-ipv6

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
ExecStart=/usr/bin/docker compose -f /var/lib/gcp/fastapi/docker-compose-http-80.yml up -d && \
          /usr/bin/docker compose -f /var/lib/gcp/fastapi/docker-compose-http-8080.yml up -d
ExecStop=/usr/bin/docker compose -f /var/lib/gcp/fastapi/docker-compose-http-80.yml down && \
         /usr/bin/docker compose -f /var/lib/gcp/fastapi/docker-compose-http-8080.yml down
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
*/1 * * * * /usr/local/bin/light-traffic 2>&1 > /dev/null
*/1 * * * * /usr/local/bin/heavy-traffic 15 1 2>&1 > /dev/null
*/2 * * * * /usr/local/bin/heavy-traffic 3 1 2>&1 > /dev/null
*/3 * * * * /usr/local/bin/heavy-traffic 8 2 2>&1 > /dev/null
*/5 * * * * /usr/local/bin/heavy-traffic 5 1 2>&1 > /dev/null
EOF

crontab /etc/cron.d/traffic-gen
