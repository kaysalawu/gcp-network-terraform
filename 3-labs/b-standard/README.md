# LAB B: Hybrid Hub and Spoke Connectivity <!-- omit from toc -->

Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Deploy the Lab](#deploy-the-lab)
- [Troubleshooting](#troubleshooting)
- [Outputs](#outputs)
- [Running Tests from VM Instances](#running-tests-from-vm-instances)
- [Site1 (On-premises EU)](#site1-on-premises-eu)
- [Site2 (On-premises US)](#site2-on-premises-us)
- [Spoke2 (US Region)](#spoke2-us-region)
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

## Site1 (On-premises EU)

1. Login to the instance `b-site1-vm` using the [SSH-in-Browser](https://cloud.google.com/compute/docs/ssh-in-browser) from the Google Cloud console.


2. Run IP ping test

   ```sh
   ping-ipv4
   ```

   <Details>
   <Summary>🟢 Sample output (expand to view)</Summary>

   ```sh
   admin_cloudtuple_com@b-site1-vm:~$ ping-ipv4

    ping ipv4 ...

   site1-vm      - 10.10.1.9 -OK 0.039 ms
   hub-eu-vm     - 10.1.11.9 -OK 2.378 ms
   spoke1-eu-vm  - 10.11.11.9 -OK 1.923 ms
   hub-eu-ilb    - 10.1.11.70 -NA
   spoke1-eu-ilb - 10.11.11.30 -NA
   site2-vm      - 10.20.1.9 -OK 138.845 ms
   hub-us-vm     - 10.1.21.9 -OK 137.984 ms
   spoke2-us-vm  - 10.22.21.9 -OK 136.939 ms
   hub-us-ilb    - 10.1.21.70 -NA
   ```
   </Details>
   <p>

   The internal passthrough load balancers - `hub-eu-ilb`, `hub-us-ilb`, and `spoke1-eu-ilb` - are not pingable because their forwarding rules are configured for TCP traffic only and do not respond to ICMP. The forwarding rule need to be configured for `L3_DEFAULT` to allow ICMP traffic.


3. Ping DNS for IPv4 addresses

   ```sh
   ping-dns4
   ```

   <Details>
   <Summary>🟢 Sample output (expand to view)</Summary>

   ```sh
   admin_cloudtuple_com@b-site1-vm:~$ ping-dns4

    ping dns ipv4 ...

   vm.site1.corp - 10.10.1.9 -OK 0.036 ms
   vm.eu.hub.g.corp - 10.1.11.9 -OK 2.109 ms
   vm.eu.spoke1.g.corp - 10.11.11.9 -OK 2.141 ms
   ilb.eu.hub.g.corp - 10.1.11.70 -NA
   ilb.eu.spoke1.g.corp - 10.11.11.30 -NA
   vm.site2.corp - 10.20.1.9 -OK 138.905 ms
   vm.us.hub.g.corp - 10.1.21.9 -OK 137.774 ms
   vm.us.spoke2.g.corp - 10.22.21.9 -OK 137.063 ms
   ilb.us.hub.g.corp - 10.1.21.70 -NA
   ```
   </Details>
   <p>

   This confirms our onpremises and hybrid-cloud DNS works. We have the same ping results as the IPv4 ping test.


4. Ping DNS for IPv6 addresses

   ```sh
   ping-dns6
   ```

   <Details>
   <Summary>🟢 Sample output (expand to view)</Summary>

   ```sh
   admin_cloudtuple_com@b-site1-vm:~$ ping-dns6
    ping dns ipv6 ...
   vm.site1.corp - fd20:35a:3e79:4000:0:a:: -OK 0.035 ms
   vm.eu.hub.g.corp - fd20:ccd:8944:4000:0:13:: -OK 2.747 ms
   vm.eu.spoke1.g.corp - fd20:a37:7dec:4000:0:12:: -OK 2.133 ms
   ilb.eu.hub.g.corp - fd20:ccd:8944:4000:0:4:: -NA
   ilb.eu.spoke1.g.corp - fd20:a37:7dec:4000:0:3:: -NA
   vm.site2.corp - fd20:9a5:1ed4:8000:0:a:: -NA
   vm.us.hub.g.corp - fd20:ccd:8944:8000:0:13:: -OK 136.589 ms
   vm.us.spoke2.g.corp - fd20:c2f:6706:8000:0:5:: -OK 135.722 ms
   ilb.us.hub.g.corp - fd20:ccd:8944:8000:0:4:: -NA
   ```
   </Details>
   <p>

   We have the same results as the IPv4 tests woth only one exception - the IPv6 address for `vm.site2.corp` is not reachable because Network Connectivity Center (NCC) does not yet support IPv6.


5. Curl IPv4 DNS

   ```sh
   curl-dns4
   ```

   <Details>
   <Summary>🟢 Sample output (expand to view)</Summary>

   ```sh
   admin_cloudtuple_com@b-site1-vm:~$ curl-dns4

    curl dns ipv4 ...

   200 (0.008111s) - 10.10.1.9 - vm.site1.corp
   200 (0.008707s) - 10.1.11.9 - vm.eu.hub.g.corp
   200 (0.007315s) - 10.11.11.9 - vm.eu.spoke1.g.corp
   200 (0.007905s) - 10.1.11.70 - ilb.eu.hub.g.corp
   200 (0.023711s) - 10.1.11.80 - nlb.eu.hub.g.corp
   200 (0.023825s) - 10.1.11.90 - alb.eu.hub.g.corp
   200 (0.005212s) - 10.11.11.30 - ilb.eu.spoke1.g.corp
   200 (0.020641s) - 10.11.11.40 - nlb.eu.spoke1.g.corp
   200 (0.023526s) - 10.11.11.50 - alb.eu.spoke1.g.corp
   200 (0.017780s) - 10.1.11.66 - ep.eu.spoke1-eu-ilb.hub.g.corp
   200 (0.012227s) - 10.1.11.77 - ep.eu.spoke1-eu-nlb.hub.g.corp
   200 (0.017261s) - 10.1.11.88 - ep.eu.spoke1-eu-alb.hub.g.corp
   200 (0.286969s) - 10.20.1.9 - vm.site2.corp
   200 (0.276842s) - 10.1.21.9 - vm.us.hub.g.corp
   200 (0.283544s) - 10.22.21.9 - vm.us.spoke2.g.corp
   200 (0.277318s) - 10.1.21.70 - ilb.us.hub.g.corp
    - nlb.us.hub.g.corp
    - alb.us.hub.g.corp
   200 (0.015702s) - 10.1.11.70 - ilb.geo.hub.g.corp
   200 (0.026692s) - 104.16.185.241 - icanhazip.com
   204 (0.019666s) - 142.250.179.234 - www.googleapis.com
   204 (0.012112s) - 10.1.0.1 - storage.googleapis.com
   204 (0.043873s) - 10.1.11.90 - europe-west2-run.googleapis.com
    - us-west2-run.googleapis.com
   403 (0.243257s) - 10.1.0.1 - https://b-hub-eu-run-httpbin-wapotrwjpq-nw.a.run.app
   ```

   </Details>
   <p>

   The unreachable services are regional `us` services that cannot be accessed from the on-premises site with HA-VPN in `eu` region.


6. Curl IPv6 DNS

   ```sh
   curl-dns6
   ```

   <Details>
   <Summary>🟢 Sample output (expand to view)</Summary>

   ```sh
   admin_cloudtuple_com@b-site1-vm:~$ curl-dns6

    curl dns ipv6 ...

   200 (0.010662s) - fd20:35a:3e79:4000:0:a:: - vm.site1.corp
   200 (0.022900s) - fd20:ccd:8944:4000:0:13:: - vm.eu.hub.g.corp
   200 (0.017259s) - fd20:a37:7dec:4000:0:12:: - vm.eu.spoke1.g.corp
   200 (0.019619s) - fd20:ccd:8944:4000:0:4:: - ilb.eu.hub.g.corp
   000 (0.014108s) -  - nlb.eu.hub.g.corp
   000 (0.009802s) -  - alb.eu.hub.g.corp
   200 (0.010900s) - fd20:a37:7dec:4000:0:3:: - ilb.eu.spoke1.g.corp
   000 (0.006560s) -  - nlb.eu.spoke1.g.corp
   000 (0.005450s) -  - alb.eu.spoke1.g.corp
   000 (0.006595s) -  - ep.eu.spoke1-eu-ilb.hub.g.corp
   000 (0.005485s) -  - ep.eu.spoke1-eu-nlb.hub.g.corp
   000 (0.005473s) -  - ep.eu.spoke1-eu-alb.hub.g.corp
   000 (1.502127s) -  - vm.site2.corp
   200 (0.283614s) - fd20:ccd:8944:8000:0:13:: - vm.us.hub.g.corp
   200 (0.284461s) - fd20:c2f:6706:8000:0:5:: - vm.us.spoke2.g.corp
   200 (0.283403s) - fd20:ccd:8944:8000:0:4:: - ilb.us.hub.g.corp
   000 (0.006571s) -  - nlb.us.hub.g.corp
   000 (0.006523s) -  - alb.us.hub.g.corp
   000 (0.006612s) -  - ilb.geo.hub.g.corp
   000 (2.251715s) -  - icanhazip.com
   404 (0.109225s) - 2a00:1450:4009:817::200a - www.googleapis.com
   000 (0.002264s) -  - storage.googleapis.com
   000 (0.003316s) -  - europe-west2-run.googleapis.com
   000 (0.001168s) -  - us-west2-run.googleapis.com
   000 (0.001148s) -  - https://b-hub-eu-run-httpbin-wapotrwjpq-nw.a.run.app
   ```

   </Details>
   <p>

   The unreachable services are regional `us` services that cannot be accessed from the on-premises site through the HA-VPN in `eu` region.  Internal network proxy load balancer (nlb) and internal application load balancer (alb) don't support IPv6 yet.


7. Run an authenticated test to services using the [PSC backend for API access](https://cloud.google.com/vpc/docs/private-service-connect-backends).

   ```sh
   curl-psc-backend
   ```

   <Details>
   <Summary>🟢 Sample output (expand to view)</Summary>

   ```sh
   admin_cloudtuple_com@b-site1-vm:~$ curl-psc-backend

    curl psc backend ...

   204 (0.024659s) - 10.1.11.90 - europe-west2-run.googleapis.com
    - us-west2-run.googleapis.com
   200 (1.889214s) - 10.1.0.1 - https://b-hub-eu-run-httpbin-wapotrwjpq-nw.a.run.app
   ```
   </Details>
   <p>

   We can reach the `eu` cloud run services `europe-west2-run.googleapis.com` through the PSC backend for API access. The VM in `site1` connects to the internal application load balancer in the hub `eu` region. The load balancer uses a Network Endpoint Group (NEG) backend to route traffic to the Cloud Run service. The endpoint in `us` region is not reachable because the on-premises site is connected to the `eu` region. We also have access to the cloud run data plane through the PSC endpoint for API access on private IP address **10.1.0.1**.


8. Test access to all Google APIs using the [discoverz.py](../../scripts/startup/discoverz.py) script.

   ```sh
   cd /var/lib/gcp/fastapi/app/app && \
   python3 discoverz.py
   ```

   <Details>
   <Summary>🟢 Sample output (expand to view)</Summary>

   ```sh
   scanning all api endpoints ...

   204 - abusiveexperiencereport    v1         https://abusiveexperiencereport.googleapis.com/generate_204
   204 - acceleratedmobilepageurl   v1         https://acceleratedmobilepageurl.googleapis.com/generate_204
   204 - accessapproval             v1         https://accessapproval.googleapis.com/generate_204
   204 - accesscontextmanager       v1         https://accesscontextmanager.googleapis.com/generate_204
   204 - addressvalidation          v1         https://addressvalidation.googleapis.com/generate_204
   204 - adexchangebuyer2           v2beta1    https://adexchangebuyer2.googleapis.com/generate_204
   204 - adexperiencereport         v1         https://adexperiencereport.googleapis.com/generate_204
   204 - admin                      datatransfer_v1 https://admin.googleapis.com/generate_204
   204 - admin                      directory_v1 https://admin.googleapis.com/generate_204
   204 - admin                      reports_v1 https://admin.googleapis.com/generate_204
   ...
   [truncated]
   ...
   204 - workloadmanager            v1         https://workloadmanager.googleapis.com/generate_204
   204 - workspaceevents            v1         https://workspaceevents.googleapis.com/generate_204
   204 - workstations               v1         https://workstations.googleapis.com/generate_204
   204 - workstations               v1         https://workstations.googleapis.com/generate_204
   204 - youtube                    v1         https://youtube.googleapis.com/generate_204
   204 - youtubeAnalytics           v1         https://youtubeAnalytics.googleapis.com/generate_204
   204 - youtubereporting           v1         https://youtubereporting.googleapis.com/generate_204

   unreachable api endpoints ...

   err - cloudbilling               v1         https://cloudbilling.googleapis.com/generate_204
   err - cloudbilling               v1         https://cloudbilling.googleapis.com/generate_204
   err - fcmdata                    v1         https://fcmdata.googleapis.com/generate_204
   ```

   </Details>
   <p>


## Site2 (On-premises US)

1. Login to the instance `b-site2-vm` using the [SSH-in-Browser](https://cloud.google.com/compute/docs/ssh-in-browser) from the Google Cloud console.


2. Run IP ping test

   ```sh
   ping-ipv4
   ```

   <Details>
   <Summary>🟢 Sample output (expand to view)</Summary>

   ```sh
   admin_cloudtuple_com@b-site2-vm:~$ ping-ipv4

    ping ipv4 ...

   site1-vm      - 10.10.1.9 -OK 139.534 ms
   hub-eu-vm     - 10.1.11.9 -OK 137.848 ms
   spoke1-eu-vm  - 10.11.11.9 -OK 136.851 ms
   hub-eu-ilb    - 10.1.11.70 -NA
   spoke1-eu-ilb - 10.11.11.30 -NA
   site2-vm      - 10.20.1.9 -OK 0.060 ms
   hub-us-vm     - 10.1.21.9 -OK 2.128 ms
   spoke2-us-vm  - 10.22.21.9 -OK 3.561 ms
   hub-us-ilb    - 10.1.21.70 -NA
   ```
   </Details>
   <p>

   The internal passthrough load balancers - `hub-eu-ilb`, `hub-us-ilb`, and `spoke1-eu-ilb` - are not pingable because their forwarding rules are configured for TCP traffic only and do not respond to ICMP. The forwarding rule need to be configured for `L3_DEFAULT` to allow ICMP traffic.


3. Ping DNS for IPv4 addresses

   ```sh
   ping-dns4
   ```

   <Details>
   <Summary>🟢 Sample output (expand to view)</Summary>

   ```sh
   admin_cloudtuple_com@b-site2-vm:~$ ping-dns4

    ping dns ipv4 ...

   vm.site1.corp - 10.10.1.9 -OK 139.371 ms
   vm.eu.hub.g.corp - 10.1.11.9 -OK 137.754 ms
   vm.eu.spoke1.g.corp - 10.11.11.9 -OK 136.336 ms
   ilb.eu.hub.g.corp - 10.1.11.70 -NA
   ilb.eu.spoke1.g.corp - 10.11.11.30 -NA
   vm.site2.corp - 10.20.1.9 -OK 0.041 ms
   vm.us.hub.g.corp - 10.1.21.9 -OK 1.925 ms
   vm.us.spoke2.g.corp - 10.22.21.9 -OK 2.762 ms
   ilb.us.hub.g.corp - 10.1.21.70 -NA
   ```
   </Details>
   <p>

   This confirms our onpremises and hybrid-cloud DNS works. We have the same ping results as the IPv4 ping test.

4. Ping DNS for IPv6 addresses

   ```sh
   ping-dns6
   ```

   <Details>
   <Summary>🟢 Sample output (expand to view)</Summary>

   ```sh
   admin_cloudtuple_com@b-site2-vm:~$ ping-dns6
    ping dns ipv6 ...
   vm.site1.corp - fd20:35a:3e79:4000:0:a:: -NA
   vm.eu.hub.g.corp - fd20:ccd:8944:4000:0:13:: -OK 137.714 ms
   vm.eu.spoke1.g.corp - fd20:a37:7dec:4000:0:12:: -OK 137.215 ms
   ilb.eu.hub.g.corp - fd20:ccd:8944:4000:0:4:: -NA
   ilb.eu.spoke1.g.corp - fd20:a37:7dec:4000:0:3:: -NA
   vm.site2.corp - fd20:9a5:1ed4:8000:0:a:: -OK 0.052 ms
   vm.us.hub.g.corp - fd20:ccd:8944:8000:0:13:: -OK 1.997 ms
   vm.us.spoke2.g.corp - fd20:c2f:6706:8000:0:5:: -OK 1.979 ms
   ilb.us.hub.g.corp - fd20:ccd:8944:8000:0:4:: -NA
   ```
   </Details>
   <p>

   We have the same results as the IPv4 tests woth only one exception - the IPv6 address for `vm.site2.corp` is not reachable because Network Connectivity Center (NCC) does not yet support IPv6.

5. Curl IPv4 DNS

   ```sh
   curl-dns4
   ```

   <Details>
   <Summary>🟢 Sample output (expand to view)</Summary>

   ```sh
   admin_cloudtuple_com@b-site2-vm:~$ curl-dns4

    curl dns ipv4 ...

   200 (0.281099s) - 10.10.1.9 - vm.site1.corp
   200 (0.278324s) - 10.1.11.9 - vm.eu.hub.g.corp
   200 (0.278135s) - 10.11.11.9 - vm.eu.spoke1.g.corp
   200 (0.276582s) - 10.1.11.70 - ilb.eu.hub.g.corp
    - nlb.eu.hub.g.corp
    - alb.eu.hub.g.corp
   200 (0.277704s) - 10.11.11.30 - ilb.eu.spoke1.g.corp
    - nlb.eu.spoke1.g.corp
    - alb.eu.spoke1.g.corp
    - ep.eu.spoke1-eu-ilb.hub.g.corp
    - ep.eu.spoke1-eu-nlb.hub.g.corp
    - ep.eu.spoke1-eu-alb.hub.g.corp
   200 (0.004303s) - 10.20.1.9 - vm.site2.corp
   200 (0.008436s) - 10.1.21.9 - vm.us.hub.g.corp
   200 (0.008877s) - 10.22.21.9 - vm.us.spoke2.g.corp
   200 (0.008224s) - 10.1.21.70 - ilb.us.hub.g.corp
   200 (0.020736s) - 10.1.21.90 - nlb.us.hub.g.corp
   200 (0.023240s) - 10.1.21.80 - alb.us.hub.g.corp
   200 (0.020866s) - 10.1.21.70 - ilb.geo.hub.g.corp
   200 (0.034876s) - 104.16.185.241 - icanhazip.com
   204 (0.016178s) - 142.250.176.10 - www.googleapis.com
   204 (0.013185s) - 10.1.0.1 - storage.googleapis.com
    - europe-west2-run.googleapis.com
   204 (0.025057s) - 10.1.21.80 - us-west2-run.googleapis.com
   403 (1.038142s) - 10.1.0.1 - https://b-hub-eu-run-httpbin-wapotrwjpq-nw.a.run.app
   ```

   </Details>
   <p>

   The unreachable services are regional `eu` services that cannot be accessed from the on-premises site with HA-VPN in `us` region. The internal passthrough load balancer `ilb.eu.spoke1.g.corp` is reachable in `eu` region from `us` region because we enabled global access for the frontend.

6. Curl IPv6 DNS

   ```sh
   curl-dns6
   ```

   <Details>
   <Summary>🟢 Sample output (expand to view)</Summary>

   ```sh
   admin_cloudtuple_com@b-site2-vm:~$ curl-dns6

    curl dns ipv6 ...

   000 (1.506285s) -  - vm.site1.corp
   200 (0.292778s) - fd20:ccd:8944:4000:0:13:: - vm.eu.hub.g.corp
   200 (0.297321s) - fd20:a37:7dec:4000:0:12:: - vm.eu.spoke1.g.corp
   200 (0.297064s) - fd20:ccd:8944:4000:0:4:: - ilb.eu.hub.g.corp
   000 (0.013167s) -  - nlb.eu.hub.g.corp
   000 (0.011072s) -  - alb.eu.hub.g.corp
   200 (0.286670s) - fd20:a37:7dec:4000:0:3:: - ilb.eu.spoke1.g.corp
   000 (0.008900s) -  - nlb.eu.spoke1.g.corp
   000 (0.008805s) -  - alb.eu.spoke1.g.corp
   000 (0.007843s) -  - ep.eu.spoke1-eu-ilb.hub.g.corp
   000 (0.010048s) -  - ep.eu.spoke1-eu-nlb.hub.g.corp
   000 (0.008939s) -  - ep.eu.spoke1-eu-alb.hub.g.corp
   200 (0.008297s) - fd20:9a5:1ed4:8000:0:a:: - vm.site2.corp
   200 (0.015539s) - fd20:ccd:8944:8000:0:13:: - vm.us.hub.g.corp
   200 (0.016153s) - fd20:c2f:6706:8000:0:5:: - vm.us.spoke2.g.corp
   200 (0.016385s) - fd20:ccd:8944:8000:0:4:: - ilb.us.hub.g.corp
   000 (0.008942s) -  - nlb.us.hub.g.corp
   000 (0.008876s) -  - alb.us.hub.g.corp
   000 (0.012075s) -  - ilb.geo.hub.g.corp
   000 (2.253583s) -  - icanhazip.com
   404 (0.113178s) - 2607:f8b0:4007:810::200a - www.googleapis.com
   000 (0.003346s) -  - storage.googleapis.com
   000 (0.003432s) -  - europe-west2-run.googleapis.com
   000 (0.003355s) -  - us-west2-run.googleapis.com
   000 (0.002235s) -  - https://b-hub-eu-run-httpbin-wapotrwjpq-nw.a.run.app
   ```

   </Details>
   <p>

   We have the same results as IPv4 curl with the exception of internal network proxy load balancer (nlb) and internal application load balancer (alb) that don't support IPv6 yet.


7. Run an authenticated test to services using the [PSC backend for API access](https://cloud.google.com/vpc/docs/private-service-connect-backends).

   ```sh
   curl-psc-backend
   ```

   <Details>
   <Summary>🟢 Sample output (expand to view)</Summary>

   ```sh
   admin_cloudtuple_com@b-site2-vm:~$ curl-psc-backend

    curl psc backend ...

    - europe-west2-run.googleapis.com
   204 (0.032184s) - 10.1.21.80 - us-west2-run.googleapis.com
   200 (0.868642s) - 10.1.0.1 - https://b-hub-eu-run-httpbin-wapotrwjpq-nw.a.run.app
   ```
   </Details>
   <p>

   We can reach the `us` cloud run services `us-west2-run.googleapis.com` through the PSC backend for API access. The VM in `site2` connects to the internal application load balancer in the hub `us` region. The load balancer uses a Network Endpoint Group (NEG) backend to route traffic to the Cloud Run service.

   The endpoint in `eu` region is not reachable because the on-premises site is connected to the `us` region. We also have access to the cloud run data plane through the PSC endpoint for API access on private IP address **10.1.0.1**.


8. Test access to all Google APIs using the [discoverz.py](../../scripts/startup/discoverz.py) script.

   ```sh
   cd /var/lib/gcp/fastapi/app/app && \
   python3 discoverz.py
   ```

   <Details>
   <Summary>🟢 Sample output (expand to view)</Summary>

   ```sh
   scanning all api endpoints ...

   204 - abusiveexperiencereport    v1         https://abusiveexperiencereport.googleapis.com/generate_204
   204 - acceleratedmobilepageurl   v1         https://acceleratedmobilepageurl.googleapis.com/generate_204
   204 - accessapproval             v1         https://accessapproval.googleapis.com/generate_204
   204 - accesscontextmanager       v1         https://accesscontextmanager.googleapis.com/generate_204
   204 - addressvalidation          v1         https://addressvalidation.googleapis.com/generate_204
   204 - adexchangebuyer2           v2beta1    https://adexchangebuyer2.googleapis.com/generate_204
   204 - adexperiencereport         v1         https://adexperiencereport.googleapis.com/generate_204
   204 - admin                      datatransfer_v1 https://admin.googleapis.com/generate_204
   204 - admin                      directory_v1 https://admin.googleapis.com/generate_204
   204 - admin                      reports_v1 https://admin.googleapis.com/generate_204
   ...
   [truncated]
   ...
   204 - workloadmanager            v1         https://workloadmanager.googleapis.com/generate_204
   204 - workspaceevents            v1         https://workspaceevents.googleapis.com/generate_204
   204 - workstations               v1         https://workstations.googleapis.com/generate_204
   204 - workstations               v1         https://workstations.googleapis.com/generate_204
   204 - youtube                    v1         https://youtube.googleapis.com/generate_204
   204 - youtubeAnalytics           v1         https://youtubeAnalytics.googleapis.com/generate_204
   204 - youtubereporting           v1         https://youtubereporting.googleapis.com/generate_204

   unreachable api endpoints ...

   err - cloudbilling               v1         https://cloudbilling.googleapis.com/generate_204
   err - cloudbilling               v1         https://cloudbilling.googleapis.com/generate_204
   err - fcmdata                    v1         https://fcmdata.googleapis.com/generate_204
   ```

   </Details>
   <p>


## Spoke2 (US Region)

1. Login to the instance `b-spoke2-us-vm` using the [SSH-in-Browser](https://cloud.google.com/compute/docs/ssh-in-browser) from the Google Cloud console.

2. Run IP ping test

   ```sh
   ping-ipv4
   ```

   <Details>
   <Summary>🟢 Sample output (expand to view)</Summary>

   ```sh
   admin_cloudtuple_com@b-spoke2-us-vm:~$ ping-ipv4

    ping ipv4 ...

   site1-vm      - 10.10.1.9 -OK 136.790 ms
   hub-eu-vm     - 10.1.11.9 -OK 135.853 ms
   spoke1-eu-vm  - 10.11.11.9 -OK 136.454 ms
   hub-eu-ilb    - 10.1.11.70 -NA
   spoke1-eu-ilb - 10.11.11.30 -NA
   site2-vm      - 10.20.1.9 -OK 3.434 ms
   hub-us-vm     - 10.1.21.9 -OK 0.557 ms
   spoke2-us-vm  - 10.22.21.9 -OK 0.041 ms
   hub-us-ilb    - 10.1.21.70 -NA
   ```
   </Details>
   <p>

   The internal passthrough load balancers - `hub-eu-ilb`, `hub-us-ilb`, and `spoke1-eu-ilb` - are not pingable because their forwarding rules are configured for TCP traffic only and do not respond to ICMP. The forwarding rule need to be configured for `L3_DEFAULT` to allow ICMP traffic.


3. Ping DNS for IPv4 addresses

   ```sh
   ping-dns4
   ```

   <Details>
   <Summary>🟢 Sample output (expand to view)</Summary>

   ```sh
   admin_cloudtuple_com@b-spoke2-us-vm:~$ ping-dns4

    ping dns ipv4 ...

   vm.site1.corp - 10.10.1.9 -OK 136.468 ms
   vm.eu.hub.g.corp - 10.1.11.9 -OK 135.714 ms
   vm.eu.spoke1.g.corp - 10.11.11.9 -OK 136.361 ms
   ilb.eu.hub.g.corp - 10.1.11.70 -NA
   ilb.eu.spoke1.g.corp - 10.11.11.30 -NA
   vm.site2.corp - 10.20.1.9 -OK 2.727 ms
   vm.us.hub.g.corp - 10.1.21.9 -OK 0.549 ms
   vm.us.spoke2.g.corp - 10.22.21.9 -OK 0.028 ms
   ilb.us.hub.g.corp - 10.1.21.70 -NA
   ```
   </Details>
   <p>

   This confirms our onpremises and hybrid-cloud DNS works. We have the same ping results as the IPv4 ping test.

4. Ping DNS for IPv6 addresses

   ```sh
   ping-dns6
   ```

   <Details>
   <Summary>🟢 Sample output (expand to view)</Summary>

   ```sh
   admin_cloudtuple_com@b-spoke2-us-vm:~$ ping-dns6
    ping dns ipv6 ...
   vm.site1.corp - fd20:35a:3e79:4000:0:a:: -OK 136.500 ms
   vm.eu.hub.g.corp - fd20:ccd:8944:4000:0:13:: -OK 135.995 ms
   vm.eu.spoke1.g.corp - fd20:a37:7dec:4000:0:12:: -OK 135.347 ms
   ilb.eu.hub.g.corp - fd20:ccd:8944:4000:0:4:: -NA
   ilb.eu.spoke1.g.corp - fd20:a37:7dec:4000:0:3:: -NA
   vm.site2.corp - fd20:9a5:1ed4:8000:0:a:: -OK 2.212 ms
   vm.us.hub.g.corp - fd20:ccd:8944:8000:0:13:: -OK 0.639 ms
   vm.us.spoke2.g.corp - fd20:c2f:6706:8000:0:5:: -OK 0.029 ms
   ilb.us.hub.g.corp - fd20:ccd:8944:8000:0:4:: -NA
   ```
   </Details>
   <p>

   We have the same results as the IPv4 tests woth only one exception - the IPv6 address for `vm.site2.corp` is not reachable because Network Connectivity Center (NCC) does not yet support IPv6.

5. Curl IPv4 DNS

   ```sh
   curl-dns4
   ```

   <Details>
   <Summary>🟢 Sample output (expand to view)</Summary>

   ```sh
   admin_cloudtuple_com@b-spoke2-us-vm:~$ curl-dns4

    curl dns ipv4 ...

   200 (0.278005s) - 10.10.1.9 - vm.site1.corp
   200 (0.276345s) - 10.1.11.9 - vm.eu.hub.g.corp
   200 (0.274998s) - 10.11.11.9 - vm.eu.spoke1.g.corp
   200 (0.272853s) - 10.1.11.70 - ilb.eu.hub.g.corp
    - nlb.eu.hub.g.corp
    - alb.eu.hub.g.corp
   200 (0.275390s) - 10.11.11.30 - ilb.eu.spoke1.g.corp
    - nlb.eu.spoke1.g.corp
    - alb.eu.spoke1.g.corp
    - ep.eu.spoke1-eu-ilb.hub.g.corp
    - ep.eu.spoke1-eu-nlb.hub.g.corp
    - ep.eu.spoke1-eu-alb.hub.g.corp
   200 (0.009255s) - 10.20.1.9 - vm.site2.corp
   200 (0.005436s) - 10.1.21.9 - vm.us.hub.g.corp
   200 (0.003661s) - 10.22.21.9 - vm.us.spoke2.g.corp
   200 (0.004745s) - 10.1.21.70 - ilb.us.hub.g.corp
   200 (0.008737s) - 10.1.21.90 - nlb.us.hub.g.corp
   200 (0.009051s) - 10.1.21.80 - alb.us.hub.g.corp
   200 (0.007006s) - 10.1.21.70 - ilb.geo.hub.g.corp
   200 (0.028517s) - 104.16.185.241 - icanhazip.com
   204 (0.002446s) - 142.250.176.10 - www.googleapis.com
   204 (0.005772s) - 10.22.0.2 - storage.googleapis.com
   204 (0.003715s) - 10.22.0.2 - europe-west2-run.googleapis.com
   204 (0.004150s) - 10.22.0.2 - us-west2-run.googleapis.com
   403 (0.978613s) - 10.22.0.2 - https://b-hub-eu-run-httpbin-wapotrwjpq-nw.a.run.app
   ```

   </Details>
   <p>

   The unreachable services are regional `eu` services that cannot be accessed from the on-premises site with HA-VPN in `us` region. The internal passthrough load balancer `ilb.eu.spoke1.g.corp` is reachable in `eu` region from `us` region because we enabled global access for the frontend.

6. Curl IPv6 DNS

   ```sh
   curl-dns4
   ```

   <Details>
   <Summary>🟢 Sample output (expand to view)</Summary>

   ```sh
   admin_cloudtuple_com@b-spoke2-us-vm:~$ curl-dns6

    curl dns ipv6 ...

   200 (0.564266s) - fd20:35a:3e79:4000:0:a:: - vm.site1.corp
   200 (0.281879s) - fd20:ccd:8944:4000:0:13:: - vm.eu.hub.g.corp
   200 (0.278967s) - fd20:a37:7dec:4000:0:12:: - vm.eu.spoke1.g.corp
   200 (0.278942s) - fd20:ccd:8944:4000:0:4:: - ilb.eu.hub.g.corp
   000 (0.005551s) -  - nlb.eu.hub.g.corp
   000 (0.003390s) -  - alb.eu.hub.g.corp
   200 (0.276953s) - fd20:a37:7dec:4000:0:3:: - ilb.eu.spoke1.g.corp
   000 (0.003358s) -  - nlb.eu.spoke1.g.corp
   000 (0.002262s) -  - alb.eu.spoke1.g.corp
   000 (0.002404s) -  - ep.eu.spoke1-eu-ilb.hub.g.corp
   000 (0.002253s) -  - ep.eu.spoke1-eu-nlb.hub.g.corp
   000 (0.002347s) -  - ep.eu.spoke1-eu-alb.hub.g.corp
   200 (0.155110s) - fd20:9a5:1ed4:8000:0:a:: - vm.site2.corp
   200 (0.006650s) - fd20:ccd:8944:8000:0:13:: - vm.us.hub.g.corp
   200 (0.006183s) - fd20:c2f:6706:8000:0:5:: - vm.us.spoke2.g.corp
   200 (0.007195s) - fd20:ccd:8944:8000:0:4:: - ilb.us.hub.g.corp
   000 (0.002306s) -  - nlb.us.hub.g.corp
   000 (0.002369s) -  - alb.us.hub.g.corp
   000 (0.005546s) -  - ilb.geo.hub.g.corp
   000 (2.252486s) -  - icanhazip.com
   404 (0.105264s) - 2607:f8b0:4007:814::200a - www.googleapis.com
   400 (0.009179s) - 2607:f8b0:4007:811::201b - storage.googleapis.com
   404 (0.826209s) - 2607:f8b0:4007:810::200a - europe-west2-run.googleapis.com
   404 (0.006428s) - 2607:f8b0:4007:801::200a - us-west2-run.googleapis.com
   403 (1.079109s) - 2001:4860:4802:38::35 - https://b-hub-eu-run-httpbin-wapotrwjpq-nw.a.run.app
   ```

   </Details>
   <p>

   We have the same results as IPv4 curl with the exception of internal network proxy load balancer (nlb) and internal application load balancer (alb) that don't support IPv6 yet.


7. Run an authenticated test to services using the [PSC backend for API access](https://cloud.google.com/vpc/docs/private-service-connect-backends).

   ```sh
   curl-psc-backend
   ```

   <Details>
   <Summary>🟢 Sample output (expand to view)</Summary>

   ```sh
   admin_cloudtuple_com@b-spoke2-us-vm:~$ curl-psc-backend

    curl psc backend ...

   204 (0.017555s) - 10.22.0.2 - europe-west2-run.googleapis.com
   204 (0.013675s) - 10.22.0.2 - us-west2-run.googleapis.com
   200 (1.739257s) - 10.22.0.2 - https://b-hub-eu-run-httpbin-wapotrwjpq-nw.a.run.app
   ```
   </Details>
   <p>

   We can reach all services through VPC peering.


8. Test access to all Google APIs using the [discoverz.py](../../scripts/startup/discoverz.py) script.

   ```sh
   cd /var/lib/gcp/fastapi/app/app && \
   python3 discoverz.py
   ```

   <Details>
   <Summary>🟢 Sample output (expand to view)</Summary>

   ```sh
   scanning all api endpoints ...

   204 - abusiveexperiencereport    v1         https://abusiveexperiencereport.googleapis.com/generate_204
   204 - acceleratedmobilepageurl   v1         https://acceleratedmobilepageurl.googleapis.com/generate_204
   204 - accessapproval             v1         https://accessapproval.googleapis.com/generate_204
   204 - accesscontextmanager       v1         https://accesscontextmanager.googleapis.com/generate_204
   204 - addressvalidation          v1         https://addressvalidation.googleapis.com/generate_204
   204 - adexchangebuyer2           v2beta1    https://adexchangebuyer2.googleapis.com/generate_204
   204 - adexperiencereport         v1         https://adexperiencereport.googleapis.com/generate_204
   204 - admin                      datatransfer_v1 https://admin.googleapis.com/generate_204
   204 - admin                      directory_v1 https://admin.googleapis.com/generate_204
   204 - admin                      reports_v1 https://admin.googleapis.com/generate_204
   ...
   [truncated]
   ...
   204 - workloadmanager            v1         https://workloadmanager.googleapis.com/generate_204
   204 - workspaceevents            v1         https://workspaceevents.googleapis.com/generate_204
   204 - workstations               v1         https://workstations.googleapis.com/generate_204
   204 - workstations               v1         https://workstations.googleapis.com/generate_204
   204 - youtube                    v1         https://youtube.googleapis.com/generate_204
   204 - youtubeAnalytics           v1         https://youtubeAnalytics.googleapis.com/generate_204
   204 - youtubereporting           v1         https://youtubereporting.googleapis.com/generate_204

   unreachable api endpoints ...

   err - cloudbilling               v1         https://cloudbilling.googleapis.com/generate_204
   err - cloudbilling               v1         https://cloudbilling.googleapis.com/generate_204
   err - fcmdata                    v1         https://fcmdata.googleapis.com/generate_204
   ```

   </Details>
   <p>

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
