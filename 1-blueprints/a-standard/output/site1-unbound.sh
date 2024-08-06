#! /bin/bash

# disable systemd-resolved as it conflicts with dnsmasq on port 53

systemctl stop systemd-resolved
systemctl disable systemd-resolved
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "$(hostname -I | cut -d' ' -f1) $(hostname)" >> /etc/hosts

apt update
apt install -y tcpdump dnsutils net-tools unbound

touch /etc/unbound/unbound.log
chmod a+x /etc/unbound/unbound.log

cat <<EOF > /etc/unbound/unbound.conf
server:
        port: 53
        do-ip4: yes
        do-udp: yes
        do-tcp: yes

        interface: 0.0.0.0

        access-control: 0.0.0.0 deny
        access-control: 127.0.0.0/8 allow
        access-control: 10.0.0.0/8 allow
        access-control: 192.168.0.0/16 allow
        access-control: 172.16.0.0/12 allow
        access-control: 35.199.192.0/19 allow

        # local data records
        local-data: "app1.site1.onprem 3600 IN A 10.10.1.9"
        local-data: "vertex.site1.onprem 3600 IN A 10.10.1.20"
        local-data: "app1.site2.onprem 3600 IN A 10.20.1.9"

        # hosts redirected to PSC
        local-zone: storage.googleapis.com redirect
        local-zone: bigquery.googleapis.com redirect
        local-zone: europe-west2-aiplatform.googleapis.com redirect
        local-zone: us-west2-aiplatform.googleapis.com redirect
        local-zone: run.app redirect
        local-zone: europe-west2-run.googleapis.com redirect
        local-zone: us-west2-run.googleapis.com redirect
        local-zone: europe-west2-run.googleapis.com redirect
        local-zone: us-west2-run.googleapis.com redirect

        local-data: "storage.googleapis.com 3600 IN A 10.1.0.1"
        local-data: "bigquery.googleapis.com 3600 IN A 10.1.0.1"
        local-data: "europe-west2-aiplatform.googleapis.com 3600 IN A 10.1.0.1"
        local-data: "us-west2-aiplatform.googleapis.com 3600 IN A 10.1.0.1"
        local-data: "run.app 3600 IN A 10.1.0.1"
        local-data: "europe-west2-run.googleapis.com 3600 IN A 10.1.11.80"
        local-data: "us-west2-run.googleapis.com 3600 IN A 10.1.21.80"
        local-data: "europe-west2-run.googleapis.com 3600 IN A 10.11.11.40"
        local-data: "us-west2-run.googleapis.com 3600 IN A 10.22.21.40"

forward-zone:
        name: "gcp."
        forward-addr: 10.1.11.40
        forward-addr: 10.1.21.40

forward-zone:
        name: "ahuball.p.googleapis.com"
        forward-addr: 10.1.11.40
        forward-addr: 10.1.21.40

forward-zone:
        name: "."
        forward-addr: 8.8.8.8
        forward-addr: 8.8.4.4
EOF

systemctl enable unbound
systemctl restart unbound
apt install resolvconf
resolvconf -u
