
gcloud compute network-endpoint-groups create ${NEG_NAME} \
--project=${PROJECT_ID} \
--network=${NETWORK} \
--zone=${ZONE} \
--default-port=${REMOTE_PORT} \
--network-endpoint-type=${NE_TYPE}

gcloud compute network-endpoint-groups update ${NEG_NAME} \
--project=${PROJECT_ID} \
--zone=${ZONE} \
--add-endpoint="ip=${REMOTE_IP},port=${REMOTE_PORT}"
