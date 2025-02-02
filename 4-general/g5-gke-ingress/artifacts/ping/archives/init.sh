#!bin/bash

PROJECT_ID=team-aura-networking
LOCATION=europe-west2
CLUSTER_NAME=g5-hub-cluster
APP_PATH=app/python
DOCKERFILE_PING_OPERATOR_PATH=Dockerfile-ping-operator
DOCKERFILE_CONTROL_PLANE_PATH=Dockerfile-control-plane

CURRENT_DIR=$(pwd)

gcloud container clusters get-credentials $CLUSTER_NAME --region "$LOCATION-b" --project=$PROJECT_ID

# Step 1: Create the PingResource Custom Resource Definition (CRD)
#---------------------------------------
# (pingresource-crd.yaml)

# Step 2: Apply the CRD to the Cluster
#---------------------------------------
kubectl apply -f pingresource-crd.yaml
kubectl get crd

# Step 3: Test locally
#---------------------------------------
cd $APP_PATH
sudo python3 -m venv ping-venv
source ping-venv/bin/activate
pip install kopf fastapi kubernetes uvicorn
# create ping_operator-local.py
kopf run ping_operator-local.py

# open another terminal and run

cd $CURRENT_DIR
kubectl apply -f pingresource-sample.yaml
kubectl get pingresource test-ping -o yaml

# ping-operator$ kubectl get pingresource test-ping -o yaml
# apiVersion: example.com/v1
# kind: PingResource
# metadata:
#   annotations:
#     kopf.zalando.org/last-handled-configuration: |
#       {"spec":{"message":"Ping"}}
#     kubectl.kubernetes.io/last-applied-configuration: |
#       {"apiVersion":"example.com/v1","kind":"PingResource","metadata":{"annotations":{},"name":"test-ping","namespace":"default"},"spec":{"message":"Ping"}}
#   creationTimestamp: "2024-11-07T12:40:07Z"
#   generation: 2
#   name: test-ping
#   namespace: default
#   resourceVersion: "56396815"
#   uid: 85ece180-7453-437f-a3f1-fce4c00c02d7
# spec:
#   message: Ping
# status:
#   response: Ping - Pong

# Step 4: Deploy to GKE
#---------------------------------------
gcloud artifacts repositories create ping-repo \
    --project=$PROJECT_ID \
    --repository-format=docker \
    --location=$LOCATION \
    --description="Repository for Ping"

gcloud auth configure-docker europe-west2-docker.pkg.dev

cd $APP_PATH
docker build -t ping-operator:latest -f $DOCKERFILE_PING_OPERATOR_PATH .
docker build -t control-plane:latest -f $DOCKERFILE_CONTROL_PLANE_PATH .
docker tag ping-operator:latest europe-west2-docker.pkg.dev/$PROJECT_ID/ping-repo/ping-operator:latest
docker tag control-plane:latest europe-west2-docker.pkg.dev/$PROJECT_ID/ping-repo/control-plane:latest
docker push europe-west2-docker.pkg.dev/$PROJECT_ID/ping-repo/ping-operator:latest
docker push europe-west2-docker.pkg.dev/$PROJECT_ID/ping-repo/control-plane:latest

cd $CURRENT_DIR
kubectl apply -f ping-operator-deploy.yaml
kubectl apply -f pingresource-sample.yaml
kubectl get pingresource test-ping
kubectl get pingresource test-ping -o yaml

# Step 5: Create control plane API and test locally
#----------------------------------------------------
cd $APP_PATH
source ping-venv/bin/activate
# create control_plane_with_api.py
python -m uvicorn control_plane-local:app --reload --host 0.0.0.0 --port 9000
# in another terminal
curl -X GET "http://127.0.0.1:9000/resources" -H "Content-Type: application/json"
# {"resources":{}}python$

# Step 6: Create client API and test locally
#-----------------------------------------------
source ping-venv/bin/activate
sudo su

# create ping_api.py
python -m uvicorn ping_api:app --reload --host 0.0.0.0 --port 8000

# in another terminal
curl -X POST "http://127.0.0.1:8000/api/create_ping" -H "Content-Type: application/json" -d '{"name": "test-ping1", "message": "Hello from FastAPI"}'
curl -X GET "http://127.0.0.1:9000/resources" -H "Content-Type: application/json"
# {"status":"success","name":"test-ping1"}python$
# {"resources":{"test-ping1":"created"}}python$

curl -X POST "http://127.0.0.1:8000/api/create_ping" -H "Content-Type: application/json" -d '{"name": "test-ping2", "message": "Hello from FastAPI"}'
curl -X GET "http://127.0.0.1:9000/resources" -H "Content-Type: application/json"
# {"status":"success","name":"test-ping2"}python$
# {"resources":{"test-ping1":"created","test-ping2":"created"}}python$

curl -X POST "http://127.0.0.1:8000/api/create_ping" -H "Content-Type: application/json" -d '{"name": "test-ping3", "message": "Hello from FastAPI"}'
curl -X GET "http://127.0.0.1:9000/resources" -H "Content-Type: application/json"
# {"status":"success","name":"test-ping3"}python$
# {"resources":{"test-ping1":"created","test-ping2":"created","test-ping3":"created"}}python$

curl -X DELETE "http://127.0.0.1:8000/api/delete_ping/test-ping3"
curl -X GET "http://127.0.0.1:9000/resources" -H "Content-Type: application/json"
# {"status":"success","message":"Resource test-ping3 deleted"}python$
# {"resources":{"test-ping1":"created","test-ping2":"created"}}python$

curl -X DELETE "http://127.0.0.1:8000/api/delete_ping/test-ping2"
curl -X GET "http://127.0.0.1:9000/resources" -H "Content-Type: application/json"
# {"status":"success","message":"Resource test-ping2 deleted"}python$
# {"resources":{"test-ping1":"created"}}python$

ping-operator$ kubectl get pingresource
NAME AGE
test-ping1 37s
test-ping2 68s
ping-operator$

# Step 7: delete all resources
#-----------------------------------------------

kubectl delete pingresource test-ping1
kubectl delete pingresource test-ping2
kubectl delete pingresource test-ping3
kubectl delete -f ping-operator-deploy.yaml
kubectl delete -f pingresource-sample.yaml
kubectl delete -f pingresource-crd.yaml

gcloud artifacts repositories delete ping-repo \
    --project=$PROJECT_ID \
    --location=$LOCATION \
    --quiet
