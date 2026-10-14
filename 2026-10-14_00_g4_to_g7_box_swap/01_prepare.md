---
status: draft
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
