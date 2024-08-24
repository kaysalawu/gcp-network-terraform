
gcloud compute url-maps import ${URL_MAP_NAME} \
--project=${PROJECT_ID} \
--source=<(echo '${YAML}')
