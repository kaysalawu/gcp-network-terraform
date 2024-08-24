#!/bin/bash

# interfaces

gcloud compute routers add-interface ${SPOKE_CR_NAME} \
--project=${PROJECT_ID} \
--interface-name=${APPLIANCE_NAME}-0  \
--subnetwork=${SUBNET} \
--region=${REGION} \
--ip-address=${SPOKE_CR_IP_0}

gcloud compute routers add-interface ${SPOKE_CR_NAME} \
--project=${PROJECT_ID} \
--interface-name=${APPLIANCE_NAME}-1  \
--redundant-interface=${APPLIANCE_NAME}-0 \
--subnetwork=${SUBNET} \
--region=${REGION} \
--ip-address=${SPOKE_CR_IP_1}

# bgp

gcloud compute routers add-bgp-peer ${SPOKE_CR_NAME} \
--project=${PROJECT_ID} \
--peer-name=${APPLIANCE_NAME}-0 \
--interface=${APPLIANCE_NAME}-0 \
--peer-ip-address=${APPLIANCE_IP} \
--peer-asn=${APPLIANCE_ASN} \
--instance=${APPLIANCE_NAME} \
--region=${REGION} \
--instance-zone=${APPLIANCE_ZONE} \
--advertisement-mode=CUSTOM \
--advertised-route-priority=${APPLIANCE_SESSION_0_METRIC} \
--set-advertisement-ranges=${APPLIANCE_ADVERTISED_PREFIXES}


gcloud compute routers add-bgp-peer ${SPOKE_CR_NAME} \
--project=${PROJECT_ID} \
--peer-name=${APPLIANCE_NAME}-1 \
--interface=${APPLIANCE_NAME}-1 \
--peer-ip-address=${APPLIANCE_IP} \
--peer-asn=${APPLIANCE_ASN} \
--instance=${APPLIANCE_NAME} \
--region=${REGION} \
--instance-zone=${APPLIANCE_ZONE} \
--advertisement-mode=CUSTOM \
--advertised-route-priority=${APPLIANCE_SESSION_0_METRIC} \
--set-advertisement-ranges=${APPLIANCE_ADVERTISED_PREFIXES}
