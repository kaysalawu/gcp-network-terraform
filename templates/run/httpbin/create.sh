
PORT=${CONTAINER_PORT}
DOCKER_IMAGE=kennethreitz/httpbin

gcloud config set project ${PROJECT}
gcloud -q auth configure-docker ${GCR_HOST}
docker pull $DOCKER_IMAGE
docker tag $DOCKER_IMAGE ${IMAGE_REPO}
docker push ${IMAGE_REPO}
gcloud config unset project
