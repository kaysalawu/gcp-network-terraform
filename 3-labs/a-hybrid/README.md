# LAB A: Simple Hybrid Connectivity <!-- omit from toc -->

Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Deploy the Lab](#deploy-the-lab)
- [Troubleshooting](#troubleshooting)
- [Outputs](#outputs)
- [Testing](#testing)
  - [1. Test Site1 (On-premises)](#1-test-site1-on-premises)
- [Cleanup](#cleanup)
- [Requirements](#requirements)
- [Inputs](#inputs)
- [Outputs](#outputs-1)

## Overview

In this lab:

* A hub VPC network with simple hybrid connectivity to two on-premises sites.
* All north-south and east-west traffic are allowed via VPC firewall rules.
* Hybrid connectivity to simulated on-premises sites is achieved using HA VPN.
* Network Connectivity Center (NCC) is used to connect the on-premises sites together via the external Hub VPC.
* Other networking features such as Cloud DNS, PSC for Google APIs and load balancers are also deployed in this lab.

<img src="./image.png" alt="Simple Hybrid Connectivity" width="550">

## Prerequisites

Ensure you meet all requirements in the [prerequisites](../../prerequisites/README.md) before proceeding.

## Deploy the Lab

1\. Clone the Git Repository for the Labs

 ```sh
 git clone https://github.com/kaysalawu/gcp-network-terraform.git
 ```

2\. Navigate to the lab directory

```sh
cd gcp-network-terraform/1-blueprints-nextgen/f-simple-hybrid
```

3\. (Optional) If you want to enable additional features such as IPv6, VPC flow logs and logging set the following variables to `true` in the [`01-main.tf`](./01-main.tf) file.

 | Variable    | Description                            | Default | Link                        |
 | ----------- | -------------------------------------- | ------- | --------------------------- |
 | enable_ipv6 | Enable IPv6 on all supported resources | false   | [main.tf](./01-main.tf#L19) |
 |             |                                        |         |

4\. Run the following terraform commands and type ***yes*** at the prompt:

 ```sh
 terraform init
 terraform plan
 terraform apply -parallelism=50
 ```

5\. (Optional) Deploy a firewall endpoint in the hub VPC in zone europe-west2-b to match `region1` set in the [00-config](./00-config.tf#L26) file.

```sh
export prefix=a
export zone=europe-west2-b

gcloud network-security firewall-endpoints create "$prefix-fwe-$zone" \
--zone=$zone \
--organization=$TF_VAR_organization_id \
--billing-project=$TF_VAR_project_id_hub

gcloud network-security firewall-endpoints list --zone=$zone --organization=$TF_VAR_organization_id
```

Sample output:

```sh
a-standard$ gcloud network-security firewall-endpoints list --zone=$zone --organization=$TF_VAR_organization_id
ID                    LOCATION        STATE
a-fwe-europe-west2-b  europe-west2-b  CREATING
```

Wait until the firewall endpoint is created and the state changes to `ACTIVE` before proceeding to the next step.

6\. (Optional) When firewall endpoint is active, associate the endpoint with the hub VPC network.

```sh
export prefix=a
export zone=europe-west2-b
gcloud network-security firewall-endpoint-associations create $prefix-fwe-association \
--project=$TF_VAR_project_id_hub \
--zone $zone \
--network=projects/$TF_VAR_project_id_hub/global/networks/$prefix-hub-vpc \
--endpoint="$prefix-fwe-$zone" \
--organization=$TF_VAR_organization_id

gcloud network-security firewall-endpoint-associations list --project $TF_VAR_project_id_hub --zone=$zone
```

Sample output:

```sh
examples$ gcloud network-security firewall-endpoint-associations list --project $TF_VAR_project_id_hub --zone=$zone
ID                 LOCATION        NETWORK    ENDPOINT              STATE
a-fwe-association  europe-west2-b  a-hub-vpc  a-fwe-europe-west2-b  CREATING
```

Waiti a few minutes for the state to change from `CREATING` to `ACTIVE`.

## Troubleshooting

See the [troubleshooting](../../troubleshooting/README.md) section for tips on how to resolve common issues that may occur during the deployment of the lab.

## Outputs

The table below shows the auto-generated output files from the lab. They are located in the `_output` directory.

| Item              | Description                           | Location                                               |
| ----------------- | ------------------------------------- | ------------------------------------------------------ |
| Hub Unbound DNS   | Unbound DNS configuration             | [_output/hub-unbound.sh](./_output/hub-unbound.sh)     |
| Site1 Unbound DNS | Unbound DNS configuration             | [_output/site1-unbound.sh](./_output/site1-unbound.sh) |
| Site2 Unbound DNS | Unbound DNS configuration             | [_output/site2-unbound.sh](./_output/site2-unbound.sh) |
| Site1 Router      | VyOS router configuration             | [_output/site1-router.sh](./_output/site1-router.sh)   |
| Site2 Router      | VyOS router configuration             | [_output/site2-router.sh](./_output/site2-router.sh)   |
| Web server        | Python Flask web server, test scripts | [_output/vm-startup.sh](./_output/vm-startup.sh)       |
|                   |                                       |                                                        |

## Testing

Each virtual machine (VM) is pre-configured with a shell [script](../../scripts/server.sh) to run various types of network reachability tests. Serial console access has been configured for all virtual machines. In each VM instance, The pre-configured test script `/usr/local/bin/playz` can be run from the SSH terminal to test network reachability.

The full list of the scripts in each VM instance is shown below:

```sh
$ ls -l /usr/local/bin/
-rwxr-xr-x 1 root root   98 Aug 17 14:58 aiz
-rwxr-xr-x 1 root root  203 Aug 17 14:58 bucketz
-rw-r--r-- 1 root root 1383 Aug 17 14:58 discoverz.py
-rwxr-xr-x 1 root root 1692 Aug 17 14:58 pingz
-rwxr-xr-x 1 root root 5986 Aug 17 14:58 playz
-rwxr-xr-x 1 root root 1957 Aug 17 14:58 probez
```
* **[bucketz](./_output/vm-startup.sh#L119)** - Test access to selected Google Cloud Storage buckets
* **[discoverz.py](../../scripts/startup/discoverz.py)** - HTTP test to all google API endpoints
* **[pingz](./_output/vm-startup.sh#L97)** - ICMP reachability test to all VM instances
* **[playz](./_output/vm-startup.sh#L57)** - HTTP (curl) test to all VM instances
* **[probez](./_output/vm-startup.sh#L183)** - Run benchmark tests to selected VM instances

### 1. Test Site1 (On-premises)

**1.1** Login to the instance `f-site1-vm` using the [SSH-in-Browser](https://cloud.google.com/compute/docs/ssh-in-browser) from the Google Cloud console.

**1.2** Run the `playz` script to test network reachability to all VM instances.

```sh
playz
```

<details>

<summary>Sample output</summary>

```sh
admin_cloudtuple_com@f-site1-vm:~$ playz

 apps ...

200 (0.009522s) - 10.10.1.9 - vm.site1.onprem:8080/
200 (0.303636s) - 10.20.1.9 - vm.site2.onprem:8080/
200 (0.011211s) - 10.1.11.70 - ilb4.eu.hub.gcp:8080/
200 (0.292074s) - 10.1.21.70 - ilb4.us.hub.gcp:8080/
200 (0.034366s) - 10.1.11.80 - ilb7.eu.hub.gcp/
000 (2.001923s) -  - ilb7.us.hub.gcp/

 psc4 ...


 apis ...

204 (0.002668s) - 216.58.204.74 - www.googleapis.com/generate_204
204 (0.007402s) - 10.1.0.1 - storage.googleapis.com/generate_204
204 (0.037531s) - 10.1.11.80 - europe-west2-run.googleapis.com/generate_204
000 (2.002903s) -  - us-west2-run.googleapis.com/generate_204
200 (0.039866s) - 10.1.0.1 - https://f-hub-us-run-httpbin-i6ankopyoa-nw.a.run.app/
204 (0.008114s) - 10.1.0.1 - fhuball.p.googleapis.com/generate_204
```

</details>
<p>

**1.3** Run the `pingz` script to test ICMP reachability to all VM instances.

```sh
pingz
```

<details>

<summary>Sample output</summary>

```sh
admin_cloudtuple_com@f-site1-vm:~$ pingz

 ping ...

vm.site1.onprem - OK 0.026 ms
vm.site2.onprem - OK 139.202 ms
ilb4.eu.hub.gcp - NA
ilb4.us.hub.gcp - NA
ilb7.eu.hub.gcp - NA
ilb7.us.hub.gcp - NA
```

</details>
<p>

**1.4** Run the `bucketz` script to test access to selected Google Cloud Storage buckets.

```sh
bucketz
```

<details>

<summary>Sample output</summary>

```sh
admin_cloudtuple_com@f-site1-vm:~$ bucketz

hub : <--- HUB EU --->
```

</details>
<p>

**1.5** On your local terminal or Cloud Shell, run the `discoverz.py` script to test access to all Google API endpoints.

```sh
gcloud compute ssh f-site1-vm \
--project $TF_VAR_project_id_onprem \
--zone europe-west2-b \
-- 'python3 /usr/local/bin/discoverz.py' | tee  _output/site1-api-discovery.txt
```

The script save the output to the file [_output/site1-vm-api-discoverz.sh`](./_output/site1-api-discovery.txt).

## Cleanup

1\. (Optional) Navigate back to the lab directory (if you are not already there).

```sh
cd gcp-network-terraform/1-blueprints-nextgen/f-simple-hybrid
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
| <a name="input_prefix"></a> [prefix](#input\_prefix) | prefix used for all resources | `string` | `"a"` | no |
| <a name="input_project_id_host"></a> [project\_id\_host](#input\_project\_id\_host) | host project id | `any` | n/a | yes |
| <a name="input_project_id_hub"></a> [project\_id\_hub](#input\_project\_id\_hub) | hub project id | `any` | n/a | yes |
| <a name="input_project_id_onprem"></a> [project\_id\_onprem](#input\_project\_id\_onprem) | onprem project id (for onprem site1 and site2) | `any` | n/a | yes |
| <a name="input_project_id_spoke1"></a> [project\_id\_spoke1](#input\_project\_id\_spoke1) | spoke1 project id (service project id attached to the host project | `any` | n/a | yes |
| <a name="input_project_id_spoke2"></a> [project\_id\_spoke2](#input\_project\_id\_spoke2) | spoke2 project id (standalone project) | `any` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
