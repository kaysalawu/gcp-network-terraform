
gcloud beta -q dns response-policies update ${RP_NAME} \
--project=${PROJECT} \
--networks=""

gcloud beta -q dns response-policies delete ${RP_NAME} \
--project=${PROJECT}
