# Build a Puppet environment on Google cloud using Terraform

## Setup a project

https://cloud.google.com/resource-manager/docs/creating-managing-projects

## Setup authentication

Follow the steps in this document to setup a project, create a service account and a service account key.
https://learn.hashicorp.com/tutorials/terraform/google-cloud-platform-build?in=terraform/gcp-get-started#set-up-gcp

Create a json service account key save it somewhere safe **DO NOT COMMIT IT TO GIT.**

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

Make a copy of the variables file for yourself:

```
cp terraform-pe-environment/local.tfvars.example terraform-pe-environment/local.tfvars
```

Modify these variables to match your environment:

```terraform
# Where to find the GCP credentials that you downloaded (required)
credentials_file = "~/something.json"

# Name of your project (required)
project_name = "example"

# Path to your SSH public key (optional, default: "~/.ssh/id_rsa.pub")
ssh_pubkey_file = "~/.ssh/id_rsa.pub"

# Path to your SSH private key (optional, default: "~/.ssh/id_rsa")
ssh_privatekey_file = "~/.ssh/id_rsa"

# Number of your packer image
packer_number = "12345"
```

*I've used the service account name here but I don't think it matters, I think any random name would work, this just sets up a public/private key pair with your laptop*


From the `terraform-pe-environment` directory run `terraform init` and then `terraform apply -var-file=local.tfvars`.

When it's finished it should present you with two ip addresses, ssh to the pe server using `ssh <ssh name>@<ip>` and then `tail -f  /var/puppetbuild.log` to watch the build finish off. When it's done you can login to Puppet on `https://<ip>/auth/login?`.

