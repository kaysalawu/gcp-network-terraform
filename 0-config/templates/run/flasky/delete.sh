
gcloud config set project ${PROJECT}
gcloud -q auth configure-docker ${GCR_HOST}
gcloud -q container images delete ${IMAGE_REPO}
gcloud config unset project
