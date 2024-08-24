
gcloud compute target-http-proxies import ${TARGET_PROXY_NAME} \
--project=${PROJECT_ID} \
--source=<(echo '${YAML}')
