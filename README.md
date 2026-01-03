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

Edit the `Contianerfile` and add packages to the `dnf install` commands.

### Adding Homebrew Packages

Edit `/etc/homebrew/Brewfile` to add system-wide Homebrew packages.

Homebrew updates are managed by systemd timers:
- `brew-update.timer` — Updates Homebrew formulae
- `brew-upgrade.timer` — Upgrades installed packages
- `brew-cleanup.timer` — Cleans outdated cache
- `brew-bundle.service` — Installs packages from Brewfiles

### Customizing ZSH

The default `.zshrc` is installed from `/etc/skel/.zshrc`. Users can customize their own `~/.zshrc` after login.

## CI/CD

The image is automatically built and pushed to `quay.io/rsturla-dev/workbench` via GitHub Actions:

- **Triggers:** Push to main, weekly schedule, manual dispatch
- **Tags:** `latest`, `YYYYMMDD` (date), short commit SHA

## License

See individual components for their respective licenses.
