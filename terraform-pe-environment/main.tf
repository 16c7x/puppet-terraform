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
  credentials = file("gcp.json")
  project     = "<project name>"
  region      = "<region>"
  zone        = "<zone>"
}

// Terraform plugin for creating random ids
resource "random_id" "instance_id" {
 byte_length = 8
}

// Setup network ports
resource "google_compute_firewall" "default" {
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
    ssh-keys = "<ssh name>:${file("~/.ssh/id_rsa.pub")}"
  }

  metadata_startup_script = "sudo chmod +x /var/tmp/master.sh; sudo /var/tmp/master.sh > /var/puppetbuild.log"

  boot_disk {
    initialize_params {
      image = "<packer-number>"
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
    ssh-keys = "<ssh name>:${file("~/.ssh/id_rsa.pub")}"
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
