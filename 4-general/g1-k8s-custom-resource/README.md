
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

Ensure you meet all requirements in the [prerequisites](../../prerequisites/README.md) before proceeding.

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

1. Set some environment variables

```sh
PROJECT_ID=<your-project-id>
LOCATION=europe-west2
CLUSTER_NAME=g1-hub-cluster
APP_PATH=artifacts/ping/app
MANIFESTS_PATH=artifacts/ping/manifests
DOCKERFILE_PING_OPERATOR_PATH=Dockerfile-ping-operator
DOCKERFILE_CONTROL_PLANE_PATH=Dockerfile-control-plane
CURRENT_DIR=$(pwd)
```

2. Get the GKE cluster credentials

```sh
gcloud container clusters get-credentials $CLUSTER_NAME --region "$LOCATION-b" --project=$PROJECT_ID
```

## (Optional) Testing the Operator (locally)

1. Create the PingResource Custom Resource Definition (CRD)

```sh
cd $APP_PATH

## Testing the Operator (GKE)


<!-- BEGIN_TF_DOCS -->

<!-- END_TF_DOCS -->
