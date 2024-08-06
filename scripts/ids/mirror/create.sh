
export FORWARDING_RULE=$(gcloud ids endpoints describe ${ENDPOINT_NAME} \
--project=${PROJECT_ID} \
--zone=${ZONE} \
--format="value(endpointForwardingRule)")

gcloud compute packet-mirrorings create ${MIRROR.name} \
--project=${PROJECT_ID} \
--network=${NETWORK} \
--region=${REGION} \
--collector-ilb=$FORWARDING_RULE \
--mirrored-tags=${MIRROR.tags}
