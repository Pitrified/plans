---
status: in progress
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
- At the G7 console, before any remote access exists: `bootstrap.sh` (only apt git and the clone of `~/bootstrap`), then `install_tools.sh` (fzf, eza, bat, btop, fonts, plocate, ag, 7zip, xclip, VS Code, Claude Code, Tailscale), then Tailscale up.
  `bootstrap.sh` is fetched from the `master` branch (the README pointed at `main`, which 404s; fixed in the bootstrap repo).
- Over ssh from G4: `install_basics.sh` (apt upgrade, uv, dotfiles install, `~/repos`, `~/ephem`, repomgr clone). It has to run before `install_tools.sh`; on G7 it ran after, see findings.
  Then `setup_gnome.sh` and `~/.gitconfig.local` (name and email, as on G4), from the console or remotely.
- Network: stock DHCP DNS, no IPv6 DNS workaround (Q9); reapply `2026-08-23_00` only if the IPv4 outage returns.
- Tailscale: remove the old `pmn-g7` node from the admin console first, then `tailscale up --ssh`; it registered as `g7`.
- `01_box_setup.md` phase 1: apt upgrade, unattended-upgrades verified, `pro attach` (esm-apps, esm-infra, livepatch), UFW default deny with no rules, sysctl hardening. Use the values found live on G4 in phase 1, not only the doc.
  No fail2ban and no usb-storage block (Q14): change `01_box_setup.md` to make fail2ban conditional on openssh-server and the usb-storage block optional.
- Packages: install from `~/saved_state_g4/apt.txt`, minus `iperf3` (Q15) and the hardware/meta packages the installer already provides.
- `bash scripts/setup-always-on.sh`; `loginctl enable-linger pmn`.
- apt: git, git-lfs, nginx, cloudflared (apt repo, `noble` fallback), docker.io, docker-compose-v2, restic, `pmn` into `docker` group, uv per its install route on G4.
- Toolchains per Q7, each from its note: Flutter + Android (`2026-07-07_00`), PATH fix (`2026-09-24_00`), emulator and kvm ACL (`2026-09-25_00`), calibre (`2026-08-11_00`), Playwright (`2026-09-17_00`).
- `~/dotfiles` and `~/bootstrap` cloned over https (public, no credentials needed) and linked as on G4.
- `bash scripts/setup-disposable-box.sh` after `~/repos/linux-box-cloudflare` lands (phase 4), so the box rule loads on G7.
- GitHub via agent forwarding (Q12): from G4, `ssh -A pmn@g7` then `ssh -T git@github.com` on G7 greets the user (key loaded on G4 with `ssh-add -t 1h`).
  Add GitHub's host key to G7's `known_hosts`. No key or credential helper on G7; a fine-grained PAT only if forwarding gets tedious (Q16).
- Claude Code: install, log in, check Remote Control in one repo (the GitHub App gate in `2026-07-17_00` is account-level, should already pass).
- Each deviation from the docs: commit a doc fix in `linux-box-cloudflare` (from G4, or from G7 in an `ssh -A` session).

## Out of scope

- Data, repos, secrets (phase 4).
- cloudflared service and tunnel JSON (phase 5); installing the package here is fine.

## Done when

- From G4: `ssh pmn@g7` works over Tailscale; it still works after a lid-closed reboot of G7 on AC.
- `ufw status`, `pro status`, `systemctl is-active unattended-upgrades` match G4's phase 1 log.
- Agent-forwarded `ssh -T git@github.com` works on G7, and fails from a session without `-A`.
- `flutter doctor`, `docker run --rm hello-world`, `restic version`, `cloudflared --version` pass on G7.

## What the implementation found

- G7 joined the tailnet as `g7` (not `pmn-g7`), Tailscale SSH on. Its host key was pinned on G4 from `tailscale status --json`, not by accepting the first prompt.
- `bootstrap.sh` is only `apt install git` and the clone. `install_basics.sh` must run before `install_tools.sh`; on G7 it ran after, so `install_tools.sh` failed in four places, fixed in `~/bootstrap` and redone by hand: batcat link (no `~/.local/bin` yet), btop (tarball needs `make`; now `apt install btop`), `fonts-hack-ttf` (now `fonts-hack`), `p7zip-desktop` snap (dropped).
- After `install_basics.sh`: dotfiles links in `~` and `~/.claude` (CLAUDE.md, settings, skills, sudo-guard hook), uv, `~/repos/repomgr`. `~/.gitconfig.local` written with name and email.
- The dotfiles Claude settings ran `rtk hook claude` on every Bash call, and nothing installs `rtk`. The user removed the hook rather than install rtk; an rtk install on G7 was rolled back (binary and its data folder).
  `RTK.md` removed from dotfiles and its `~/.claude` link removed on G4 and G7. The `rtk` config topic in dotfiles and the `rtk` binary on G4 remain, unused.
- `setup_gnome.sh` run over ssh against the console session's bus (`DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus`).
- The first apt upgrade left a kernel update pending a reboot.
