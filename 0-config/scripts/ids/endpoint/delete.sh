
gcloud -q ids endpoints delete ${ENDPOINT_NAME} \
--project=${PROJECT_ID} \
--zone=${ZONE} \
--no-async
