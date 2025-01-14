
# Lab: G3 GCP Private Service Connect for Neo4j AuraDB <!-- omit from toc -->

Contents- [Overview](#overview)
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Deploy the Lab](#deploy-the-lab)
- [Troubleshooting](#troubleshooting)
  - [1. Configuration and Testing](#1-configuration-and-testing)
- [Cleanup](#cleanup)
- [Requirements](#requirements)
- [Inputs](#inputs)
- [Outputs](#outputs)


## Overview

This lab deploys a simple GCP VPC with a VM installed with neo4j client. The aim is to demonstrate how to use GCP Private Service Connect to connect to a Neo4j AuraDB instance.

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
cd gcp-network-terraform/4-general/g3-neo4j-auradb-psc
```

3\. Run the following terraform commands and type ***yes*** at the prompt:

 ```sh
 terraform init
 terraform plan
 terraform apply -parallelism=50
 ```

 ## Troubleshooting

See the [troubleshooting](../../troubleshooting/README.md) section for tips on how to resolve common issues that may occur during the deployment of the lab.


### 1. Configuration and Testing

**1.1** Login to the instance `g3-hub-eu-vm` using the [SSH-in-Browser](https://cloud.google.com/compute/docs/ssh-in-browser) from the Google Cloud console.

**1.2** Navigate to the pre-installed neo4j directory.

```sh

```

<details>

<summary>Sample output</summary>

```sh

```

</details>
<p>

## Cleanup

1\. (Optional) Navigate back to the lab directory (if you are not already there).

```sh
cd gcp-network-terraform/4-general/g3-neo4j-auradb-psc
```

2\. Run terraform destroy.

```sh
terraform destroy -auto-approve
```

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_folder_id"></a> [folder\_id](#input\_folder\_id) | folder id | `any` | `null` | no |
| <a name="input_organization_id"></a> [organization\_id](#input\_organization\_id) | organization id | `any` | `null` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | prefix used for all resources | `string` | `"g3"` | no |
| <a name="input_project_id_hub"></a> [project\_id\_hub](#input\_project\_id\_hub) | hub project id | `any` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
