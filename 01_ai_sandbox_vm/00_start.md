---
status: draft
priority: 0
description: |
  A KVM virtual machine on the g7 laptop where an AI assistant runs as root with
  permissions skipped, cut off from the host filesystem, the LAN and the tailnet.
  Covers the host setup, the guest provisioning, the git flow in and out, GPU
  passthrough, rebuilds and day-to-day maintenance.
comment: |
  Written from a design conversation on 2026-10-09/10. Nothing has been run on
  g7. Phases 1, 2, 3 and 5 were dry-run on another machine the same day, see
  01.2_lab_run.md; phase 4 (GPU) has not been run anywhere.
---

# AI sandbox VM

## The idea

Give the assistant a machine where it is root and can do whatever a task needs
(install toolchains, run servers, break things), entirely separate from the
host filesystem. We put inside exactly what it needs: the repos for the work at
hand, several at once if useful, and a few low-impact API keys dedicated to it.
Nothing of the host's own credentials goes in.

## Threat model

Containing **mistakes, not attackers**. We do not expect serious prompt
injection; the point is that a misunderstanding by the assistant cannot touch
the host's files or the services on the home network. This is why several
measures below are described as hygiene and not as hard requirements. If the
threat model changes, the review ordering and the credential handling are the
first things to tighten.

## Host facts

Captured in [`01.1_host_facts.md`](01.1_host_facts.md). In short: HP ZBook
Studio G7 (`pmn-G7`), 10th-gen Intel, 32 GB RAM, a Quadro RTX 3000 Mobile as the
only visible GPU, IOMMU on with the GPU alone in its group, nested
virtualization already enabled.

## Decisions

Settled in the conversation. Rejected alternatives are kept because they
explain the shape.

### Isolation

- **A KVM virtual machine, not a container.** A container shares the host
  kernel, so root inside is not far enough from the host. Rejected: plain
  Docker/Podman, gVisor, Kata, off-host sandboxes.
- **Incus as the VM manager**, for now. The rebuild loop, the GPU toggle and the
  network rule are first-class there, where libvirt needs glue for each.
  Fallback: libvirt, if GPU passthrough on the mobile Quadro needs tricks that
  only the libvirt guides cover. The guest image, the provisioning script and
  the firewall design carry over unchanged.
- **Ubuntu guest**, because the other machines run it. Rejected: NixOS, which
  fights `bpy` wheels, the Android SDK and anything else shipping prebuilt
  binaries, and that is most of this stack.

### Trust direction

- **The host reaches in; the VM never reaches the host.** Every flow below is
  shaped by this.
- **No `ssh -A`.** Agent forwarding would hand the host's keys to root in the VM
  for as long as the connection is open.
- **No GitHub credential in the VM**, not even a read-only PAT. Repos go in and
  out through a git remote on the host that points at the VM.

### Network

- **Internet only.** The VM sits on its own bridge behind the host's NAT. Host
  rules block it from the LAN, the tailnet (`100.64.0.0/10`) and the host
  itself. Two layers do it: an Incus ACL for the private ranges, and a small
  nftables guard for the host's own addresses, which the ACL does not cover. Kept even under the mistakes-only threat model: repos hold configs
  pointing at real homelab services, and a test run should fail to reach them.
- **The VM is not on the tailnet** and Tailscale is not installed in it. Other
  tailnet devices reach a web app in the VM through the host.

### Git flow

- **Commits happen inside the VM**, with only a name and email configured.
- **In:** `git push sandbox <branch>` from the host.
- **Out:** fetch, review, fast-forward, push. The code also lives on the host,
  and host repos stay trusted because nothing reaches a working tree before the
  review:

  ```bash
  git fetch sandbox
  git log -p ..sandbox/feat          # review
  git merge --ff-only sandbox/feat   # host branch and working tree take it
  git push
  ```

  Not `git pull sandbox feat`: pull fetches again and could take commits made
  after the review.

### Tooling and rebuilds

- **The assistant installs freely.** Anything worth keeping is written into the
  provisioning script, which is reviewed like any other change.
- **Rebuilding from the base image keeps the script honest**: anything not in it
  disappears. Rejected: a fully declarative guest (NixOS, see above).
- **The projects volume and the caches survive a rebuild** (uv, Gradle, Android
  SDK, Blender). The home directory does not.
- **`~/.claude` is not persisted.** The useful parts are symlinked from the
  dotfiles repo, which goes in through the same git remote and is reviewed like
  anything else.

### Assistant login

