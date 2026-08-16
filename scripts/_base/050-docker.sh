#!/usr/bin/env bash

set -euox pipefail

# Install Docker CE
cat > /etc/yum.repos.d/docker-ce.repo << 'REPO'
[docker-ce-stable]
name=Docker CE Stable
baseurl=https://download.docker.com/linux/fedora/$releasever/$basearch/stable
enabled=0
gpgcheck=1
gpgkey=https://download.docker.com/linux/fedora/gpg

[docker-ce-testing]
name=Docker CE Testing
baseurl=https://download.docker.com/linux/fedora/$releasever/$basearch/test
enabled=0
gpgcheck=1
gpgkey=https://download.docker.com/linux/fedora/gpg
REPO

DOCKER_REPO=stable

dnf install -y --enablerepo=docker-ce-$DOCKER_REPO \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin \
  docker-model-plugin

systemctl enable docker.socket

rm -f /etc/yum.repos.d/docker-ce.repo

cat > /usr/lib/sysusers.d/docker.conf << SYSUSERS
g docker -
SYSUSERS
