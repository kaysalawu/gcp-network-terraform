#! /bin/bash

set -e

base_dir=$(pwd)
init_dir=${INIT_DIR}
log_init=$init_dir/log_init.txt

if [ ! -d "$init_dir" ]; then mkdir -p "$init_dir"; fi

echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding=1' >> /etc/sysctl.conf
sysctl -p

cat <<EOF > /etc/motd
################################################
         Cloudtuple
################################################
Docker Ubuntu
 Date:     $(date)
- Version:  1.0
- Distro:   $(cat /etc/issue)
- Packages:
  - Docker
  - Chrony
################################################

EOF

install_packages() {
  echo "*****************************************"
  echo " Step 1: Install packages"
  echo "*****************************************"
  apt-get update
  apt-get install -y chrony net-tools jq tcpdump dnsutils
  echo ""
  echo "chronyc sources"
  chronyc sources

  echo "*****************************************"
  echo " Step 2: Install docker"
  echo "*****************************************"
  apt-get update
  apt-get install -y ca-certificates curl gnupg lsb-release
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  echo ""
  docker version
  docker compose version

  echo "*****************************************"
  echo " Step 3: Cleanup apt"
  echo "*****************************************"
  apt-get --purge -y autoremove
  apt-get clean
  echo "done!"
}

install_packages | tee -a $log_init
