#!/bin/bash

export project_id=$(gcloud config list --format="value(core.project)")
export org_id=$(gcloud projects get-ancestors $project_id --format="csv[no-heading](id,type)" | grep ",organization$" | cut -d"," -f1)
export region=europe-west2
export zone=europe-west2-b
export prefix=cloudngfw
export org_prefix=cloudngfw
export billing_project_id=prj-hub-x

gcloud network-security firewall-endpoint-associations list
gcloud network-security firewall-endpoint-associations delete $prefix-association --zone $zone
gcloud network-security firewall-endpoint-associations list
gcloud network-security firewall-endpoints list --zone $zone --organization $org_id
gcloud -q network-security firewall-endpoints delete $org_prefix-$zone --zone=$zone --organization $org_id
gcloud network-security firewall-endpoints list --zone $zone --organization $org_id
gcloud -q network-security security-profile-groups delete $org_prefix-spg --organization $org_id --location=global
gcloud -q network-security security-profiles threat-prevention delete $org_prefix-sp-threat --organization $org_id --location=global
gcloud -q compute forwarding-rules delete $prefix-nlb-ipv4 --region $region
gcloud -q compute backend-services delete $prefix-nlb-bes --region $region
gcloud -q compute health-checks delete $prefix-$region-hc-http80 --region $region
gcloud -q compute instance-groups unmanaged delete $prefix-ig --zone $zone
gcloud -q compute instances delete $prefix-$zone-www --zone=$zone
gcloud -q compute instances delete $prefix-$zone-client --zone=$zone
export user_id=$(gcloud auth list --format="value(account)")
gcloud organizations remove-iam-policy-binding $org_id --member user:$user_id --role roles/resourcemanager.tagAdmin
gcloud organizations remove-iam-policy-binding $org_id --member user:$user_id --role roles/resourcemanager.tagUser
gcloud -q resource-manager tags values delete $project_id/$prefix-vpc-tags/$prefix-vpc-client
gcloud -q resource-manager tags values delete $project_id/$prefix-vpc-tags/$prefix-vpc-server
gcloud -q resource-manager tags values delete $project_id/$prefix-vpc-tags/$prefix-vpc-quarantine
gcloud -q resource-manager tags keys delete $project_id/$prefix-vpc-tags
gcloud -q compute network-firewall-policies associations delete --firewall-policy $prefix-fwpolicy --name $prefix-fwpolicy-association --global-firewall-policy
gcloud -q compute network-firewall-policies delete $prefix-fwpolicy --global
gcloud -q compute routers nats delete $prefix-cloudnat-$region --router=$prefix-cr --router-region $region
gcloud -q compute routers delete $prefix-cr --region=$region
gcloud -q compute addresses delete $prefix-$region-nlbip --region=$region
gcloud -q compute addresses delete $prefix-$region-cloudnatip --region=$region
gcloud -q compute networks subnets delete $prefix-$region-subnet --region $region
gcloud -q compute networks delete $prefix-vpc
