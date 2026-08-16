#!/usr/bin/env bash

set -euox pipefail

# Enable core system services
systemctl enable sshd.service
systemctl enable qemu-guest-agent.service
systemctl enable libvirtd.service
