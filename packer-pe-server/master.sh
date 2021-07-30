#!/usr/bin/env bash

sudo yum -y install wget

# Install Puppet -  ToDo - we should probably handle .tar.gz files rather then presume it'll all be uncompressed.
wget --content-disposition 'https://pm.puppet.com/cgi-bin/download.cgi?dist=el&rel=7&arch=x86_64&ver=latest'
#
gunzip puppet-enterprise-*.tar.gz
tar -xvf puppet-enterprise-*.tar
cd puppet-enterprise-*
sudo ./puppet-enterprise-installer -c /var/tmp/pe.conf
cd ..

# Autosign local agents - probably don't need this anymore.
sudo cp /var/tmp/autosign.conf /etc/puppetlabs/puppet/autosign.conf

# Copy over the code manager private key 
sudo cp /var/tmp/id-control_repo.rsa /etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa
sudo chown pe-puppet:pe-puppet /etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa

# Run Puppet a couple of times to straighten itself out. 
sudo /usr/local/bin/puppet agent -t || true
sudo /usr/local/bin/puppet agent -t || true

