# Build a Puppet environment on Google cloud using Terraform

## Setup a project

https://cloud.google.com/resource-manager/docs/creating-managing-projects

## Setup authentication

Follow the steps in this document to setup a project, create a service account and a service account key.
https://learn.hashicorp.com/tutorials/terraform/google-cloud-platform-build?in=terraform/gcp-get-started#set-up-gcp

Create a json service account key as and name it ```gcp.json```.

## Build a new packer image

The reason for building the packer image is that Terraform doesn't have a suitable method for pushing config files into VM's at build time. So we'll take an existing VM image that we would have used anyway and use packer to add the files to it and create a new custom image.
You'll need to fill in the ```packer-pe-server/id-control_repo.rsa``` file with whatever key you use to access the git repository holding your control-repo. 
Modify the ```packer-pe-server/pe.conf``` file and update the lines;

* "console_admin_password" with whatever combination of username and password you want.
* "puppet_enterprise::profile::master::r10k_remote" either the path to your own control-repo or use ```git@github.com:puppetlabs/control-repo.git```

Make sure the ```gcp.json``` file is in the root of the ```packer-pe-server``` directory.
Edit the ```packer-pe-server/peserver.json``` file updating the following with the relevant information.

```json
{
    "type": "googlecompute",
    "project_id": "<project name>",
    "source_image": "centos-7-v20210721",
    "ssh_username": "<service account name>",
    "zone": "<zone>",
    "account_file": "gcp.json"
}
```

From within the ```packer-pe-server``` directory, run ```packer verify peserver.json``` and then ```packer build peserver.json``` this will build the image and return an image name, something like ```packer-123456789```, copy this name, it needs adding to the terraform script later.

## Build the Environment

Make sure you have the ```gcp.json``` file in the ```terraform-pe-environment``` directory.
Edit the ```terraform-pe-environment/main.tf``` and fill out the relevant project info;

```ruby
provider "google" {
  credentials = file("gcp.json")
  project     = "<project name>"
  region      = "<region>"
  zone        = "<zone>"
}
```

In the same file edit the ssh key info to add the an account name, you'll need to do this in two different places.

```ruby
metadata = {
  ssh-keys = "<ssh name>:${file("~/.ssh/id_rsa.pub")}"
}
```

*I've used the service account name here but I don't think it matters, I think any random name would work, this just sets up a public/private key pair with your laptop*

Hopefully you haven't lost the packer image name, it goes in here;

```ruby
boot_disk {
  initialize_params {
    image = "<packer-number>"
  }
}
```

From the ```terraform-pe-environment``` directory run ```teerraform init``` and then ```terraform apply```.

When it's finished it should present you with two ip addresses, ssh to the pe server using ```ssh <ssh name>@<ip>``` and then ```tail -f  /var/puppetbuild.log``` to watch the build finish off. When it's done you can login to Puppet on ```https://<ip>/auth/login?```.

