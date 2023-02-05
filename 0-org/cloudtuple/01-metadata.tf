
# hub

resource "google_compute_project_metadata" "hub_metadata" {
  project = data.google_project.hub.project_id
  metadata = {
    ssh-keys       = "user:${file(var.public_key_path)}"
    VmDnsSetting   = "ZonalPreferred"
    enable-oslogin = true
  }
}

# spoke1

resource "google_compute_project_metadata" "spoke1_metadata" {
  project = data.google_project.spoke1.project_id
  metadata = {
    ssh-keys       = "user:${file(var.public_key_path)}"
    VmDnsSetting   = "ZonalPreferred"
    enable-oslogin = true
  }
}

# spoke2

resource "google_compute_project_metadata" "spoke2_metadata" {
  project = data.google_project.spoke2.project_id
  metadata = {
    ssh-keys       = "user:${file(var.public_key_path)}"
    VmDnsSetting   = "ZonalPreferred"
    enable-oslogin = true
  }
}
