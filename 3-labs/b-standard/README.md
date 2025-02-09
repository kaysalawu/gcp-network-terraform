# LAB B: Hybrid Hub and Spoke Connectivity <!-- omit from toc -->

Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Deploy the Lab](#deploy-the-lab)
- [Troubleshooting](#troubleshooting)
- [Outputs](#outputs)
- [Running Tests from VM Instances](#running-tests-from-vm-instances)
- [Site1 (On-premises)](#site1-on-premises)
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
* Networking features such as Cloud DNS, PSC for Google APIs and load balancers are also deployed in this lab.

<img src="./image.png" alt="Simple Hybrid Connectivity" width="1000">

## Prerequisites

Ensure you meet all requirements in the [prerequisites](../../prerequisites/README.md) before proceeding.


## Deploy the Lab

1. Clone the Git Repository for the Labs

    ```sh
    git clone https://github.com/kaysalawu/gcp-network-terraform.git
    ```

2. Navigate to the lab directory

   ```sh
   cd gcp-network-terraform/1-blueprints-nextgen/b-simple-hybrid
   ```

3. (Optional) If you want to enable additional features such as IPv6, VPC flow logs and logging set the following variables to `true` in the [`01-main.tf`](./01-main.tf) file.

    | Variable    | Description                 | Default | Link             |
    | ----------- | -------------------------------------- | ------- | --------------------------- |
    | enable_ipv6 | Enable IPv6 on all supported resources | false   | [main.tf](./01-main.tf#L19) |
    |  |                             |         |

4. Run the following terraform commands and type ***yes*** at the prompt:

    ```sh
    terraform init
    terraform plan
    terraform apply -parallelism=50
    ```

5. (Optional) Deploy a firewall endpoint in the hub VPC in zone europe-west2-b to match `region1` set in the config file - [00-config](./00-config.tf#L25).

   <Details>
   <Summary>🟢 Click to view the steps</Summary>

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

   </Details>
   <p>

6. (Optional) When firewall endpoint is active, associate the endpoint with the hub VPC network.

   <Details>
   <Summary>🟢 Click to view the steps</Summary>

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

   Wait a few minutes for the state to change from `CREATING` to `ACTIVE`.

   </Details>
   <p>

## Troubleshooting

See the [troubleshooting](../../troubleshooting/README.md) section for tips on how to resolve common issues that may occur during the deployment of the lab.

## Outputs

The table below shows the auto-generated output files from the lab. They are located in the `_output` directory.

| Item   | Description                | Location                                    |
| ----------------- | ------------------------------------- | ------------------------------------------------------ |
| Hub Unbound DNS   | Unbound DNS configuration  | [_output/hub-unbound.sh](./_output/hub-unbound.sh)     |
| Site1 Unbound DNS | Unbound DNS configuration  | [_output/site1-unbound.sh](./_output/site1-unbound.sh) |
| Site2 Unbound DNS | Unbound DNS configuration  | [_output/site2-unbound.sh](./_output/site2-unbound.sh) |
| Web server        | Python Flask web server, test scripts | [_output/vm-startup.sh](./_output/startup.sh)       |
|        |                            |                                             |

## Running Tests from VM Instances

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

- **[test-scripts](./_output/startup.sh)** - Test access to selected Google Cloud Storage buckets
- **[discoverz.py](../../scripts/startup/discoverz.py)** - HTTP test to all google API endpoints

## Site1 (On-premises)

1. Login to the instance `b-site1-vm` using the [SSH-in-Browser](https://cloud.google.com/compute/docs/ssh-in-browser) from the Google Cloud console.

2. Run IP ping test

   ```sh
   ping-ipv4
   ```

   Sample output:

   ```sh
   admin_cloudtuple_com@b-site1-vm:~$ ping-ipv4

    ping ipv4 ...

   site1-vm      - 10.10.1.9 -OK 0.066 ms
   hub-eu-vm     - 10.1.11.9 -OK 2.390 ms
   spoke1-eu-vm  - 10.11.11.9 -OK 2.309 ms
   spoke1-eu-ilb - 10.11.11.30 -NA
   site2-vm      - 10.20.1.9 -OK 139.728 ms
   hub-us-vm     - 10.1.21.9 -OK 135.945 ms
   spoke2-us-vm  - 10.22.21.9 -OK 136.640 ms
   spoke2-us-ilb - 10.22.21.30 -OK 137.078 ms
   ```

   The interlan passthrough load balancer `spoke1-eu-ilb` is not reachable because it's forwarding rule is configured for TCP only. The interlan passthrough load balancer `spoke2-us-ilb` is reachable because it's forwarding rule is configured for `L3_DEFAULT` which allows ICMP traffic.


3. Ping DNS for IPv4 addresses

   ```sh
   ping-dns4
   ```

   Sample output:

   ```sh
    ping dns ipv4 ...

   vm.site1.corp - 10.10.1.9 -OK 0.048 ms
   vm.eu.hub.g.corp - 10.1.11.9 -OK 2.659 ms
   vm.eu.spoke1.g.corp - 10.11.11.9 -OK 2.319 ms
   ilb.eu.spoke1.g.corp - 10.11.11.30 -NA
   vm.site2.corp - 10.20.1.9 -OK 139.874 ms
   vm.us.hub.g.corp - 10.1.21.9 -OK 136.853 ms
   vm.us.spoke2.g.corp - 10.22.21.9 -OK 136.541 ms
   ilb.us.spoke2.g.corp - 10.22.21.30 -OK 136.414 ms
   ```

   We have the same results as the IPv4 ping test.

4. Ping DNS for IPv6 addresses

   ```sh
   ping-dns6
   ```

   Sample output:

   ```sh
    ping dns ipv6 ...
   vm.site1.corp - fd20:de2:3ace:4000:: -OK 0.031 ms
   vm.eu.hub.g.corp - fd20:c7b:bc33:4000:: -OK 1.724 ms
   vm.eu.spoke1.g.corp - fd20:a45:2b9:4000:0:1:: -OK 2.428 ms
   ilb.eu.spoke1.g.corp - fd20:a45:2b9:4000:0:3:: -NA
   vm.site2.corp - fd20:f43:cd23:8000:: -NA
   vm.us.hub.g.corp - fd20:c7b:bc33:8000:0:1:: -OK 135.671 ms
   vm.us.spoke2.g.corp - fd20:351:ba55:8000:0:1:: -OK 136.001 ms
   ilb.us.spoke2.g.corp - fd20:351:ba55:8000:0:3:: -OK 136.258 ms
   ```

   We have the same results as the IPv4 tests. In additiona, the IPv6 address for `vm.site2.corp` is not reachable because Network Connectivity Center (NCC) does not yet support IPv6.

5. Ping Curl for IPv4 DNS

   ```sh
   curl-dns4
   ```

   Sample output:

   ```sh
   curl dns ipv4 ...

   200 (0.004087s) - 10.10.1.9 - vm.site1.corp
   200 (0.009381s) - 10.1.11.9 - vm.eu.hub.g.corp
   200 (0.007887s) - 10.11.11.9 - vm.eu.spoke1.g.corp
   200 (0.006949s) - 10.11.11.30 - ilb.eu.spoke1.g.corp
   200 (0.016816s) - 10.11.11.40 - nlb.eu.spoke1.g.corp
   200 (0.016397s) - 10.11.11.50 - alb.eu.spoke1.g.corp
    - ep.eu.spoke1-eu-ilb.spoke2.g.corp
    - ep.eu.spoke1-eu-nlb.spoke2.g.corp
    - ep.eu.spoke1-eu-alb.spoke2.g.corp
   200 (0.278723s) - 10.20.1.9 - vm.site2.corp
   200 (0.278996s) - 10.1.21.9 - vm.us.hub.g.corp
   200 (0.276319s) - 10.22.21.9 - vm.us.spoke2.g.corp
   200 (0.275769s) - 10.22.21.30 - ilb.us.spoke2.g.corp
    - nlb.us.spoke2.g.corp
    - alb.us.spoke2.g.corp
   000 (0.027143s) -  - ilb.geo.hub.g.corp
   200 (0.020094s) - 104.16.184.241 - icanhazip.com
   404 (0.102787s) - 172.217.169.74 - www.googleapis.com
   400 (0.022956s) - 10.1.0.1 - storage.googleapis.com
    - europe-west2-run.googleapis.com
    - us-west2-run.googleapis.com
   403 (0.192085s) - 10.1.0.1 - https://b-hub-us-run-httpbin-wapotrwjpq-nw.a.run.app
   403 (0.177581s) - 10.1.0.1 - https://b-spoke1-eu-run-httpbin-expmorqqnq-nw.a.run.app
   403 (1.007457s) - 10.1.0.1 - https://b-spoke2-us-run-httpbin-4e4skt6nna-wl.a.run.app
   ```

   Result explanation:

   ILB = Internal Network Load Balancer (Pass-through)
   NLB = Internal Network Load Balancer (Proxy)
   ALB = Internal Application Load Balancer (Proxy)

   | Target | Hub VM | Spoke1 VM | Spoke2 VM | ILB | NLB | ALB | Comment |
   |---|---|---|---|---|---|---|---|
   | Target | Hub VM | Spoke1 VM | Spoke2 VM | ILB | NLB | ALB | Comment |


6. Run an authenticated test to the cloud run services

   ```sh
   BEARER_TOKEN=$(gcloud auth print-identity-token) && \
   curl -H "Authorization: Bearer $BEARER_TOKEN" https://b-hub-us-run-httpbin-wapotrwjpq-nw.a.run.app/headers
   curl -H "Authorization: Bearer $BEARER_TOKEN" https://b-spoke1-eu-run-httpbin-expmorqqnq-nw.a.run.app/headers
   curl -H "Authorization: Bearer $BEARER_TOKEN" https://b-spoke2-us-run-httpbin-4e4skt6nna-wl.a.run.app/headers
   ```


7. On your local terminal or Cloud Shell, run the `discoverz.py` script to test access to all Google API endpoints.

   ```sh
   gcloud compute ssh b-site1-vm \
   --project $TF_VAR_project_id_onprem \
   --zone europe-west2-b \
   -- 'python3 /usr/local/bin/discoverz.py' | tee  _output/site1-api-discovery.txt
   ```

   The script output is saved to [_output/site1-vm-api-discoverz.sh`](./_output/site1-api-discovery.txt).

## Cleanup

Let's clean up the resources deployed.

1. (Optional) Navigate back to the lab directory (if you are not already there).

   ```sh
   cd gcp-network-terraform/1-blueprints-nextgen/b-simple-hybrid
   ```

2. Run terraform destroy.

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
| <a name="input_prefix"></a> [prefix](#input\_prefix) | prefix used for all resources | `string` | `"b"` | no |
| <a name="input_project_id_host"></a> [project\_id\_host](#input\_project\_id\_host) | host project id | `any` | n/a | yes |
| <a name="input_project_id_hub"></a> [project\_id\_hub](#input\_project\_id\_hub) | hub project id | `any` | n/a | yes |
| <a name="input_project_id_onprem"></a> [project\_id\_onprem](#input\_project\_id\_onprem) | onprem project id (for onprem site1 and site2) | `any` | n/a | yes |
| <a name="input_project_id_spoke1"></a> [project\_id\_spoke1](#input\_project\_id\_spoke1) | spoke1 project id (service project id attached to the host project | `any` | n/a | yes |
| <a name="input_project_id_spoke2"></a> [project\_id\_spoke2](#input\_project\_id\_spoke2) | spoke2 project id (standalone project) | `any` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
