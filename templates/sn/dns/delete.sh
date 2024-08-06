
gcloud -q services peered-dns-domains delete ${DNS_ZONE_NAME} \
--project=${PROJECT} \
--network=${NETWORK} \
--service=${SERVICE}
