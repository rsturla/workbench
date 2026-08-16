#!/usr/bin/env bash

set -euox pipefail

# Assign chunkah xattr components to non-RPM files so they get merged into
# the correct RPM component layers during rechunking. Files owned by RPMs are
# already handled by chunkah's rpmdb component; this script covers cross-cutting
# content generated at install time that should land in the same layer as the
# RPM that produced it.

# ── Kernel modules ────────────────────────────────────────────────────────
# The .ko.xz files are RPM-owned (kernel-core, kernel-modules, etc.) but dracut
# generates initramfs and other files at install time which are unowned by RPM.
# Tag the entire /usr/lib/modules tree so they merge into the rpm/kernel
# component.
for kdir in /usr/lib/modules/*/; do
  setfattr -n user.component -v "rpm/kernel" "$kdir"
  find "$kdir" -mindepth 1 -exec setfattr -n user.component -v "rpm/kernel" {} \;
done

# ── SELinux compiled policy ───────────────────────────────────────────────
# The compiled policy modules under /etc/selinux are generated at install time
# by selinux-policy-targeted. They all change together when the selinux-policy
# SRPM is updated.
setfattr -n user.component -v "rpm/selinux-policy" /etc/selinux
find /etc/selinux -mindepth 1 -exec setfattr -n user.component -v "rpm/selinux-policy" {} \;
