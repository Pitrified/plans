---
status: draft
---

# Phase 3 - Install G7 as the box

## Overview

Rebuild G7 from the repo docs, as if the box were new.
This is also the test of `linux-box-cloudflare`: anything the docs miss is fixed there, not only done by hand.
Context: [`00_start.md`](00_start.md) Q1, Q7, Q9. Depends on [`01_prepare.md`](01_prepare.md); the GitHub check needs the G4 key from [`02_g4_trusted.md`](02_g4_trusted.md). G7 is already wiped (Q1).

## Goals

1. G7 runs Ubuntu 26.04, hardened per `01_box_setup.md` phase 1, always-on per `always-on-server.md`.
2. G7 is reachable from G4 over Tailscale SSH and survives a reboot lid-closed.
3. Base packages and toolchains are installed from apt or the methods in the existing notes.
4. Claude Code runs on G7 with Remote Control working.

## Plan

- Install Ubuntu 26.04 (user, at the machine). Same username `pmn`, so paths in units and configs carry over.
- Network: stock DHCP DNS, no IPv6 DNS workaround (Q9); reapply `2026-08-23_00` only if the IPv4 outage returns.
- Tailscale: remove the old `pmn-g7` node from the admin console first, then `tailscale up --ssh` and name it `pmn-g7`.
- `01_box_setup.md` phase 1: apt upgrade, unattended-upgrades verified, `pro attach` (esm-apps, esm-infra, livepatch), UFW default deny, fail2ban, sysctl hardening, usb-storage block. Use the values found live on G4 in phase 1, not only the doc.
- `bash scripts/setup-always-on.sh`; `loginctl enable-linger pmn`.
- apt: git, git-lfs, nginx, cloudflared (apt repo, `noble` fallback), docker.io, docker-compose-v2, restic, `pmn` into `docker` group, uv per its install route on G4.
- Toolchains per Q7, each from its note: Flutter + Android (`2026-07-07_00`), PATH fix (`2026-09-24_00`), emulator and kvm ACL (`2026-09-25_00`), calibre (`2026-08-11_00`), Playwright (`2026-09-17_00`).
- `~/dotfiles` and `~/bootstrap` cloned over https (public, no credentials needed) and linked as on G4.
- `bash scripts/setup-disposable-box.sh` after `~/repos/linux-box-cloudflare` lands (phase 4), so the box rule loads on G7.
- GitHub via agent forwarding (Q12): from G4, `ssh -A pmn@pmn-g7` then `ssh -T git@github.com` on G7 greets the user, and a confirmation prompt appears on G4 (`ssh-add -c`).
  Add GitHub's host key to G7's `known_hosts`. No key, PAT or credential helper on G7.
- Claude Code: install, log in, check Remote Control in one repo (the GitHub App gate in `2026-07-17_00` is account-level, should already pass).
- Each deviation from the docs: commit a doc fix in `linux-box-cloudflare` (from G4, or from G7 in an `ssh -A` session).

## Out of scope

- Data, repos, secrets (phase 4).
- cloudflared service and tunnel JSON (phase 5); installing the package here is fine.

## Done when

- From G4: `ssh pmn@pmn-g7` works over Tailscale; it still works after a lid-closed reboot of G7 on AC.
- `ufw status`, `fail2ban-client status sshd`, `pro status`, `systemctl is-active unattended-upgrades` match G4's phase 1 log.
- Agent-forwarded `ssh -T git@github.com` works on G7, and fails from a session without `-A`.
- `flutter doctor`, `docker run --rm hello-world`, `restic version`, `cloudflared --version` pass on G7.
