
gcloud config set project ${PROJECT}
gcloud -q auth configure-docker ${AR_HOST}
gcloud builds submit --tag ${IMAGE_REPO} ${DOCKERFILE_DIR}
gcloud config unset project
