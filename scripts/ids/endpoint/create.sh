
gcloud ids endpoints create ${ENDPOINT_NAME} \
--project=${PROJECT_ID} \
--network=${NETWORK} \
--zone=${ZONE} \
--severity=${SEVERITY} \
--no-async
