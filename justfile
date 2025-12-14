# Image settings
image_registry := "quay.io/rsturla-dev"
image_name := "workbench"
image_tag := "latest"
image_ref := image_registry + "/" + image_name + ":" + image_tag
installer_ref := image_registry + "/" + image_name + "-installer:" + image_tag

# Output settings
output_dir := "output"

# Build the container image (rootless)
build:
    podman build -t {{ image_ref }} --iidfile /tmp/image.id -f Contianerfile --no-cache .

# Build the installer container image (rootless)
build-installer:
    podman build -t {{ installer_ref }} -f Containerfile.installer .

# Transfer image from rootless to rootful storage (only if not already present or outdated)
_transfer-image:
    #!/usr/bin/env bash
    set -euo pipefail
    LOCAL_ID=$(podman image inspect --format '{{{{.Id}}}}' {{ image_ref }} 2>/dev/null || echo "")
    ROOT_ID=$(sudo podman image inspect --format '{{{{.Id}}}}' {{ image_ref }} 2>/dev/null || echo "")
    if [[ "$LOCAL_ID" != "$ROOT_ID" ]]; then
        echo "Transferring image to root storage..."
        podman image scp $USER@localhost::{{ image_ref }} root@localhost::
    else
        echo "Image already in root storage, skipping transfer."
    fi

# Transfer installer image from rootless to rootful storage
_transfer-installer-image:
    #!/usr/bin/env bash
    set -euo pipefail
    LOCAL_ID=$(podman image inspect --format '{{{{.Id}}}}' {{ installer_ref }} 2>/dev/null || echo "")
    ROOT_ID=$(sudo podman image inspect --format '{{{{.Id}}}}' {{ installer_ref }} 2>/dev/null || echo "")
    if [[ "$LOCAL_ID" != "$ROOT_ID" ]]; then
        echo "Transferring installer image to root storage..."
        podman image scp $USER@localhost::{{ installer_ref }} root@localhost::
    else
        echo "Installer image already in root storage, skipping transfer."
    fi

# Build a QEMU qcow2 disk image from the bootc container
build-qcow2: build _transfer-image
    mkdir -p {{ output_dir }}
    sudo podman run \
        --rm \
        --privileged \
        --pull=newer \
        --security-opt label=type:unconfined_t \
        -v ./{{ output_dir }}:/output \
        -v ./config.toml:/config.toml:ro \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        ghcr.io/osbuild/image-builder-cli \
        build qcow2 \
        --bootc-ref {{ image_ref }} \
        --bootc-default-fs ext4 \
        --blueprint /config.toml \
        --output-dir /output
    sudo chown -R $(id -u):$(id -g) {{ output_dir }}

# Build a raw disk image from the bootc container
build-raw: build _transfer-image
    mkdir -p {{ output_dir }}
    sudo podman run \
        --rm \
        --privileged \
        --pull=newer \
        --security-opt label=type:unconfined_t \
        -v ./{{ output_dir }}:/output \
        -v ./config.toml:/config.toml:ro \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        ghcr.io/osbuild/image-builder-cli \
        build raw \
        --bootc-ref {{ image_ref }} \
        --bootc-default-fs ext4 \
        --blueprint /config.toml \
        --output-dir /output
    sudo chown -R $(id -u):$(id -g) {{ output_dir }}

# Build an ISO from the bootc container
build-iso: build build-installer _transfer-image _transfer-installer-image
    mkdir -p {{ output_dir }}
    sudo podman run \
        --rm \
        --privileged \
        --pull=newer \
        --security-opt label=type:unconfined_t \
        -v ./{{ output_dir }}:/output \
        -v ./config.toml:/config.toml:ro \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        ghcr.io/osbuild/image-builder-cli \
        build bootc-installer \
        --bootc-ref {{ installer_ref }} \
        --bootc-installer-payload-ref {{ image_ref }} \
        --bootc-default-fs ext4 \
        --blueprint /config.toml \
        --output-dir /output
    sudo chown -R $(id -u):$(id -g) {{ output_dir }}

# VM settings
vm_name := "workbench"
vm_memory := "4096"
vm_cpus := "2"
ssh_port := "2222"

