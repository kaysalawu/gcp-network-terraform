
# Simple Kubernetes Customer Resource and Operator <!-- omit from toc -->

Contents
- [1. Overview](#1-overview)
- [2. Prerequisites](#2-prerequisites)
- [3. Deploy the Lab](#3-deploy-the-lab)
- [4. Troubleshooting](#4-troubleshooting)
- [5. Initial Setup](#5-initial-setup)
- [Testing the Operator (GKE)](#testing-the-operator-gke)
- [Cleanup](#cleanup)
- [Useful Commands](#useful-commands)
- [Requirements](#requirements)
- [Inputs](#inputs)
- [Outputs](#outputs)


## 1. Overview

This lab deploys a GKE cluster and a simple Kubernetes Operator that watches for a custom resource and prints a message to the logs when the custom resource is created.

<img src="images/image.png" alt="FastAPI Web Interface" width="600"/>

## 2. Prerequisites

1. Ensure you meet all requirements in the [prerequisites](../../prerequisites/README.md) before proceeding.
2. [Install skaffold](https://skaffold.dev/docs/install/) for deploying the operator to the GKE cluster.

## 3. Deploy the Lab

3. Clone the Git Repository for the Labs

    ```sh
    git clone https://github.com/kaysalawu/gcp-network-terraform.git
    ```

4. Navigate to the lab directory

   ```sh
   cd gcp-network-terraform/4-general/g1-k8s-custom-resource
   ```

5. Deploy the terraform configuration:

    ```sh
    terraform init
    terraform plan
    terraform apply -auto-approve
    ```

## 4. Troubleshooting

See the [troubleshooting](../../troubleshooting/README.md) section for tips on how to resolve common issues that may occur during the deployment of the lab.


## 5. Initial Setup

1. Set some environment variables

   ```sh
   export TF_VAR_project_id_hub=<PLACEHOLDER_FOR_TF_VAR_project_id_hub>
   export LOCATION=europe-west2
   export CLUSTER_NAME=g1-hub-eu-cluster
   ```

2. Get the GKE cluster credentials

   ```sh
   gcloud container clusters get-credentials $CLUSTER_NAME --region="$LOCATION-b" --project=$TF_VAR_project_id_hub
   ```

3. Replace all occurences of project IDs in the manifests with the environment variables.

   ```sh
   for i in $(find artifacts -name '*.yaml'); do sed -i'' -e "s/YOUR_PROJECT_ID/${TF_VAR_project_id_hub}/g" "$i"; done
   ```

4. Create the python virtual environment

   ```sh
   cd artifacts/ping/app && \
   python3 -m venv ping-venv && \
   source ping-venv/bin/activate && \
   pip install kopf fastapi kubernetes uvicorn && \
   pip freeze > requirements.txt
   ```

## Testing the Operator (GKE)

1. Deploy the operator, control plane and API server using skaffold

   ```sh
   cd artifacts
   skaffold run
   ```

2. Confirm the operator is running

   ```sh
   kubectl get pods
   ```

   Sample output

   ```sh
   artifacts$ kubectl get pods
   NAME                             READY   STATUS    RESTARTS   AGE
   api-server-5ff4d7b6cb-7ndh8      1/1     Running   0          56s
   control-plane-6b98d95f97-s64rt   1/1     Running   0          56s
   ping-operator-64fcffb9d8-2sdv4   1/1     Running   0          56s
   ```

3. Confirm the CRD is created

   ```sh
   kubectl get crd pingresources.example.com
   ```

   Sample output

   ```sh
   artifacts$ kubectl get crd pingresources.example.com
   NAME                        CREATED AT
   pingresources.example.com   2025-01-08T08:45:51Z
   ```

4. Confirm the load balancer IP addresses

   ```sh
   kubectl get svc
   ```

   Sample output

   ```sh
   artifacts$ kubectl get svc
   NAME                 TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)        AGE
   api-server-elb       LoadBalancer   10.1.102.123   34.142.15.176    80:30889/TCP   76m
   api-server-service   ClusterIP      10.1.102.125   <none>           8080/TCP       99m
   control-plane        ClusterIP      10.1.102.32    <none>           9000/TCP       70m
   control-plane-elb    LoadBalancer   10.1.102.176   35.197.246.167   80:30298/TCP   74m
   kubernetes           ClusterIP      10.1.102.1     <none>           443/TCP        6h26m
   ```

5. Extract the external IP addresses and create `test-ping1` resource

   ```sh
   API_SERVER_IP=$(kubectl get svc api-server-elb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
   curl -X POST "http://$API_SERVER_IP/api/create_ping" -H "Content-Type: application/json" -d '{"name": "test-ping1", "message": "Hello from FastAPI"}'
   ```

   Sample output

   ```json
   {"status":"success","name":"test-ping1"}
   ```

6. Confirm the control plane events

   ```sh
   CONTROL_PLANE_IP=$(kubectl get svc control-plane-elb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
   curl -X GET "http://$CONTROL_PLANE_IP/resources" -H "Content-Type: application/json"
   ```

   Sample output

   ```json
   {"resources":{"test-ping1":"created"}}
   ```

7. Create `test-ping2` resource

   ```sh
   curl -X POST "http://$API_SERVER_IP/api/create_ping" \
   -H "Content-Type: application/json" \
   -d '{"name": "test-ping2", "message": "Hello from FastAPI"}'
   ```

   Sample output

   ```json
   {"status":"success","name":"test-ping2"}
   ```

8. (Optional) Test API server using FastApi web interface

   Go to `http://$API_SERVER_IP/docs` in your browser and test the API server.

   <img src="images/fastapi-api-server.png" alt="FastAPI Web Interface" width="800"/>

9. (Optional) Test control plane using FastApi web interface

   Go to `http://$CONTROL_PLANE_IP/docs` in your browser and test the control plane.

   <img src="images/fastapi-control-plane.png" alt="FastAPI Web Interface" width="800"/>

10. Delete the resources

    ```sh
    curl -X DELETE "http://$API_SERVER_IP/api/delete_ping/test-ping1"
    curl -X DELETE "http://$API_SERVER_IP/api/delete_ping/test-ping2"
    skaffold delete
    ```

## Cleanup

1. (Optional) Navigate back to the lab directory (if you are not already there).

   ```sh
   cd gcp-network-terraform/4-general/g1-k8s-custom-resource
   ```

2. Run terraform destroy.

   ```sh
   terraform destroy -auto-approve
   ```

## Useful Commands

1. Force delete PingResource custom resource

   ```sh
   kubectl patch pingresource test-ping1 -p '{"metadata":{"finalizers":[]}}' --type=merge
   ```

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_folder_id"></a> [folder\_id](#input\_folder\_id) | folder id | `any` | `null` | no |
| <a name="input_organization_id"></a> [organization\_id](#input\_organization\_id) | organization id | `any` | `null` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | prefix used for all resources | `string` | `"g1"` | no |
| <a name="input_project_id_hub"></a> [project\_id\_hub](#input\_project\_id\_hub) | hub project id | `any` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
