
# Troubleshooting <!-- omit from toc -->

Error Messages

- [1. Error disabling Shared VPC Resource](#1-error-disabling-shared-vpc-resource)
- [2. There is a peering operation in progress on the local or peer network](#2-there-is-a-peering-operation-in-progress-on-the-local-or-peer-network)


There are scenarios where you might encounter errors after running terraform to deploy any of the labs. This could be as a result of occasional race conditions or random errors during deployment.

The following are some of the common errors and how to resolve them.

## 1. Error disabling Shared VPC Resource

Due to a race condition, you might encounter an error message related to removal of service project attachment to the shared VPC of a host project

**Example:**

```sh
│ Error: local-exec provisioner error
│
│   with null_resource.remove_service_project_spoke2,
│   on 03-hub-e.tf line 2117, in resource "null_resource" "remove_service_project_spoke2":
│ 2117:   provisioner "local-exec" {
│
│ Error running command '  gcloud compute shared-vpc associated-projects remove prj-spoke2-x --host-project=prj-hub-x
│ ': exit status 1. Output: ERROR: (gcloud.compute.shared-vpc.associated-projects.remove) Could not disable resource [prj-spoke2-x] as an associated resource for project [prj-hub-x]:
│  - The resource 'projects/prj-spoke2-x/regions/us-west2/forwardingRules/e-spoke2-us-ilb7-http-fr' is still linked to shared VPC host 'projects/prj-hub-x'.
```

**Solution:**

Rum terraform destroy again to remove the shared VPC resource

```sh
terraform destroy -auto-approve
```

## 2. There is a peering operation in progress on the local or peer network

Two peering operations cannot be performed at the same time on the same network. If you encounter this error, wait for the current peering operation to complete before running the terraform apply or destroy command again. The following example is from a terraform destroy operation.

**Example:**

```sh
│ Error: Error removing peering `d-hub-int-to-spoke1` from network `d-hub-int-vpc`: googleapi: Error 400: There is a peering operation in progress on the local or peer network. Try again later., badRequest
│
│ Error: local-exec provisioner error
│
│   with null_resource.remove_service_project_spoke1,
│   on 04-host.tf line 174, in resource "null_resource" "remove_service_project_spoke1":
│  174:   provisioner "local-exec" {
│
│ Error running command '  gcloud compute shared-vpc associated-projects remove prj-spoke1-x --host-project=prj-central-x
│ ': exit status 1. Output: ERROR: (gcloud.compute.shared-vpc.associated-projects.remove) Could not disable resource [prj-spoke1-x] as an associated resource for project [prj-central-x]:
│  - The resource 'projects/prj-spoke1-x/regions/europe-west2/forwardingRules/d-spoke1-eu-ilb7-https-fr' is still linked to shared VPC host 'projects/prj-central-x'.
```

**Solution:**

Wait for about a minute and run the terraform destroy command again.

---sh
terraform destroy -auto-approve
```
