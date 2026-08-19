# Workbench

An immutable Fedora development environment with batteries included.

## Overview

An image-based development workstation built on [Fedora bootc](https://docs.fedoraproject.org/en-US/bootc/). It provides a consistent, reproducible development environment with pre-configured tools for cloud-native development.

**Container Image:** `quay.io/rsturla-dev/workbench`

## Features

- **Atomic Base** — Built on Fedora bootc for atomic updates and rollbacks
- **ZSH Shell** — Pre-configured with oh-my-zsh, autosuggestions, and syntax highlighting
- **Docker** — Full Docker CE installation with BuildKit and Compose
- **Homebrew** — Linux Homebrew for user-space package management
- **direnv** — Automatic environment variable loading per directory
- **Google Cloud CLI** — Ready for GCP development
- **Git Worktree Utilities** — Custom scripts for portable worktree workflows

## Included Tools

### System Packages

- `git`, `make`, `gcc` — Build essentials
- `just` — Modern command runner
- `fzf` — Fuzzy finder
- `ripgrep` — Fast recursive search
- `direnv` — Per-directory environment management
- `zsh` — Default shell with oh-my-zsh

### Homebrew Packages

Managed via `/usr/share/homebrew/Brewfile` and `/etc/homebrew/Brewfile`:

- `awscli` — AWS command-line interface
- `claude-code` — Claude AI coding assistant

### Git Wrapper Scripts

Located in `/usr/bin/`:

| Command | Description |
|---------|-------------|
| `git-bootstrap` | Initialize a new repository (optionally with worktree setup) |
| `git-web` | Open files/commits in GitHub from the terminal |
| `git-worktree-add` | Add worktrees with portable relative paths |
| `git-worktree-clone` | Clone repositories with bare git + worktree structure |

## Building

Requires: `podman`, `just`

```bash
# Build the container image
just build

# Push to registry
just push

# Build a qcow2 disk image for VMs
just build-qcow2

# Build a raw disk image
just build-raw

# Build an installer ISO
just build-iso
```

## Running

### With libvirt/virt-manager

```bash
just run-vm
```

Creates a VM with Secure Boot enabled. Connect via `virt-manager` or:

```bash
virsh console workbench
```

### With QEMU directly

```bash
just run-qemu
```

Runs with Secure Boot in the terminal (serial console).

### VM Management

```bash
just stop-vm    # Stop the running VM
just delete-vm  # Remove VM and its configuration
just clean      # Remove all build artifacts
```

## Default User

| Field | Value |
|-------|-------|
| Username | `admin` |
| Groups | `wheel`, `docker` |

## Customization

### Adding System Packages

Build logic lives in numbered scripts under `scripts/_base/`, run in order by
`scripts/setup.sh` during the image build. To add packages, edit the relevant
script (e.g. `scripts/_base/010-base-packages.sh`) or add a new numbered
script. Static configuration files ship under `files/` and are copied verbatim
into the image root.

### Adding Homebrew Packages

Edit `/etc/homebrew/Brewfile` to add system-wide Homebrew packages.

Homebrew updates are managed by systemd timers:
- `brew-update.timer` — Updates Homebrew formulae
- `brew-upgrade.timer` — Upgrades installed packages
- `brew-cleanup.timer` — Cleans outdated cache
- `brew-bundle.service` — Installs packages from Brewfiles

### Customizing ZSH

The default `.zshrc` is installed from `/etc/skel/.zshrc`. Users can customize their own `~/.zshrc` after login.

### AI agent configuration

Managed agent instructions and skills ship read-only under
`/usr/share/workbench/agents/` and are versioned with the image. On every login,
`user-tmpfiles.d` projects them into each user's home, so existing users pick up
updates when the image changes (unlike `/etc/skel`, which only applies at user
creation):

- `~/AGENTS.md` and `~/.claude/CLAUDE.md` → the managed instructions
- `~/.agents/skills/<name>` → individual managed skills (`asd-ste100`, `unslop`,
  `writing-pull-requests`), with `~/.claude/skills` pointing at the same directory

The skills directory itself is writable, so users can install their own skills
alongside the managed ones. Personal Claude Code instructions can be added under
`~/.claude/rules/` without affecting the managed baseline.

## CI/CD

The image is automatically built and pushed to `quay.io/rsturla-dev/workbench` via GitHub Actions:

- **Triggers:** Push to main, weekly schedule, manual dispatch
- **Tags:** `latest`, `YYYYMMDD` (date), short commit SHA
- **Rechunking:** Final image is split into component-aligned OCI layers with
  [chunkah](https://github.com/coreos/chunkah) for efficient delta updates
- **Supply chain:** Images are signed with cosign and ship an SBOM (SPDX)
  attestation generated from the locally-built image
- **Workflows:** `build.yml` (build/push/sign), `pre-commit.yml` (lint), and
  `renovate.yml` (config validation)

Run the linters locally before pushing:

```bash
pre-commit run --all-files
```

## License

See individual components for their respective licenses.
