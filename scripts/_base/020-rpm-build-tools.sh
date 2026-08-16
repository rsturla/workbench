#!/usr/bin/env bash

set -euox pipefail

# Virtualisation and RPM/packaging tooling used for local development and
# building packages inside the workbench.
dnf install -y \
    qemu-system-x86 \
    qemu-img \
    libvirt-daemon-kvm \
    askalono-cli \
    go-vendor-tools
