
# Prerequisites

> **⚠️ NOTE:**
> The labs require that you have a GCP organization and create five projects. An organization and multiple projects are required to deploy Shared VPC.


## 1. Using Cloud Shell Bash (Option 1)

**1.1** [Launch a Cloud Shell session](https://cloud.google.com/shell/docs/launching-cloud-shell) from the Google Cloud console. Click ![Activate Cloud Shell](../images/general/cloud-shell-button.png) Activate Cloud Shell in the Google Cloud console. This launches a session in the bottom pane of Google Cloud console.

**1.2** (Optional) Verify the linux version of the Cloud Shell by running the following command:

```sh
lsb_release -a
```

Sample output:

```sh
$ lsb_release -a
No LSB modules are available.
Distributor ID: Ubuntu
Description:    Ubuntu 22.04.4 LTS
Release:        22.04
Codename:       jammy
```

**1.3** Verify the Terraform version by running the following command:

```sh
terraform version
```

Sample output:

```sh
salawu@cloudshell:~ (prj-onprem-x)$ terraform version
Terraform v1.5.7
on linux_amd64

Your version of Terraform is out of date! The latest version
is 1.9.3. You can update by downloading from https://www.terraform.io/downloads.html
```

**1.4** (Optional) If your terraform version is not at least 1.7.4, update it by running the following command:

```sh
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install terraform
```

**1.5** Confirm that the Terraform version is updated by running the following command:

```sh
$ terraform version
Terraform v1.9.4
on linux_amd64
```

## 2. Using Local Linux Machine (Option 2)

To use a local Linux machine, do the following:

**2.1** Ensure that you have installed and configured [Google Cloud SDK](https://cloud.google.com/sdk/docs/install#linux) using the installation guide for your operating system.

**2.2** Ensure that you have installed [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) version 1.7.4 or later.

## 3. Remaining Steps

**3.1** Export your project IDs to the following terraform variables:

```sh
export TF_VAR_project_id_onprem=[YOUR_ONPREM_PROJECT_ID]
export TF_VAR_project_id_hub=[YOUR_HUB_PROJECT_ID]
export TF_VAR_project_id_host=[YOUR_HOST_PROJECT_ID]
export TF_VAR_project_id_spoke1=[YOUR_SPOKE1_PROJECT_ID]
export TF_VAR_project_id_spoke2=[YOUR_SPOKE2_PROJECT_ID]
```

**3.2** Authenticate your gcloud client

**Option 1 (using Application Default Credentials)**

To authenticate using [Application Default Credentials (ADC)](https://cloud.google.com/docs/authentication/application-default-credentials) run the following command

```sh
gcloud auth application-default login
```

Proceed to **step 3.3**.

**Option 2 (using Service Account)**

Authenticate using a service account by setting the applications credentials variable GOOGLE_APPLICATION_CREDENTIALS and setting gcloud authentication to use the service account.

```sh
export GOOGLE_APPLICATION_CREDENTIALS=${KEY_FILE_PATH}
gcloud auth activate-service-account --key-file=${KEY_FILE_PATH}
```

Proceed to **step 3.3**.


**3.3** Run the following commands to enable the required APIs and services used in the lab:

```sh
gcloud services enable compute.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable dns.googleapis.com
gcloud services enable networkconnectivity.googleapis.com
gcloud services enable servicenetworking.googleapis.com
gcloud services enable servicedirectory.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable networkmanagement.googleapis.com
gcloud services enable firewallinsights.googleapis.com
gcloud services enable container.googleapis.com
```


