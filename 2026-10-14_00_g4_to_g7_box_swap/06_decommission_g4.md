---
status: draft
---

# Phase 6 - Decommission G4's box role

## Overview

Remove the box services and box-only secrets from G4, install the admin role, and reissue what was lost with G7.
The tunnel is kept (`00_start.md` Q2), so the only copy of its JSON must end up on G7.
Context: [`00_start.md`](00_start.md) Q3, Q8, Q11. Depends on [`05_cutover.md`](05_cutover.md) verified for a few days.

## Goals

1. G4 runs no box service and holds no box-only secret, including the tunnel JSON.
2. G4 is the Gramps admin machine.
3. G7 holds no trusted credential; the old G7 PAT is revoked.

## Plan

- Before deleting anything: copy the restic repository password from G4's `.restic.env` into the new `.admin.env` (see the reissue list in `00_start.md`).
- G4 services (sudo-handoff): remove `/etc/cloudflared/*.json` (shred) and `config.yml`, `apt remove cloudflared` or leave it masked; disable the `hub` and `cc-kb` nginx sites (or remove nginx); `setfacl -x u:www-data /home/pmn`.
- Gramps on G4: remove the stopped containers and named volumes; delete `.env`, `.backup.env`, `.restic.env` from the G4 clone.
  Create `.admin.env` with reissued values: R2 token with delete rights, Cloudflare Access token, Gramps admin credential, repository password.
  Keep `/srv/gramps-web` on G4 for 14 days after the first verified G7 backup, then delete it (Q11). Log the deletion date.
- `rm ~/.claude/rules/local-box.md` on G4 (the box rule no longer describes it).
- Remote access to G4 (Q8, Q16). While Tailscale SSH is on it answers port 22 on the tailnet address itself, so openssh-server cannot be tested from another device until it is off, and turning it off may drop Tailscale SSH sessions:
  install openssh-server; `ufw allow in on tailscale0 to any port 22 proto tcp`; check `ssh pmn@localhost` on G4 asks for the password;
  then, from a session that does not ride on Tailscale SSH (VS Code Remote-SSH counts as one that does) or at the machine, `tailscale set --ssh=false`; check `ssh pmn@pmn-14g4` from another device. Revert: `tailscale set --ssh`.
  sshd settings from `01_box_setup.md` phase 1 except `PasswordAuthentication`, which stays on (port 22 is reachable from the tailnet only).
- Optional: revert G4's always-on lid setting (`always-on-server.md` Reverting section), drop linger.
- GitHub: revoke the fine-grained PAT that lived on G7.
- Docs in `linux-box-cloudflare`: any gap found in phases 3 to 5; which host is the box. Gramps `docs/admin-machine.md` if it names a host.
- `genealogy-gramps-fn`: consider a fixed `--host` for `restic backup` in `backup_run.sh`, so snapshots stay one series across box swaps (phase 5 finding).
- Delete `/srv/gramps-web.rehearsal` on G7.
- Lid-closed reboot test of G7, if still open.
- Final log line in `tracking.md`; folder status to `done`.

## Done when

- On G4: no `/etc/cloudflared/*.json`; no listener on 8090, 8091, 8092; `docker ps -a` empty; `tailscale debug prefs` shows `RunSSH: false`; ssh to G4 over Tailscale reaches openssh-server.
- In `genealogy-gramps-fn`: `make ps` refuses on G4 and works on G7; an admin target is accepted on G4.
- The site still serves from G7 with G4 powered off.
