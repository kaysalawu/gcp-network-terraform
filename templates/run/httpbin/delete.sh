
gcloud config set project ${PROJECT}
gcloud -q auth configure-docker ${GCR_HOST}
gcloud config unset project
