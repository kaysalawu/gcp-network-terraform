
gcloud config set project ${PROJECT}
gcloud -q auth configure-docker ${AR_HOST}
gcloud artifacts docker images delete ${IMAGE_REPO} --quiet
gcloud config unset project
