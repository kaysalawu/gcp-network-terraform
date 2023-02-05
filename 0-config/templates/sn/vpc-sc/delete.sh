
gcloud -q services vpc-peerings disable-vpc-service-controls \
--project=${PROJECT} \
--network=${NETWORK} \
--service=${SERVICE}
