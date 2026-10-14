---
status: done
---

# Phase 1 - Prepare and close inventory gaps

## Overview

Nothing changes on either host's role here.
The phase finishes the inventory where it needed sudo and takes a G4 state snapshot to rebuild from.
G7 is already wiped (`00_start.md` Q1), so there is nothing left to rescue from it.
Context: [`00_start.md`](00_start.md).

## Goals

1. A complete list of G4 system state, including what needed sudo to read.
2. A G4 snapshot in the same shape as `~/saved_state` (G7's), for diffing and rebuild.
3. Cloudflare zone state recorded before anything moves.

## Plan

- G4 snapshot into `~/saved_state_g4/` (unprivileged, same lists as G7's): `apt-mark showmanual`, `snap list`, `dconf dump /`, VS Code server extensions, `systemctl --user list-unit-files --state=enabled`, home tree at depth 3.
  It stays on the hosts, not in this public repo.
- sudo-handoff, read-only, logged to `~/handoff-logs/`:
  `ufw status verbose`, `fail2ban-client status`, `ls /etc/modprobe.d /etc/systemd/logind.conf.d /etc/sysctl.d`, `tailscale debug prefs | grep -E 'RunSSH|WantRunning'`, `systemctl cat iperf3`, `cat /etc/docker/daemon.json`.
  Diff the result against `01_box_setup.md` and the plan notes; every live item with no doc gets a line in `00_start.md`.
- Cloudflare dashboard (browser on G4): HSTS state; the Access applications covering apex, `*`, `family`; DNS records. Record which, not values.

## Out of scope

- Any install, any login on G4 (phase 2).

## Done when

- `~/saved_state_g4/` exists and the sudo-read logs are reviewed.
- HSTS and Access coverage are written in the log.

## What the implementation found

Snapshot in `~/saved_state_g4/` on G4 (package lists, dconf, enabled units, apt sources, shell rc files).
Privileged reads logged in `~/handoff-logs/g4_to_g7/01*`.

- UFW: active, default deny incoming, allow outgoing, **no rules**. This is the end state `01_box_setup.md` phase 6 describes.
- Tailscale: `RunSSH` and `WantRunning` true, no advertised routes, no exit node, shields down.
- No openssh-server; nothing listens on 22.
- **fail2ban is not installed**, although `01_box_setup.md` phase 1 step 6 says to. With no openssh-server and no open inbound port it has nothing to watch. See `00_start.md` Q14.
- **No usb-storage block** in `/etc/modprobe.d/`, although the doc lists it. See Q14.
- **iperf3** is manually installed and its packaged server is enabled, listening on `*:5201`. UFW blocks it from the LAN; Tailscale peers can reach it. See Q15.
- An ad hoc `house-renderer` viewer (`uvicorn --reload`) listens on the Tailscale IP, port 8093. A dev server, not a service: nothing to migrate.
- No `/etc/docker/daemon.json`: Docker runs on defaults.
- `/etc/sysctl.d/99-hardening.conf` and `/etc/systemd/logind.conf.d/keep-awake.conf` are present, as tracked.
- Manually installed packages (73, `apt.txt`) beyond the plan notes: SDL2 dev libraries and libpng/jpeg/freetype dev (pygame, for `laife`), ffmpeg, eza (from the `gierens` repo), bat, 7zip, fonts-hack, xclip, xtermcontrol, silversearcher-ag, gnome-tweaks, ibus Chinese input tables.
  The phase 3 package list comes from this file, not from memory.
- Snaps: `code`, `zellij`, `firefox`, `canonical-livepatch`. `~/.local/bin`: `uv`, `claude`, `rtk`.

Cloudflare, read through a one-day read-only API token (`cf_dump.sh`; JSON kept on G4 only, since Access policies hold email addresses):

- HSTS on: max-age 6 months, `includeSubDomains` on, **preload off**, nosniff on. Matches `01_box_setup.md`.
  No action for the cutover: the tunnel stays the same, so HTTPS never goes away and HSTS can stay on.
- SSL mode Full (strict), minimum TLS 1.2, Always Use HTTPS off (HSTS covers browsers).
- DNS: exactly three proxied CNAMEs (apex, `cc-kb`, `family`), all to the current tunnel. No stale records.
- Access: three self-hosted applications, each with one Allow policy:
  apex (`Home Portal`, 24h), `*.pitrified.qzz.io` (`Internal Apps`, 24h), `family.pitrified.qzz.io` (`Family Tree App`, 168h, its own policy for family users). Every ingress hostname is covered.
- Tunnels: one, healthy, 4 connections. It is named `pmn-14g4` after G4; the name is cosmetic and stays when the JSON moves to G7.
