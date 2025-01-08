
# Simple Kubernetes Operator Customer Resource and Operator <!-- omit from toc -->

Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Deploy the Lab](#deploy-the-lab)
- [Troubleshooting](#troubleshooting)
- [Initial Setup](#initial-setup)
- [(Optional) Testing the Operator (locally)](#optional-testing-the-operator-locally)
- [Testing the Operator (GKE)](#testing-the-operator-gke)


## Overview

This lab deploys a GKE cluster and a simple Kubernetes Operator that watches for a custom resource and prints a message to the logs when the custom resource is created.

## Prerequisites

1. Ensure you meet all requirements in the [prerequisites](../../prerequisites/README.md) before proceeding.
2. [Install skaffold](https://skaffold.dev/docs/install/) for deploying the operator to the GKE cluster.

## Deploy the Lab

1\. Clone the Git Repository for the Labs

 ```sh
 git clone https://github.com/kaysalawu/gcp-network-terraform.git
 ```

2\. Navigate to the lab directory

```sh
cd gcp-network-terraform/4-general/g1-k8s-custom-resource
```

3\. Run the following terraform commands and type ***yes*** at the prompt:

 ```sh
 terraform init
 terraform plan
 terraform apply -parallelism=50
 ```

 ## Troubleshooting

See the [troubleshooting](../../troubleshooting/README.md) section for tips on how to resolve common issues that may occur during the deployment of the lab.


## Initial Setup

1\. Set some environment variables

```sh
PROJECT_ID=<your-project-id>
LOCATION=europe-west2
CLUSTER_NAME=g1-hub-cluster
APP_PATH=artifacts/ping/app
MANIFESTS_PATH=artifacts/ping/manifests/kustomize/base
DOCKERFILE_PING_OPERATOR_PATH=Dockerfile-ping-operator
DOCKERFILE_CONTROL_PLANE_PATH=Dockerfile-control-plane
```

2\. Get the GKE cluster credentials

```sh
gcloud container clusters get-credentials $CLUSTER_NAME --region "$LOCATION-b" --project=$PROJECT_ID
```

3\. Create the python virtual environment

```sh
cd $APP_PATH
python3 -m venv ping-venv
source ping-venv/bin/activate
pip install kopf fastapi kubernetes uvicorn
pip freeze > requirements.txt
```

## (Optional) Testing the Operator (locally)

1\. Create the PingResource Custom Resource Definition (CRD)

```sh
cd ../manifests/kustomize/base
kubectl apply -f pingresource-crd.yaml
```

2\. Confirm the CRD is created

```sh
kubectl get crd pingresources.example.com
```

Sample Output:

```sh
(ping-venv) base$ kubectl get crd pingresources.example.com
NAME                        CREATED AT
pingresources.example.com   2025-01-08T06:56:17Z
(ping-venv) base$
```

3\. Run the operator locally

```sh
cd ../../../app/operator/
kopf run ping_operator-local.py
```

<details>

<summary>Sample output</summary>

```sh
(ping-venv) operator$ kopf run ping_operator-local.py
/home/salawu/GCP/gcp-network-terraform/4-general/g1-k8s-custom-resource/artifacts/ping/app/ping-venv/lib/python3.11/site-packages/kopf/_core/reactor/running.py:179: FutureWarning: Absence of either namespaces or cluster-wide flag will become an error soon. For now, switching to the cluster-wide mode for backward compatibility.
  warnings.warn("Absence of either namespaces or cluster-wide flag will become an error soon."
[2025-01-08 07:05:26,490] kopf._core.engines.a [INFO    ] Initial authentication has been initiated.
[2025-01-08 07:05:26,515] kopf.activities.auth [INFO    ] Activity 'login_via_client' succeeded.
[2025-01-08 07:05:26,515] kopf._core.engines.a [INFO    ] Initial authentication has finished.
```

</details>
<p>

4\. In a new terminal in the same directory, create a PingResource custom resource

```sh
kubectl apply -f ../../manifests/kustomize/base/pingresource-sample.yaml
```

5\. Confirm the custom resource is created

```sh
kubectl get pingresource test-ping -o yaml
```

<details>

<summary>Sample output</summary>

```sh
operator$ kubectl get pingresource test-ping -o yaml
apiVersion: example.com/v1
kind: PingResource
metadata:
  annotations:
    kopf.zalando.org/last-handled-configuration: |
      {"spec":{"message":"Ping"}}
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"example.com/v1","kind":"PingResource","metadata":{"annotations":{},"name":"test-ping","namespace":"default"},"spec":{"message":"Ping"}}
  creationTimestamp: "2025-01-08T07:06:19Z"
  finalizers:
  - kopf.zalando.org/KopfFinalizerMarker
  generation: 2
  name: test-ping
  namespace: default
  resourceVersion: "122393"
  uid: 18a5fe69-5e64-45a0-ae1c-dbb7e64f19fd
spec:
  message: Ping
status:
  response: Ping - Pong
```

</details>
<p  >

We can see that the message is `ping` and the response is `ping - pong` which is the expected output.

😎 For the fun of it, let's create an almost useless control plane that watches the custom resource and prints a message when a custom resource is created or deleted.


6\. In the current (second) terminal, run the control plane locally

```sh
cd ../control-plane/
source ../ping-venv/bin/activate
python -m uvicorn control_plane-local:app --reload --host 0.0.0.0 --port 9000
```

<details>

<summary>Sample output</summary>

```sh
(ping-venv) control-plane$ python -m uvicorn control_plane-local:app --reload --host 0.0.0.0 --port 9000
INFO:     Will watch for changes in these directories: ['/home/salawu/GCP/gcp-network-terraform/4-general/g1-k8s-custom-resource/artifacts/ping/app/control-plane']
INFO:     Uvicorn running on http://0.0.0.0:9000 (Press CTRL+C to quit)
INFO:     Started reloader process [73643] using statreload
Started monitoring PingResource events...
INFO:     Started server process [73645]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
Resource test-ping added.
```

</details>
<p>

7\. In a new (third) terminal, check the control plane for CRD events

```sh
curl -X GET "http://127.0.0.1:9000/resources" -H "Content-Type: application/json"
```

Sample Output:

```json
{"resources":{"test-ping":"created"}}
```

In step 4, we created the custom resource using **kubectl**. We will now create the custom resource programatically using an API server implemented in FastAPI.

8\. In a new (fourth) terminal, run the API server

```sh
cd ../api-server/
source ../ping-venv/bin/activate
python -m uvicorn ping_api:app --reload --host 0.0.0.0 --port 8000
```

<details>

<summary>Sample output</summary>

```sh
(ping-venv) api-server$ python -m uvicorn ping_api-local:app --reload --host 0.0.0.0 --port 8000
INFO:     Will watch for changes in these directories: ['/home/salawu/GCP/gcp-network-terraform/4-general/g1-k8s-custom-resource/artifacts/ping/app/api-server']
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
INFO:     Started reloader process [74140] using statreload
INFO:     Started server process [74142]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
```

</details>
<p>

9\. Back in the third terminal, run various tests on the API endpoint and verify that the control plane receives the events

- 9.1 Create `test-ping1` resource

   ```sh
   curl -X POST "http://127.0.0.1:8000/api/create_ping" -H "Content-Type: application/json" -d '{"name": "test-ping1", "message": "Hello from FastAPI"}'
   curl -X GET "http://127.0.0.1:9000/resources" -H "Content-Type: application/json"
   ```

  Sample output

  ```json
  {"status":"success","name":"test-ping1"}
  {"resources":{"test-ping":"created","test-ping1":"created"}}
  ```

  We can see that the API server returned **success** for teh creation of test-ping1 resource and teh control plane registered the event.

- 9.2 Add `test-ping2` resource

  ```sh
  curl -X POST "http://127.0.0.1:8000/api/create_ping" -H "Content-Type: application/json" -d '{"name": "test-ping2", "message": "Hello from FastAPI"}'
  curl -X GET "http://127.0.0.1:9000/resources" -H "Content-Type: application/json"
  ```

  Sample output

  ```json
  {"status":"success","name":"test-ping2"}
  {"resources":{"test-ping":"created","test-ping1":"created","test-ping2":"created"}}
  ```

- 9.3 Use kubectl to verify the custom resources

  ```sh
  kubectl get pingresources
  ```

  Sample output

  ```sh
  python$ kubectl get pingresources
  NAME         AGE
  test-ping    37m
  test-ping1   9m
  test-ping2   4m5s
  ```

- 9.4 Delete `test-ping1` resource using kubectl and verify control plane events

  ```sh
  kubectl delete pingresource test-ping2
  curl -X GET "http://127.0.0.1:9000/resources" -H "Content-Type: application/json"
  ```

  Sample output

  ```json
  pingresource.example.com "test-ping2" deleted
  {"resources":{"test-ping":"created","test-ping1":"created"}}
  ```

- 9.5 Delete `test-ping1` resource using the API server and verify control plane events

  ```sh
  curl -X DELETE "http://127.0.0.1:8000/api/delete_ping/test-ping1"
  curl -X GET "http://127.0.0.1:9000/resources" -H "Content-Type: application/json"
  ```

  Sample output

  ```json
  {"status":"success","message":"Resource test-ping1 deleted"}
  {"resources":{"test-ping":"created"}}
  ```

  We have successfully tested the operator locally.

10\.   Navigate to the `artifacts/ping/manifests` directory and delete the `test-ping` custom resource

  ```sh
  cd ../../manifests/kustomize/base/
  kubectl delete -f pingresource-sample.yaml
  kubectl delete -f pingresource-crd.yaml
  ```

11\.   Stop the control plane and API server by pressing `Ctrl+C` in the respective terminals.

## Testing the Operator (GKE)


<!-- BEGIN_TF_DOCS -->

<!-- END_TF_DOCS -->
