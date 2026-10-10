---
status: draft
---

# Phase 5 - Rebuild, snapshots and day-to-day maintenance

## Overview

Turn the manual steps of phases 2 and 3 into one rebuild command, protect
unfetched work with snapshots, and write down the routine commands. When this
phase closes, its runbook section moves to wherever the scripts live
(`00_start.md` Q1) as the as-is documentation; this file stays as the record.
Context: [`00_start.md`](00_start.md), depends on
[`03_git_flow_and_credentials.md`](03_git_flow_and_credentials.md).

## Goals

1. `sbx rebuild`: one command from a running VM to a fresh one, login intact.
2. Scheduled snapshots of the projects volume, and a tested restore.
3. Web apps in the VM reachable from the host and from other tailnet devices.
4. A runbook of the routine commands.

## Plan

Commands are the intended shape and have not been run.

### Rebuild

```
sbx rebuild
  1. refuse if any project in the VM has commits the host has not fetched,
     unless --force (it names the project and branch)
  2. carry out: credentials, .claude.json            (phase 3)
  3. snapshot the projects volume, labelled pre-rebuild-<timestamp>
  4. delete the instance
  5. create and start it from the profile and cloud-init (phase 2)
  6. wait for cloud-init, then for SSH
  7. push the host's provision.sh in and run it
  8. carry in: credentials, .claude.json, sbx.env    (phase 3)
  9. run the isolation test                           (phase 1)
```

Implemented in `sandbox-vm/sbx` and run end to end in the lab, including the
refusal in step 1 ([`01.2_lab_run.md`](01.2_lab_run.md)). Repos such as the
dotfiles live on the projects volume, so they are still there after a rebuild
and need no pushing in again.

Step 1 is the one that matters: a rebuild keeps the projects volume, but it is
also the moment people stop looking at what was in the old VM.

Cadence follows `00_start.md` Q6.

### Snapshots

`00_start.md` Q5:

```bash
incus storage volume set default sbx-projects snapshots.schedule="@hourly"
incus storage volume set default sbx-projects snapshots.expiry=7d
incus storage volume snapshot list default sbx-projects
```

Restore, with the VM stopped:

```bash
incus stop sbx
incus storage volume snapshot restore default sbx-projects <snapshot>
incus start sbx
```

Restore needs the instance stopped; Incus refuses otherwise. Confirmed in the
lab, where a deleted project came back from a snapshot.

A snapshot of a block volume taken while the guest is writing is crash
consistent, not clean. Good enough for git repos. The lab pool was `dir`, so
neither that nor a scheduled snapshot actually firing has been seen.

### Web apps

From the host, directly:

```
http://10.77.0.10:<port>
```

If the app binds to localhost in the VM:

```bash
ssh -L <port>:localhost:<port> sbx
```

From another tailnet device, through the host. Ad hoc:

```bash
ssh -L <port>:10.77.0.10:<port> pmn-G7      # then browse localhost:<port>
```

Persistent, or from a phone:

```bash
tailscale serve --bg <port>     # host side, pointing at a local forwarder
```

`tailscale serve` may only accept localhost targets; if so, a `socat` or
`ssh -L` forwarder on the host sits in between. Both routes work with the host
headless. The direct route, the `ssh -L` route and a `socat` forwarder on the
host's tailnet address were tested in the lab; `tailscale serve` itself was not.

### Runbook

| Want | Command |
| ---- | ------- |
| start, CPU-only | `sbx up` |
| start with GPU | `sudo grub-reboot "<entry>" && sudo reboot`, then `sbx up --gpu` |
| stop | `incus stop sbx` |
| shell | `sbx ssh` |
| root shell without SSH | `incus exec sbx -- bash` |
| send a branch in | `sbx in` |
| review and take work out | `sbx out`, then `git push` |
| state and address | `incus list sbx` |
| console, when SSH is dead | `incus console sbx` |
| disk use | `incus storage info default` |
| snapshots | `incus storage volume snapshot list default sbx-projects` |
| rebuild | `sbx rebuild` |
| re-check isolation | `sbx test` |

### Routine upkeep

- After any host network change (Tailscale update, Docker install, new
  interface): re-run the isolation test.
- After a host kernel or NVIDIA driver update: check GPU mode still binds.
- Monthly or so: one rebuild, to prove the provisioning script still produces a
  working VM, and a look at pool usage.
- When a key in `sbx.env` is rotated: edit the host copy, carry it in.

## Pitfalls

- **The pool fills up.** Loop-file pools do not grow by themselves; snapshots
  and Android system images add up. `incus storage info default` is in the
  monthly check for that reason.
- **Snapshots are not a backup.** They live on the same disk as the volume.
  Work that matters leaves through `sbx out`.

## Out of scope

- Backing the volumes up off the machine.
- A second VM for a different trust level. A sibling folder if it is ever
  needed.

## Done when

- `sbx rebuild` goes from a running VM to a working one, with projects, caches
  and the Claude login intact, and the isolation test passing, with no manual
  step in between.
- A file deleted from `~/projects` is recovered from a scheduled snapshot.
- A web app in the VM opens from the host and from a second tailnet device.
- The runbook has been used for a week without needing a command that is not
  in it.

## Rollback

Unset the snapshot keys (`incus storage volume unset default sbx-projects
snapshots.schedule`), `tailscale serve reset`, remove the wrapper.
