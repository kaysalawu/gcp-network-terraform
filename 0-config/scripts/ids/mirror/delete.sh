
gcloud -q compute packet-mirrorings delete ${MIRROR.name} \
--project=${PROJECT_ID} \
--region=${REGION}
