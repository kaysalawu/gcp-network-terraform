
# Lab: G4 Neo4j GCP Client <!-- omit from toc -->

Contents- [Overview](#overview)
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Deploy the Lab](#deploy-the-lab)
- [Initial Configuration](#initial-configuration)
- [Troubleshooting](#troubleshooting)
  - [1. Configuration and Testing](#1-configuration-and-testing)
- [Cleanup](#cleanup)
- [Requirements](#requirements)
- [Inputs](#inputs)
- [Outputs](#outputs)


## Overview

This lab deploys a simple GCP VPC with a VM installed with neo4j client for testing connectivity to Neo4j databases.

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
cd gcp-network-terraform/4-general/g4-neo4j-auradb-client
```

3\. Run the following terraform commands and type ***yes*** at the prompt:

 ```sh
 terraform init
 terraform plan
 terraform apply -auto-approve
 ```

 ## Initial Configuration

1\. Set the project environment variable:

Example:

```sh
export TF_VAR_project_id_hub=<my-project-id>
```

2\. Set the neo4j environment variables:

Example:

```sh
export TF_VAR_neo4j_db_uri=<neo4j+s://your-db-host.databases.neo4j.io>
export TF_VAR_neo4j_db_username="neo4j"
export TF_VAR_neo4j_db_password="Password123"
```

3\. Run the following terraform commands and type ***yes*** at the prompt:

```sh
terraform init
terraform plan
terraform apply -parallelism=50 -auto-approve
```

## Troubleshooting

See the [troubleshooting](../../troubleshooting/README.md) section for tips on how to resolve common issues that may occur during the deployment of the lab.


### 1. Configuration and Testing

**1.1** Login to the instance `g4-hub-eu-vm` using the [SSH-in-Browser](https://cloud.google.com/compute/docs/ssh-in-browser) from the Google Cloud console.

**1.2** Navigate to the pre-installed neo4j directory.

```sh
sudo su && cd /var/lib/gcp/neo4j/
ls -la
```

<details>

<summary>Sample output</summary>

```sh
# ls -la
total 32
drwxr-xr-x 3 root root 4096 Jan 14 16:51 .
drwxr-xr-x 4 root root 4096 Jan 14 16:50 ..
-rwxr--r-- 1 root root  124 Jan 14 16:50 Dockerfile
-rwxr--r-- 1 root root 1378 Jan 14 16:50 client.py
-rwxr--r-- 1 root root  112 Jan 14 16:50 devenv.txt
drwxr-xr-x 5 root root 4096 Jan 14 16:51 env
-rwxr--r-- 1 root root 2588 Jan 14 16:50 query.py
-rwxr--r-- 1 root root   35 Jan 14 16:50 requirements.txt
```

</details>
<p>

**1.3** Activate the python virtual environment **env**.

```sh
source env/bin/activate
```

**1.4** Install the required python packages.

```sh
pip install -r requirements.txt
```

**1.5** Run the `client.py` script to test connection to the database.

```sh
python3 client.py devenv.txt
```

The client should successfully connect to the Neo4j database.

<img src="./images/db-connection.png" alt="Database Connection" width="700">

## Cleanup

1\. (Optional) Navigate back to the lab directory (if you are not already there).

```sh
cd gcp-network-terraform/4-general/g4-neo4j-auradb-client
```

2\. Run terraform destroy.

```sh
terraform destroy -auto-approve
```

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Inputs

| Name                                                                              | Description                   | Type     | Default | Required |
| --------------------------------------------------------------------------------- | ----------------------------- | -------- | ------- | :------: |
| <a name="input_folder_id"></a> [folder\_id](#input\_folder\_id)                   | folder id                     | `any`    | `null`  |    no    |
| <a name="input_organization_id"></a> [organization\_id](#input\_organization\_id) | organization id               | `any`    | `null`  |    no    |
| <a name="input_prefix"></a> [prefix](#input\_prefix)                              | prefix used for all resources | `string` | `"g4"`  |    no    |
| <a name="input_project_id_hub"></a> [project\_id\_hub](#input\_project\_id\_hub)  | hub project id                | `any`    | n/a     |   yes    |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
