FROM quay.io/fedora/fedora-bootc:latest AS build

COPY files/ /

RUN --mount=type=cache,target=/var/cache \
    --mount=type=tmpfs,target=/var \
    --mount=type=tmpfs,target=/tmp \
    --mount=type=tmpfs,target=/run \
    <<EOF
set -euox pipefail

dnf install -y \
    awk \
    pkgconf-pkg-config \
    git \
    make \
    gcc \
    curl \
    tar \
    unzip \
    openssl-devel \
    just \
    fzf \
    zsh \
    ripgrep \
    socat \
    direnv \
    qemu-guest-agent

# Remove just docs (contains non-ASCII filenames that break ostree deployment)
rm -rf /usr/share/doc/just
EOF

RUN --mount=type=cache,target=/var/cache \
    --mount=type=tmpfs,target=/var \
    --mount=type=tmpfs,target=/tmp \
    --mount=type=tmpfs,target=/run \
    <<EOF
set -euox pipefail

dnf install -y \
    qemu-system-x86 \
    qemu-img \
    libvirt-daemon-kvm \
    mock \
    rpmdevtools \
    askalono-cli \
    go-vendor-tools \
    packit
EOF

# Install oh-my-zsh system-wide
RUN --mount=type=cache,target=/var/cache \
    --mount=type=tmpfs,target=/var \
    --mount=type=tmpfs,target=/tmp \
    --mount=type=tmpfs,target=/run \
    <<EOF
set -euox pipefail

# Install oh-my-zsh to /usr/share/oh-my-zsh
git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git /usr/share/oh-my-zsh

# Install zsh-autosuggestions plugin
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git \
    /usr/share/oh-my-zsh/custom/plugins/zsh-autosuggestions

# Install zsh-syntax-highlighting plugin
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git \
    /usr/share/oh-my-zsh/custom/plugins/zsh-syntax-highlighting

# Remove .git directories to save space
find /usr/share/oh-my-zsh -name '.git' -type d -exec rm -rf {} + 2>/dev/null || true
EOF

# Install Google Cloud CLI
RUN --mount=type=cache,target=/var/cache \
    --mount=type=tmpfs,target=/var \
    --mount=type=tmpfs,target=/tmp \
    --mount=type=tmpfs,target=/run \
    <<EOF
set -euox pipefail

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
EOF

# Install Docker
RUN --mount=type=cache,target=/var/cache \
    --mount=type=tmpfs,target=/var \
    --mount=type=tmpfs,target=/tmp \
    --mount=type=tmpfs,target=/run \
    <<EOF
set -euox pipefail

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
EOF

# Install Homebrew
RUN --mount=type=cache,target=/var/cache \
    --mount=type=tmpfs,target=/var \
    --mount=type=tmpfs,target=/tmp \
    --mount=type=tmpfs,target=/run \
    <<EOF
set -euox pipefail

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
EOF

# Enable services
RUN --mount=type=tmpfs,target=/run \
    <<EOF
set -euox pipefail

systemctl enable sshd.service
systemctl enable qemu-guest-agent.service
systemctl enable libvirtd.service
EOF

# Tag non-RPM files with chunkah xattr components so they land in the correct
# RPM component layers during rechunking.
RUN --mount=type=tmpfs,target=/run \
    <<EOF
set -euox pipefail

# Kernel modules — dracut generates initramfs and other files at install time
# which are unowned by RPM. Tag the entire /usr/lib/modules tree so they merge
# into the rpm/kernel component.
for kdir in /usr/lib/modules/*/; do
  setfattr -n user.component -v "rpm/kernel" "$kdir"
  find "$kdir" -mindepth 1 -exec setfattr -n user.component -v "rpm/kernel" {} \;
done

# SELinux compiled policy — generated at install time by selinux-policy-targeted.
# All change together when the selinux-policy SRPM is updated.
setfattr -n user.component -v "rpm/selinux-policy" /etc/selinux
find /etc/selinux -mindepth 1 -exec setfattr -n user.component -v "rpm/selinux-policy" {} \;
EOF

RUN bootc container lint

# Rechunk the image into component-aligned OCI layers via chunkah.
# Build must use --skip-unused-stages=false for the oci-archive stage to work.
# See https://github.com/coreos/chunkah#splitting-an-image-at-build-time-buildahpodman-only
FROM quay.io/coreos/chunkah:dev AS chunkah
RUN --mount=from=build,src=/,target=/chunkah,ro \
  chunkah build \
  --prune /sysroot/ \
  --max-layers 448 \
  > /run/src/out.ociarchive

FROM oci-archive:out.ociarchive

LABEL containers.bootc=1
LABEL ostree.bootable=true
