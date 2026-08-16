#!/usr/bin/env bash

set -euox pipefail

# Install Google Cloud CLI
cat > /etc/yum.repos.d/google-cloud-sdk.repo << REPO
[google-cloud-cli]
name=Google Cloud CLI
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el9-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
REPO

dnf install -y google-cloud-cli

rm -rf /etc/yum.repos.d/google-cloud-sdk.repo
