
gcloud compute network-endpoint-groups create ${NEG_NAME} \
--project=${PROJECT_ID} \
--region=${REGION} \
--network-endpoint-type=PRIVATE_SERVICE_CONNECT \
--psc-target-service="${TARGET_SERVICE}"
