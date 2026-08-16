#!/usr/bin/env bash

set -euox pipefail

dnf install -y \
    awk \
    bwrap \
    pkgconf-pkg-config \
    git \
    make \
    gcc \
    curl \
    tar \
    unzip \
    openssl-devel \
    patch \
    createrepo_c \
    just \
    fzf \
    zsh \
    ripgrep \
    socat \
    direnv \
    qemu-guest-agent

# Remove just docs (contains non-ASCII filenames that break ostree deployment)
rm -rf /usr/share/doc/just
