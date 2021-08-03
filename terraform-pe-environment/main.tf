variable "credentials_file" {
  type = string
}

variable "project_name" {
  type = string
}

variable "region" {
  type = string
  default = "europe-west2"
}

variable "zone" {
  type = string
  default = "europe-west2-c"
}

variable "ssh_username" {
  type    = string
  default = "puppet-ps"
}

variable "ssh_pubkey_file" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.5.0"
    }
  }
}

// Setup google
provider "google" {
  credentials = file(var.credentials_file)
  project     = var.project_name
  region      = var.region
  zone        = var.zone
}

// Terraform plugin for creating random ids
resource "random_id" "instance_id" {
 byte_length = 8
}

// Setup network ports
resource "google_compute_firewall" "pe-firewall" {
 name    = "pe-firewall"
 network = "default"

 allow {
   protocol = "tcp"
   ports    = ["8140", "8142", "80", "8080", "443", "4433", "22"]
 }
}

resource "google_compute_firewall" "pam-firewall" {
 name    = "pam-firewall"
 network = "default"

 // Data from: https://puppet.com/docs/continuous-delivery/4.x/pam/pam-node-arch.html

 allow {
   protocol = "tcp"
   ports    = [
    "80",    // Web ports
    "443",   // Web ports
    "6443",  // k8s API
    "8800",  // kotsadm console
    "22",    // ssh
    "2379",  // backplane
    "2380",  // backplane
    "10250", // backplane
    "6783",  // backplane
  ]
 }

 allow {
   protocol = "udp"
   ports = ["6783"] // backplane
 }
}

# // PE node
# resource "google_compute_instance" "pe" {
#   name         = "pe-${random_id.instance_id.hex}"
#   machine_type = "e2-standard-4"
#   tags         = ["puppet", "enterprise"]
   
#   metadata = {
#     ssh-keys = "<ssh name>:${file("~/.ssh/id_rsa.pub")}"
#   }

#   metadata_startup_script = "sudo chmod +x /var/tmp/master.sh; sudo /var/tmp/master.sh > /var/puppetbuild.log"

#   boot_disk {
#     initialize_params {
#       image = "<packer-number>"
#     }
#   }

#   network_interface {
#     network = "default"
#     access_config {
#      // Include this section to give the VM an external ip address
#     }
#   }
# }

# // PE node
# resource "google_compute_instance" "node1" {
#   name         = "node1-${random_id.instance_id.hex}"
#   machine_type = "e2-small"
#   tags         = ["puppet", "target"]
   
#   metadata = {
#     ssh-keys = "<ssh name>:${file("~/.ssh/id_rsa.pub")}"
#   }

#   boot_disk {
#     initialize_params {
#       image = "centos-cloud/centos-7"
#     }
#   }

#   network_interface {
#     network = "default"
#     access_config {
#      // Include this section to give the VM an external ip address
#     }
#   }
# }

resource "google_compute_disk" "ceph-storage" {
  count = 3
  name  = "ceph-${count.index}"
  type  = "pd-standard"
  zone  = var.zone
  size  = 50
}
resource "google_compute_attached_disk" "ceph-storage-attach" {
  count       = 3
  disk        = google_compute_disk.ceph-storage[count.index].id
  instance    = google_compute_instance.pam-primary[count.index].id
  device_name = "ceph"
}

resource "google_compute_instance" "pam-primary" {
  count        = 3
  name         = "pam-primary-${count.index}"
  machine_type = "e2-standard-4"
  tags         = ["pam"]

  metadata = {
    ssh-keys = "${var.ssh_username}:${file(var.ssh_pubkey_file)}"
  }

  // Create the boot disk
  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-8"
    }
    auto_delete = true
  }

  lifecycle {
    ignore_changes = [attached_disk]
  }

  network_interface {
    network = "default"
    access_config {
     // Include this section to give the VM an external ip address
    }
  }
}