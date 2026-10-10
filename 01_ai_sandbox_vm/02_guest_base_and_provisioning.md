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

`sandbox-vm/guest/cloud-init.yaml`. Kept small: it creates the user, labels and
mounts the two volumes, and sets SSH to key-only. Everything else lives in the
provisioning script, where it is reviewed.

The volumes are mounted by filesystem label. On a first boot a small script,
`sbx-disks.sh`, labels them; on a rebuild they already carry the label and are
left alone. The script finds each disk by its **serial**, which is expected to
carry the Incus device name (`incus_projects`, `incus_caches`), and guesses
nothing: with no matching serial the label stays missing and the mount is
skipped. It never touches a disk that already has a filesystem.

This replaces cloud-init's `fs_setup`, which needs device names. Tested in a
real VM in the lab, including a rebuild; see [`01.2_lab_run.md`](01.2_lab_run.md).

### Launch

```bash
sbx up
```

which creates the instance from the profile on first use:

```bash
incus init images:ubuntu/24.04/cloud sbx --vm -p sbx \
  --config cloud-init.user-data="$(sed "s|__SSH_PUBKEY__|$(cat ~/.ssh/sbx_ed25519.pub)|" cloud-init.yaml)"
incus start sbx
```

### Provisioning script

`sandbox-vm/guest/provision.sh`: one script, idempotent, run as `ai`. It is the
reviewed list of what the VM contains. `sbx provision` pushes the **host's**
copy into the VM and runs it, so what runs is what was reviewed. Only its `base`
section has been run (packages, git identity, cache locations); the rest is a
first draft:

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
script in its clone of the repo, and the change comes out through the git flow
of phase 3. It takes effect at the next `sbx provision` or rebuild, from the
host's copy.

### Emulator check

```bash
ls -l /dev/kvm            # must exist in the guest
```

then the headless emulator steps already recorded in this repo's
`2026-09-25_00_install_android_emulator.md`.

## Pitfalls

- **Disk serials under Incus.** The label script relies on Incus naming a
  volume's serial after its device (`incus_projects`). True of the versions
  read about, not seen on a real Incus VM. Check with `lsblk -o NAME,SERIAL` on
  the first boot. If the serial differs, both labels stay missing, the mounts
  are skipped, and nothing is formatted: a safe failure, visible as an empty
  `~/projects` on the root disk.
- **cloud-init runs once per instance.** A changed file takes effect on the
  next rebuild, not on a restart.
- **Nested KVM** in an Incus VM is assumed from the host's `nested=Y`. Not
  tested.

## Out of scope

- Getting repos, credentials and API keys in: phase 3.
- The rebuild script itself: phase 5. Here the rebuild is done by hand once to
  prove the volumes survive.

## Done when

- `sbx ssh` works from the host with the key, and password login is refused.
- `lsblk -o NAME,SERIAL,LABEL,MOUNTPOINT` in the guest shows the two volumes
  labelled and mounted.
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
