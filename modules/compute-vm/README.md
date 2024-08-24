# Google Compute Engine VM module

This module can operate in two distinct modes:

- instance creation, with optional unmanaged group
- instance template creation

In both modes, an optional service account can be created and assigned to either instances or template. If you need a managed instance group when using the module in template mode, refer to the [`compute-mig`](../compute-mig) module.

## Examples

### Instance using defaults

The simplest example leverages defaults for the boot disk image and size, and uses a service account created by the module. Multiple instances can be managed via the `instance_count` variable.

```hcl
module "simple-vm-example" {
  source     = "./modules/compute-vm"
  project_id = var.project_id
  zone     = "europe-west1-b"
  name       = "test"
  network_interfaces = [{
    network    = var.vpc.self_link
    subnetwork = var.subnet.self_link
    nat        = false
    addresses  = null
    alias_ips  = null
  }]
  service_account_create = true
}
# tftest:modules=1:resources=2

```

### Disk sources

Attached disks can be created and optionally initialized from a pre-existing source, or attached to VMs when pre-existing. The `source` and `source_type` attributes of the `attached_disks` variable allows several modes of operation:

- `source_type = "image"` can be used with zonal disks in instances and templates, set `source` to the image name or link
- `source_type = "snapshot"` can be used with instances only, set `source` to the snapshot name or link
- `source_type = "attach"` can be used for both instances and templates to attach an existing disk, set source to the name (for zonal disks) or link (for regional disks) of the existing disk to attach; no disk will be created
- `source_type = null` can be used where an empty disk is needed, `source` becomes irrelevant and can be left null

This is an example of attaching a pre-existing regional PD to a new instance:

```hcl
module "simple-vm-example" {
  source     = "./modules/compute-vm"
  project_id = var.project_id
  zone     = "${var.region}-b"
  name       = "test"
  network_interfaces = [{
    network    = var.vpc.self_link
    subnetwork = var.subnet.self_link
    nat        = false
    addresses  = null
    alias_ips  = null
  }]
  attached_disks = [{
    name        = "repd-1"
    size        = null
    source_type = "attach"
    source      = "regions/${var.region}/disks/repd-test-1"
    options = {
      mode         = null
      replica_zone = "${var.region}-c"
      type         = null
    }
  }]
  service_account_create = true
}
# tftest:modules=1:resources=2
```

And the same example for an instance template (where not using the full self link of the disk triggers recreation of the template)

```hcl
module "simple-vm-example" {
  source     = "./modules/compute-vm"
  project_id = var.project_id
  zone     = "${var.region}-b"
  name       = "test"
  network_interfaces = [{
    network    = var.vpc.self_link
    subnetwork = var.subnet.self_link
    nat        = false
    addresses  = null
    alias_ips  = null
  }]
  attached_disks = [{
    name        = "repd"
    size        = null
    source_type = "attach"
    source      = "https://www.googleapis.com/compute/v1/projects/${var.project_id}/regions/${var.region}/disks/repd-test-1"
    options = {
      mode        = null
      replica_zone = "${var.region}-c"
      type        = null
    }
  }]
  service_account_create = true
  create_template  = true
}
# tftest:modules=1:resources=2
```

### Disk encryption with Cloud KMS

This example shows how to control disk encryption via the the `encryption` variable, in this case the self link to a KMS CryptoKey that will be used to encrypt boot and attached disk. Managing the key with the `../kms` module is of course possible, but is not shown here.

```hcl
module "kms-vm-example" {
  source     = "./modules/compute-vm"
  project_id = var.project_id
  zone       = "europe-west1-b"
  name       = "kms-test"
  network_interfaces = [{
    network    = var.vpc.self_link
    subnetwork = var.subnet.self_link
    nat        = false
    addresses  = null
    alias_ips  = null
  }]
  attached_disks = [
    {
      name  = "attached-disk"
      size        = 10
      source      = null
      source_type = null
      options     = null
    }
  ]
  service_account_create = true
  boot_disk = {
    image        = "projects/debian-cloud/global/images/family/debian-10"
    type         = "pd-ssd"
    size         = 10
  }
  encryption = {
    encrypt_boot            = true
    disk_encryption_key_raw = null
    kms_key_self_link       = var.kms_key.self_link
  }
}
# tftest:modules=1:resources=3
```

### Using Alias IPs

