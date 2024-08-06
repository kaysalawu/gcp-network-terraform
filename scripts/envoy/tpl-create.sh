
gcloud compute instance-templates create ${TEMPLATE_NAME} \
--project=${PROJECT_ID} \
--network=${NETWORK_NAME} \
--region=${REGION} \
--subnet=${SUBNET_NAME} \
--image-family=debian-10  \
--image-project=debian-cloud \
--machine-type=e2-medium \
--service-proxy=enabled \
--metadata-from-file=startup-script=<(echo '${METADATA}')