# Run the qcow2 image in virt-manager/libvirt with Secure Boot
run-vm:
    #!/usr/bin/env bash
    set -euo pipefail
    DISK=$(find {{ output_dir }} -name "*.qcow2" | head -1)
    if [[ -z "$DISK" ]]; then
        echo "No qcow2 image found in {{ output_dir }}. Run 'just build-qcow2' first."
        exit 1
    fi
    # Remove existing VM if present
    virsh destroy {{ vm_name }} 2>/dev/null || true
    virsh undefine {{ vm_name }} --nvram 2>/dev/null || true
    # Create VM with Secure Boot
    virt-install \
        --name {{ vm_name }} \
        --memory {{ vm_memory }} \
        --vcpus {{ vm_cpus }} \
        --disk path="$DISK",format=qcow2 \
        --import \
        --os-variant fedora-unknown \
        --boot uefi,firmware.feature0.name=secure-boot,firmware.feature0.enabled=yes \
        --network default \
        --graphics spice \
        --noautoconsole
    echo "VM '{{ vm_name }}' started. Use 'virt-manager' or 'virsh console {{ vm_name }}' to connect."

# Run the qcow2 image directly with qemu-system (Secure Boot)
run-qemu:
    #!/usr/bin/env bash
    set -euo pipefail
    DISK=$(find {{ output_dir }} -name "*.qcow2" | head -1)
    if [[ -z "$DISK" ]]; then
        echo "No qcow2 image found in {{ output_dir }}. Run 'just build-qcow2' first."
        exit 1
    fi
    # Create a copy of OVMF vars for this VM
    OVMF_CODE="/usr/share/edk2/ovmf/OVMF_CODE.secboot.fd"
    OVMF_VARS="/usr/share/edk2/ovmf/OVMF_VARS.secboot.fd"
    VARS_COPY="{{ output_dir }}/OVMF_VARS.fd"
    cp "$OVMF_VARS" "$VARS_COPY"
    qemu-system-x86_64 \
        -enable-kvm \
        -cpu host \
        -m {{ vm_memory }} \
        -smp {{ vm_cpus }} \
        -machine q35,smm=on \
        -global driver=cfi.pflash01,property=secure,value=on \
        -drive if=pflash,format=raw,unit=0,file="$OVMF_CODE",readonly=on \
        -drive if=pflash,format=raw,unit=1,file="$VARS_COPY" \
        -drive file="$DISK",format=qcow2,if=virtio \
        -nic user,model=virtio-net-pci,hostfwd=tcp::{{ ssh_port }}-:22 \
        -nographic \
        -serial mon:stdio

# SSH into the QEMU VM (via port forward)
ssh-qemu:
    ssh -i keys/admin -p {{ ssh_port }} -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null admin@localhost

# SSH into the libvirt VM
ssh:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! virsh domstate {{ vm_name }} &>/dev/null; then
        echo "VM '{{ vm_name }}' does not exist. Run 'just build-qcow2 && just run-vm' first."
        exit 1
    fi
    STATE=$(virsh domstate {{ vm_name }})
    if [[ "$STATE" != "running" ]]; then
        echo "VM '{{ vm_name }}' is not running (state: $STATE). Run 'just run-vm' first."
        exit 1
    fi
    VM_IP=$(virsh domifaddr {{ vm_name }} | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
    if [[ -z "$VM_IP" ]]; then
        echo "Could not get IP for VM '{{ vm_name }}'. The VM may still be booting - try again in a few seconds."
        exit 1
    fi
    ssh -i keys/admin -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null admin@"$VM_IP"

# Get the VM IP address
vm-ip:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! virsh domstate {{ vm_name }} &>/dev/null; then
        echo "VM '{{ vm_name }}' does not exist. Run 'just build-qcow2 && just run-vm' first."
        exit 1
    fi
    STATE=$(virsh domstate {{ vm_name }})
    if [[ "$STATE" != "running" ]]; then
        echo "VM '{{ vm_name }}' is not running (state: $STATE). Run 'just run-vm' first."
        exit 1
    fi
    VM_IP=$(virsh domifaddr {{ vm_name }} | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
    if [[ -z "$VM_IP" ]]; then
        echo "Could not get IP for VM '{{ vm_name }}'. The VM may still be booting - try again in a few seconds."
        exit 1
    fi
    echo "$VM_IP"

# Stop the VM
stop-vm:
    virsh destroy {{ vm_name }} || true

# Delete the VM
delete-vm:
    virsh destroy {{ vm_name }} 2>/dev/null || true
    virsh undefine {{ vm_name }} --nvram 2>/dev/null || true

# Clean build artifacts
clean:
    rm -rf {{ output_dir }}

# List available image types
list-types:
    podman run --rm ghcr.io/osbuild/image-builder-cli list