This example shows how add additional [Alias IPs](https://cloud.google.com/vpc/docs/alias-ip) to your VM.

```hcl
module "vm-with-alias-ips" {
  source     = "./modules/compute-vm"
  project_id = "my-project"
  zone     = "europe-west1-b"
  name       = "test"
  network_interfaces = [{
    network    = var.vpc.self_link
    subnetwork = var.subnet.self_link
    nat        = false
    addresses  = null
    alias_ips = {
      alias1 = "10.16.0.10/32"
    }
  }]
  service_account_create = true
}
# tftest:modules=1:resources=2
```

### Instance template

This example shows how to use the module to manage an instance template that defines an additional attached disk for each instance, and overrides defaults for the boot disk image and service account.

```hcl
module "cos-test" {
  source     = "./modules/compute-vm"
  project_id = "my-project"
  zone     = "europe-west1-b"
  name       = "test"
  network_interfaces = [{
    network    = var.vpc.self_link
    subnetwork = var.subnet.self_link
    nat        = false
    addresses  = null
    alias_ips  = null
  }]
  boot_disk      = {
    image = "projects/cos-cloud/global/images/family/cos-stable"
    type  = "pd-ssd"
    size  = 10
  }
  attached_disks = [
    {
      name        = "disk-1"
      size        = 10
      source      = null
      source_type = null
      options     = null
    }
  ]
  service_account        = "vm-default@my-project.iam.gserviceaccount.com"
  create_template  = true
}
# tftest:modules=1:resources=1
```

### Instance group

If an instance group is needed when operating in instance mode, simply set the `group` variable to a non null map. The map can contain named port declarations, or be empty if named ports are not needed.

```hcl
locals {
  cloud_config = "my cloud config"
}

module "instance-group" {
  source     = "./modules/compute-vm"
  project_id = "my-project"
  zone     = "europe-west1-b"
  name       = "ilb-test"
  network_interfaces = [{
    network    = var.vpc.self_link
    subnetwork = var.subnet.self_link
    nat        = false
    addresses  = null
    alias_ips  = null
  }]
  boot_disk = {
    image = "projects/cos-cloud/global/images/family/cos-stable"
    type  = "pd-ssd"
    size  = 10
  }
  service_account        = var.service_account.email
  service_account_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  metadata = {
    user-data = local.cloud_config
  }
  group = { named_ports = {} }
}
# tftest:modules=1:resources=2
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 4.0.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | >= 4.0.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_attached_disk_defaults"></a> [attached\_disk\_defaults](#input\_attached\_disk\_defaults) | Defaults for attached disks options. | <pre>object({<br>    mode         = string<br>    replica_zone = string<br>    type         = string<br>  })</pre> | <pre>{<br>  "auto_delete": true,<br>  "mode": "READ_WRITE",<br>  "replica_zone": null,<br>  "type": "pd-balanced"<br>}</pre> | no |
| <a name="input_attached_disks"></a> [attached\_disks](#input\_attached\_disks) | Additional disks, if options is null defaults will be used in its place. Source type is one of 'image' (zonal disks in vms and template), 'snapshot' (vm), 'existing', and null. | <pre>list(object({<br>    name        = string<br>    size        = string<br>    source      = string<br>    source_type = string<br>    options = object({<br>      mode         = string<br>      replica_zone = string<br>      type         = string<br>    })<br>  }))</pre> | `[]` | no |
| <a name="input_boot_disk"></a> [boot\_disk](#input\_boot\_disk) | Boot disk properties. | <pre>object({<br>    image = string<br>    size  = number<br>    type  = string<br>  })</pre> | <pre>{<br>  "image": "debian-cloud/debian-12",<br>  "size": 10,<br>  "type": "pd-ssd"<br>}</pre> | no |
| <a name="input_boot_disk_delete"></a> [boot\_disk\_delete](#input\_boot\_disk\_delete) | Auto delete boot disk. | `bool` | `true` | no |
| <a name="input_can_ip_forward"></a> [can\_ip\_forward](#input\_can\_ip\_forward) | Enable IP forwarding. | `bool` | `false` | no |
| <a name="input_confidential_compute"></a> [confidential\_compute](#input\_confidential\_compute) | Enable Confidential Compute for these instances. | `bool` | `false` | no |
| <a name="input_create_template"></a> [create\_template](#input\_create\_template) | Create instance template instead of instances. | `bool` | `false` | no |
| <a name="input_description"></a> [description](#input\_description) | Description of a Compute Instance. | `string` | `"Managed by the compute-vm Terraform module."` | no |
| <a name="input_enable_display"></a> [enable\_display](#input\_enable\_display) | Enable virtual display on the instances | `bool` | `false` | no |
| <a name="input_encryption"></a> [encryption](#input\_encryption) | Encryption options. Only one of kms\_key\_self\_link and disk\_encryption\_key\_raw may be set. If needed, you can specify to encrypt or not the boot disk. | <pre>object({<br>    encrypt_boot            = bool<br>    disk_encryption_key_raw = string<br>    kms_key_self_link       = string<br>  })</pre> | `null` | no |
| <a name="input_group"></a> [group](#input\_group) | Define this variable to create an instance group for instances. Disabled for template use. | <pre>object({<br>    named_ports = map(number)<br>  })</pre> | `null` | no |
| <a name="input_hostname"></a> [hostname](#input\_hostname) | Instance FQDN name. | `string` | `null` | no |
| <a name="input_iam"></a> [iam](#input\_iam) | IAM bindings in {ROLE => [MEMBERS]} format. | `map(list(string))` | `{}` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | Instance type. | `string` | `"e2-small"` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Instance labels. | `map(string)` | `{}` | no |
| <a name="input_metadata"></a> [metadata](#input\_metadata) | Instance metadata. | `map(string)` | `{}` | no |
| <a name="input_metadata_startup_script"></a> [metadata\_startup\_script](#input\_metadata\_startup\_script) | Instance metadata startup script. | `string` | `null` | no |
| <a name="input_min_cpu_platform"></a> [min\_cpu\_platform](#input\_min\_cpu\_platform) | Minimum CPU platform. | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Instance name. | `string` | n/a | yes |
| <a name="input_network_interfaces"></a> [network\_interfaces](#input\_network\_interfaces) | Network interfaces configuration. Use self links for Shared VPC, set addresses and alias\_ips to null if not needed. | <pre>list(object({<br>    nat        = bool<br>    network    = string<br>    subnetwork = string<br>    addresses = object({<br>      internal = string<br>      external = string<br>    })<br>    alias_ips = map(string)<br>  }))</pre> | n/a | yes |
| <a name="input_options"></a> [options](#input\_options) | Instance options. | <pre>object({<br>    allow_stopping_for_update = bool<br>    deletion_protection       = bool<br>    preemptible               = bool<br>  })</pre> | <pre>{<br>  "allow_stopping_for_update": true,<br>  "deletion_protection": false,<br>  "preemptible": false<br>}</pre> | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project id. | `string` | n/a | yes |
| <a name="input_scratch_disks"></a> [scratch\_disks](#input\_scratch\_disks) | Scratch disks configuration. | <pre>object({<br>    count     = number<br>    interface = string<br>  })</pre> | <pre>{<br>  "count": 0,<br>  "interface": "NVME"<br>}</pre> | no |
| <a name="input_service_account"></a> [service\_account](#input\_service\_account) | Service account email. Unused if service account is auto-created. | `string` | `null` | no |
| <a name="input_service_account_create"></a> [service\_account\_create](#input\_service\_account\_create) | Auto-create service account. | `bool` | `false` | no |
| <a name="input_service_account_scopes"></a> [service\_account\_scopes](#input\_service\_account\_scopes) | Scopes applied to service account. | `list(string)` | <pre>[<br>  "cloud-platform"<br>]</pre> | no |
| <a name="input_shielded_config"></a> [shielded\_config](#input\_shielded\_config) | Shielded VM configuration of the instances. | <pre>object({<br>    enable_secure_boot          = bool<br>    enable_vtpm                 = bool<br>    enable_integrity_monitoring = bool<br>  })</pre> | <pre>{<br>  "enable_integrity_monitoring": true,<br>  "enable_secure_boot": true,<br>  "enable_vtpm": true<br>}</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Instance tags. | `list(string)` | `[]` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | Compute zone. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_external_ip"></a> [external\_ip](#output\_external\_ip) | Instance main interface external IP addresses. |
| <a name="output_group"></a> [group](#output\_group) | Instance group resource. |
| <a name="output_instance"></a> [instance](#output\_instance) | Instance resource. |
| <a name="output_internal_ip"></a> [internal\_ip](#output\_internal\_ip) | Instance main interface internal IP address. |
| <a name="output_self_link"></a> [self\_link](#output\_self\_link) | Instance self links. |
| <a name="output_service_account"></a> [service\_account](#output\_service\_account) | Service account resource. |
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Service account email. |
| <a name="output_service_account_iam_email"></a> [service\_account\_iam\_email](#output\_service\_account\_iam\_email) | Service account email. |
| <a name="output_template"></a> [template](#output\_template) | Template resource. |
| <a name="output_template_name"></a> [template\_name](#output\_template\_name) | Template name. |
<!-- END_TF_DOCS -->
