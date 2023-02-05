
gcloud services peered-dns-domains create ${DNS_ZONE_NAME} \
--project=${PROJECT} \
--network=${NETWORK} \
--service=${SERVICE} \
--dns-suffix=${DNS_SUFFIX}
