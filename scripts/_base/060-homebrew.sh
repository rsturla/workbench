#!/usr/bin/env bash

set -euox pipefail

# Install Homebrew (Linuxbrew) into the image, snapshotted to a tarball that
# brew-setup.service unpacks on first boot.

# /home and /root are symlinks to /var/home and /var/roothome respectively,
# but /var is a tmpfs mount so we need to create these for the symlinks to resolve
mkdir -p /var/home /var/roothome

# Install Brew dependencies
dnf install -y procps-ng file

# Convince the installer we are in CI
touch /.dockerenv

# Brew Install Script
curl -fsSL -o /tmp/brew-install https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
chmod +x /tmp/brew-install
/tmp/brew-install
tar --zstd -cf /usr/share/homebrew.tar.zst /var/home/linuxbrew/.linuxbrew

# Clean up
rm -rf /.dockerenv

# Create linuxbrew user/group via sysusers.d
cat > /usr/lib/sysusers.d/linuxbrew.conf << 'SYSUSERS'
u linuxbrew - "Homebrew" /var/home/linuxbrew /sbin/nologin
SYSUSERS

# Create directories via tmpfiles.d
cat > /usr/lib/tmpfiles.d/homebrew.conf << 'TMPFILES'
d /var/home/linuxbrew 0755 linuxbrew linuxbrew - -
TMPFILES

semanage fcontext -a -t usr_t "/var/home/linuxbrew/.linuxbrew(/.*)?"

# Enable Systemd services
systemctl enable brew-setup.service
systemctl enable brew-upgrade.timer
systemctl enable brew-update.timer
systemctl enable brew-cleanup.timer
systemctl enable brew-bundle.service
