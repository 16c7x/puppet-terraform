#!/bin/bash

HOSTNAME=$(hostname)

if [[ "$HOSTNAME" == "pam-primary-0" ]]; then
  echo "On the first primary. Installing PAM..."
  curl -sSL https://k8s.kurl.sh/puppet-application-manager | sudo bash -s installer-spec-file=/tmp/config.yaml yes
else
  echo "Wrong node, exiting"
fi
