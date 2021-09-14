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

variable "ssh_privatekey_file" {
  type    = string
  default = "~/.ssh/id_rsa"
}

variable "packer_number" {
  type    = string
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


// PE node
resource "google_compute_instance" "pe" {
  name         = "pe-${random_id.instance_id.hex}"
  machine_type = "e2-standard-4"
  tags         = ["puppet", "enterprise"]
   
  metadata = {
    ssh-keys = "${var.ssh_username}:${file(var.ssh_pubkey_file)}"
  }

  metadata_startup_script = "sudo chmod +x /var/tmp/master.sh; sudo /var/tmp/master.sh > /var/puppetbuild.log"

  boot_disk {
    initialize_params {
      image = var.packer_number
    }
  }

  network_interface {
    network = "default"
    access_config {
     // Include this section to give the VM an external ip address
    }
  }
}

// PE node
resource "google_compute_instance" "node1" {
  name         = "node1-${random_id.instance_id.hex}"
  machine_type = "e2-small"
  tags         = ["puppet", "target"]
   
  metadata = {
    ssh-keys = "${var.ssh_username}:${file(var.ssh_pubkey_file)}"
  }

  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-7"
    }
  }

  network_interface {
    network = "default"
    access_config {
     // Include this section to give the VM an external ip address
    }
  }
}


//
// Puppet Application Manager
//

// This is currently able to do the following:
//
// * Create servers to run PAM
// * Create firewall rules
// * Attach additional storage to servers for ceph
// * Create an instance group & health checks for load balancing
// * Install Pam in machine number 0
//
// However in order to be complete we will need to add:
//
// * Actually creating a load balancer and the working out how to tell PAM about
//   it (currently there is a placeholder in config.yaml)
// * Installing other masters
// * Installing apps on top of PAM and configuring them
//

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

resource "google_compute_instance_group" "pam-servers" {
  name        = "pam-servers"
  description = "Servers running PAM"

  // TODO: Make this dynamic
  instances = [
    google_compute_instance.pam-primary[0].self_link,
    google_compute_instance.pam-primary[1].self_link,
    google_compute_instance.pam-primary[2].self_link,
  ]

  named_port {
    name = "http"
    port = "80"
  }

  named_port {
    name = "https"
    port = "443"
  }

  named_port {
    name = "k8s-api"
    port = "6443"
  }

  zone = var.zone
}

resource "google_compute_health_check" "k8s-api-health" {
  name        = "k8s-api-health"
  description = "Checks that k8s is running"

  https_health_check {
    port         = "6443"
    request_path = "/livez"
  }
}

resource "google_compute_health_check" "https-health" {
  name        = "https-health"
  description = "Checks a https server is running"

  https_health_check {
    port = "443"
  }
}

resource "google_compute_instance" "pam-primary" {
  count        = 3
  name         = "pam-primary-${count.index}"
  machine_type = "e2-standard-4"
  tags         = ["pam"]

  metadata = {
    ssh-keys = "${var.ssh_username}:${file(var.ssh_pubkey_file)}"
  }

  connection {
    type        = "ssh"
    user        = "${var.ssh_username}"
    private_key = "${file(var.ssh_privatekey_file)}"
    host        = "${self.network_interface[0].access_config[0].nat_ip}"
  }

  provisioner "file" {
    source      = "pam-config/config.yaml"
    destination = "/tmp/config.yaml"
  }

  provisioner "file" {
    source      = "pam-config/install.sh"
    destination = "/tmp/install.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install.sh",
      "/tmp/install.sh",
    ]
  }

  // Create the boot disk
  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-8"
      type  = "pd-standard"
      size  = 100
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