#!bin/bash

PROJECT=team-aura-networking
LOCATION=europe-west2
CLUSTER_NAME=g1-hub-cluster

gcloud container clusters get-credentials $CLUSTER_NAME --region "$LOCATION-b" --project=$PROJECT

# Step 1: Create the PingResource Custom Resource Definition (CRD)
#---------------------------------------
# (pingresource-crd.yaml)

# Step 2: Apply the CRD to the Cluster
#---------------------------------------
kubectl apply -f pingresource-crd.yaml
kubectl get crd

# Step 3: Test locally
#---------------------------------------
python3 -m venv ping-operator-env
source ping-operator-env/bin/activate
pip install kopf kubernetes
# create ping_operator-local.py
kopf run ping_operator-local.py

# (ping-operator-env) ping-operator$ kopf run ping_operator-local.py
# /home/salawu/CLOUDTUPLE/platforms/neo4j-gcp-v2/ping-operator/ping-operator-env/lib/python3.11/site-packages/kopf/_core/reactor/running.py:179: FutureWarning: Absence of either namespaces or cluster-wide flag will become an error soon. For now, switching to the cluster-wide mode for backward compatibility.
#   warnings.warn("Absence of either namespaces or cluster-wide flag will become an error soon."
# [2024-11-07 12:39:57,029] kopf._core.engines.a [INFO    ] Initial authentication has been initiated.
# [2024-11-07 12:39:57,054] kopf.activities.auth [INFO    ] Activity 'login_via_client' succeeded.
# [2024-11-07 12:39:57,055] kopf._core.engines.a [INFO    ] Initial authentication has finished.
# [2024-11-07 12:40:07,282] kopf.objects         [INFO    ] [default/test-ping] Handler 'on_create_pingresource' succeeded.
# [2024-11-07 12:40:07,283] kopf.objects         [INFO    ] [default/test-ping] Creation is processed: 1 succeeded; 0 failed.

# open another terminal and run

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

# Step 3: Deploy to GKE
#---------------------------------------

gcloud artifacts repositories create ping-operator-repo \
--project=$project \
--repository-format=docker \
--location=$location \
--description="Repository for Ping Operator"

gcloud auth configure-docker europe-west2-docker.pkg.dev
docker build -t ping-operator:latest .
docker tag ping-operator:latest europe-west2-docker.pkg.dev/prj-p-core-rest-svc-auto-911f/ping-operator-repo/ping-operator:latest
docker push europe-west2-docker.pkg.dev/prj-p-core-rest-svc-auto-911f/ping-operator-repo/ping-operator:latest
kubectl apply -f ping-operator-deployment.yaml
kubectl apply -f pingresource-sample.yaml


# Create client API
#---------------------------------------

pip install fastapi kubernetes uvicorn
# create ping_api.py
uvicorn ping_api:app --reload --host 0.0.0.0 --port 8000
# in another terminal
curl -X POST "http://127.0.0.1:8000/api/create_ping" -H "Content-Type: application/json" -d '{"name": "test-ping", "message": "Hello from FastAPI"}'

# {"status":"success","name":"test-ping"}ping-operator$
ping-operator$ kubectl get pingresource
NAME        AGE
test-ping   37s
ping-operator$
