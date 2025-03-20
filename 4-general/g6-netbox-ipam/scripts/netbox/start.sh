#!/bin/bash

set -e

dir_base=$(pwd)
dir_netbox=${NETBOX_DIR}
log_systemd=$dir_bridge/log_systemd.txt
service_name=netbox

HOSTNAME=$(hostname)
LOCAL_IP=$(hostname -I | awk '{print $1}')

display_delimiter() {
  echo "####################################################################################"
  date
  echo $(basename "$0")
  echo "SYSTEMCTL - Start"
}

start_services() {
  echo -e "\n**********************************************************"
  echo "STEP 1: Start Services"
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

start=$(date +%s)
display_delimiter | tee -a $log_systemd
start_services | tee -a $log_systemd
check_services | tee -a $log_systemd
end=$(date +%s)
elapsed=$(($end-$start))
echo "Completed in $(($elapsed/60))m $(($elapsed%60))s!" | tee -a $log_systemd
