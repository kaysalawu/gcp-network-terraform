#!/bin/bash

# https://cloud.google.com/architecture/creating-kubernetes-engine-private-clusters-with-net-proxies

gcloud config set project ${PROJECT_ID}
gcloud -q auth configure-docker ${GCR_HOST}
gcloud config set compute/region ${REGION}
gcloud container clusters get-credentials ${CLUSTER} --region=${REGION}
gcloud builds submit --tag ${IMAGE_REPO} .
kubectl run k8s-api-proxy --image=${IMAGE_REPO} --port=8118
kubectl create -f manifests
kubectl get service/k8s-api-proxy

export LB_IP=`kubectl get  service/k8s-api-proxy \
-o jsonpath='{.status.loadBalancer.ingress[].ip}'`
export CONTROLLER_IP=`gcloud container clusters describe ${CLUSTER} \
--region=${REGION} \
--format="get(privateClusterConfig.privateEndpoint)"`

# config to test on a gcp instance
cat <<EOF > output.sh
gcloud config set project ${PROJECT_ID}
gcloud -q auth configure-docker ${GCR_HOST}
gcloud config set compute/region ${REGION}
gcloud container clusters get-credentials ${CLUSTER} --region=${REGION}
curl -k -x $LB_IP:8118 https://$CONTROLLER_IP/version
EOF