- **Claude login is done inside the VM** (subscription login, over SSH).
- **The host carries the credentials file out before a rebuild and back in
  after**, so the login survives. Accepted: the token gives access to the whole
  subscription. If the VM is ever suspected compromised, log that session out
  from the account and do not carry the file across.

### GPU and emulator

- **GPU off in the VM most of the time.** When wanted, the host is rebooted into
  headless mode so nothing on it holds the card, and the same VM starts with the
  RTX attached. One disk, one provisioning script, two ways to start.
- Rejected: BIOS hybrid graphics (not needed given the reboot), and the live
  swap that stops the display manager and unloads the driver without a reboot.
- **Android emulator inside the VM**, using nested KVM.

### Driving it

- SSH into the VM, tmux or zellij, assistant running with permissions skipped.
  Works from the phone and with the host headless.

## Open questions

- Q1: Where do the scripts live (host setup, guest provisioning, rebuild, the
  `sbx` wrapper)? This folder is the plan and the record; a plan folder holds
  markdown only, so executable files need a home.
  - a. `bootstrap`, in a `sandbox-vm/` subfolder split into `host/` and
    `guest/`. The guest provisioning can call the existing `install_*.sh`.
  - b. A new dedicated repo.
  - c. This repo, in a sibling folder outside the numbered plan folders.
  - Recommended: a, because the VM needs a clone of `bootstrap` anyway to
    provision itself, so the assistant's additions come back through the normal
    review.
  - Note, 2026-10-10: the lab run needed somewhere to keep what it wrote, so
    the scripts are in `sandbox-vm/` at the root of this repo for now. That is
    option c by accident, not a decision; moving them is a copy.
  - NEW_ANS:
- Q2: Which Ubuntu release is on g7, and which for the guest? Incus is in the
  standard repos from 24.04; an older host needs the Zabbly repo. `lsb_release
  -ds` answers the first half.
  - Recommended: guest on 24.04 LTS whatever the host runs, for the widest
    package and driver support.
  - NEW_ANS:
- Q3: Storage pool backend for Incus. It decides whether volume snapshots are
  cheap, and it is chosen once at `incus admin init`.
  - a. btrfs on a loop file. Snapshots work, nothing to repartition.
  - b. zfs on a loop file. Same, heavier on RAM.
  - c. dir. No setup, no real snapshots.
  - Recommended: a, because it gives scheduled snapshots with the least setup.
  - NEW_ANS:
- Q4: VM size. The host has 32 GB RAM; core count and free disk are not known
  yet (`nproc`, `df -h /`). Blender, the emulator and Flutter builds are heavy.
  - Recommended: 16 GB RAM, about two thirds of the host threads, 60 GB root,
    100 GB projects volume, 60 GB caches volume, adjusted once the two commands
    are run.
  - NEW_ANS:
- Q5: Scheduled snapshots of the projects volume. Work the assistant has done
  and that has not been fetched exists only in the VM; a mistaken `rm -rf` or
  hard reset there loses it. Under this threat model this is the main risk left.
  - Recommended: hourly, expiring after 7 days.
  - NEW_ANS:
- Q6: Rebuild cadence.
  - a. On demand, when the VM gets messy or to prove the script still works.
  - b. On a schedule (weekly).
  - Recommended: a, because rebuilds are no longer a security measure.
  - NEW_ANS:
- Q7: How do the low-impact API keys get in?
  - Recommended: a `.env` kept on the host with mode 600 and pushed in by the
    rebuild script, the same way as the Claude credentials.
  - NEW_ANS:
- Q8: Also carry `~/.claude.json` across rebuilds? It appears to hold first-run
  and folder-trust state; without it the onboarding prompts come back after
  each rebuild.
  - Recommended: yes, it is one more file in the same carry step.
  - NEW_ANS:
- Q9: Guest user. A single user `ai` with passwordless sudo, reached by SSH with
  the host's public key only, password login off.
  - Recommended: yes.
  - NEW_ANS:
- Q10: How is the host guard loaded at boot on g7? Raised by the lab run
  ([`01.2_lab_run.md`](01.2_lab_run.md)): the Incus ACL alone left the host
  reachable through any address outside the private ranges, and the nftables
  table that closes this does not survive a reboot by itself.
  - a. A small systemd unit ordered before `incus.service` that runs
    `nft -f host_guard.nft`.
  - b. An include in `/etc/nftables.conf` with `nftables.service` enabled.
  - Recommended: a, because it leaves the host's main firewall file alone and
    ties the guard to the thing it guards.
  - NEW_ANS:
