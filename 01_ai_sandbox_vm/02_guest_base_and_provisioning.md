---
status: draft
---

# Phase 2 - Guest: base VM and provisioning

## Overview

Create the real VM and the script that makes it. After this phase the VM can be
deleted and rebuilt from the base image with one command, with projects and
caches surviving. The GPU stays out of it; the VM is CPU-only here.
Context: [`00_start.md`](00_start.md), depends on
[`01_host_incus_and_network.md`](01_host_incus_and_network.md).

## Goals

1. An Incus profile that describes the VM: size, network, disks.
2. Two persistent volumes, projects and caches, that outlive the instance.
3. A cloud-init file that creates the user and runs the provisioning script.
4. A provisioning script covering the known stack.
5. Nested KVM working in the guest, for the Android emulator.

## Plan

Commands are the intended shape and have not been run. Sizes are placeholders
until `00_start.md` Q4 is answered.

### Volumes

Block volumes, formatted in the guest. A filesystem volume would be shared into
the VM over virtiofs, which is slower for git and builds.

```bash
incus storage volume create default sbx-projects --type=block size=100GiB
incus storage volume create default sbx-caches   --type=block size=60GiB
```

### Profile

```bash
incus profile create sbx
incus profile set sbx limits.cpu=8 limits.memory=16GiB security.secureboot=false
incus profile device add sbx root disk pool=default path=/ size=60GiB
incus profile device add sbx eth0 nic network=sbxbr0 ipv4.address=10.77.0.10
incus profile device add sbx projects disk pool=default source=sbx-projects
incus profile device add sbx caches   disk pool=default source=sbx-caches
```

- A fixed address so the host's SSH config and the git remotes can name it.
- Secure boot off, so the NVIDIA driver in phase 4 needs no module signing.

### cloud-init

Kept small: it creates the user, mounts the two volumes and hands over to the
provisioning script. Everything else lives in the script, where it is reviewed.

```yaml
#cloud-config
users:
  - name: ai
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - <host public key>
ssh_pwauth: false
fs_setup:
  - {device: /dev/disk/by-id/<projects>, filesystem: ext4, label: projects, overwrite: false}
  - {device: /dev/disk/by-id/<caches>,   filesystem: ext4, label: caches,   overwrite: false}
mounts:
  - [LABEL=projects, /home/ai/projects, ext4, "defaults,nofail"]
  - [LABEL=caches,   /home/ai/.cache,   ext4, "defaults,nofail"]
```

`overwrite: false` is what keeps a rebuild from reformatting a volume that
already holds work. Verify it on a volume with a test file before trusting it.

### Launch

```bash
incus launch images:ubuntu/24.04/cloud sbx --vm -p sbx \
  --config cloud-init.user-data="$(cat cloud-init.yaml)"
```

### Provisioning script

One script, idempotent, run as `ai`. It is the reviewed list of what the VM
contains. First version:

- base: git, build-essential, curl, tmux, zellij, ripgrep, the existing
  `install_basics.sh` and `install_tools.sh` where they fit
- Python: uv, then Pythons through uv
- Claude Code
- dotfiles: clone location under `~/projects`, run `install/install.py`
- Flutter and the Android SDK into `~/android-sdk`, emulator and one system image
- Blender and `bpy`
- Docker engine, if wanted inside the VM

Large downloads point their caches at `~/.cache` so the caches volume holds
them: `UV_CACHE_DIR`, `GRADLE_USER_HOME`, `PUB_CACHE`. Whether the Android SDK
itself should sit on the caches volume is decided here by how long a fresh
install takes.

The loop for new tools: the assistant installs what it needs, appends it to the
script in its clone, and the change comes out through the git flow of phase 3.

### Emulator check

```bash
ls -l /dev/kvm            # must exist in the guest
```

then the headless emulator steps already recorded in this repo's
`2026-09-25_00_install_android_emulator.md`.

## Pitfalls

- **Volume device names in the guest.** The `by-id` names for attached Incus
  volumes need to be read off a running VM before the cloud-init file is final.
- **cloud-init runs once per instance.** A changed file takes effect on the
  next rebuild, not on a restart.
- **`/home/ai/.cache` on a separate disk** is owned by root after the first
  mount. The script has to `chown` it.

## Out of scope

- Getting repos, credentials and API keys in: phase 3.
- The rebuild script itself: phase 5. Here the rebuild is done by hand once to
  prove the volumes survive.

## Done when

- `ssh ai@10.77.0.10` works from the host with the key, and password login is
  refused.
- The phase 1 isolation test passes from inside this VM.
- `uv`, `flutter doctor`, `blender --version` and `claude --version` all answer.
- The emulator boots headless to `sys.boot_completed=1`.
- A file written to `~/projects`, and one to `~/.cache`, are still there after
  deleting the instance and launching it again.

## Rollback

```bash
incus delete -f sbx
incus profile delete sbx
incus storage volume delete default sbx-projects
incus storage volume delete default sbx-caches
```
