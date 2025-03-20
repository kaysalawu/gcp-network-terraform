#!/bin/bash

set -e

dir_base=$(pwd)
dir_netbox=${NETBOX_DIR}
log_netbox=$dir_netbox/log_netbox.txt
service_name=netbox

HOSTNAME=$(hostname)
LOCAL_IP=$(hostname -I | awk '{print $1}')

display_delimiter() {
  echo "####################################################################################"
  date
  echo $(basename "$0")
}

clone_repo() {
  echo -e "\n**********************************************************"
  echo "STEP 1: Clone ${NETBOX_REPO}"
  echo "**********************************************************"
  echo "git clone ${NETBOX_REPO}"
  git clone ${NETBOX_REPO} || true
}

configure_netbox_settings() {
  echo -e "\n**********************************************************"
  echo "STEP 2: Configure Netbox Settings"
  echo "**********************************************************"

  cat <<EOF > $dir_netbox/docker-compose.override.yml
services:
  netbox:
    ports:
      - ${NETBOX_PORT}:8080
    environment:
      - no_proxy=localhost,
EOF
}

start_services() {
  echo -e "\n**********************************************************"
  echo "STEP 2: Start Services"
  echo "**********************************************************"
  cd "$dir_netbox/netbox-docker"
  echo "docker compose up -d"
  docker compose up -d
  cd "$dir_base"
}

check_services() {
  echo -e "\n**********************************************************"
  echo "STEP 3: Check Services"
  echo "**********************************************************"
  echo "sleep 3 ..." && sleep 3
  echo "docker ps"
  docker ps
  echo ""
  echo "docker logs netbox"
  docker logs netbox
}

systemd_config() {
  echo -e "\n**********************************************************"
  echo "STEP 4: Systemd Config"
  echo "**********************************************************"
  echo "Create: /etc/systemd/system/${service_name}.service"
  cat <<EOF > /etc/systemd/system/${service_name}.service
  [Unit]
  Description=Script for ${service_name}

  [Service]
  Type=oneshot
  ExecStart=-$dir_netbox/start.sh
  RemainAfterExit=true
  ExecStop=-$dir_netbox/stop.sh
  StandardOutput=journal

  [Install]
  WantedBy=multi-user.target
EOF
  cat /etc/systemd/system/${service_name}.service
  systemctl start ${service_name}
  systemctl enable ${service_name}
}

start=$(date +%s)
display_delimiter | tee -a $log_netbox
clone_repo | tee -a $log_netbox
configure_netbox_settings | tee -a $log_netbox
start_services | tee -a $log_netbox
check_services | tee -a $log_netbox
systemd_config | tee -a $log_netbox
end=$(date +%s)
elapsed=$(($end-$start))
echo "Completed in $(($elapsed/60))m $(($elapsed%60))s!" | tee -a $log_netbox
