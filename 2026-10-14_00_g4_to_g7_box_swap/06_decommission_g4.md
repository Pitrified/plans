---
status: in progress
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

- Gate: the user makes an edit in Gramps through the public hostname and sees it persist after a reload (open from phase 5). The tunnel JSON on G4 is the rollback path, so it goes last.
- Before deleting anything: create `.admin.env` from `.admin.env.example`, with `RESTIC_REPOSITORY` and `RESTIC_PASSWORD` copied from G4's `.restic.env` (the same values also live on G7) and `GRAMPS_BOX_HOST=g7`. Copied by script, never printed.
  The rest is reissued by the user per `genealogy-gramps-fn/docs/admin-machine.md` steps 4-6: Gramps admin account, R2 token with delete rights, Cloudflare Access token. Admin targets fail until then.
- Gramps on G4: `docker compose down -v` (stopped containers and the four named volumes), remove the `grampsweb`, `valkey` and `hello-world` images (about 6.8 GB); delete `.env`, `.backup.env`, `.restic.env` from the G4 clone.
- G4 services (sudo-handoff): `cloudflared service uninstall`, shred `/etc/cloudflared/*.json`, remove `config.yml`. The `cloudflared` package stays: G4 is the management machine and needs the CLI.
  nginx: remove the `hub` and `cc-kb` links in `sites-enabled` and `/var/www`, `systemctl disable --now nginx`. `setfacl -x u:www-data /home/pmn`.
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

## What the implementation found

- Gramps edit check passed on G7 through the public hostname: the edit persisted after a reload.
- `.admin.env` on G4 created from the template by a script, mode 600: `GRAMPS_BOX_HOST=g7`, `GRAMPS_BOX_USER=pmn`, restic repository and password copied from `.restic.env` (compared equal without printing). Eight values remain placeholders for the user to reissue.
  `make ps` now refuses on G4 ("this machine has .admin.env") and works on G7.
- G4 Docker: `docker compose down -v` and three images removed (about 6.8 GB). Zero containers, volumes, images.
- The permission layer blocks Claude commands that delete or even list `.env` files (the `Read(**/.env)` deny rule matches them): the user deleted `.env`, `.backup.env`, `.restic.env` on G4.
- G4 teardown (user, `06a-g4-teardown.log`): `cloudflared service uninstall`, tunnel JSON shredded (rollback ended here), `config.yml` removed, nginx sites and `/var/www` links removed, nginx disabled, `www-data` ACL removed. No listener on 80 or 8090-8092. The `cloudflared` package stays for management.
- `/srv/gramps-web.rehearsal` deleted on G7. Box rule link removed from G4's `~/.claude/rules/`.
- Remote access: openssh-server on G4 with a hardening drop-in (`PermitRootLogin no`, `AllowUsers pmn`, `MaxAuthTries 3`, `X11Forwarding no`), password login kept, UFW allows 22 on `tailscale0` only; `ssh pmn@localhost` tested before `tailscale set --ssh=false`. Port 22 answers over the tailnet; `RunSSH` is false.
  A "temporary failure in name resolution" from G7 was a false alarm: the user's retry logged in from G7 to G4 with the password, and G7 resolves `pmn-14g4` with MagicDNS.
  G7 can reach G4's sshd (password only). A Tailscale ACL could block G7 to G4 on port 22; not done.
- Docs: `01_box_setup.md` gets fail2ban as conditional on openssh-server and the usb-storage block as optional (`00_start.md` Q14, owed since phase 3), and a "Moving the box, same tunnel" section describing this cutover.

Still open, with the user:

- ~~Revoke the fine-grained GitHub PAT that lived on the old G7.~~ The user decided not to revoke it (2026-10-15); its only copy was on the wiped disk.
- ~~Reissue the three admin credentials into `.admin.env` (`genealogy-gramps-fn/docs/admin-machine.md` steps 4-6).~~
  Done 2026-10-15, without rotation: the old admin machine was wiped with care, only the file was lost. The R2 and Cloudflare token values came from the password manager.
  The `admin-scripts` Gramps password was not saved anywhere, and the API cannot set another user's password, so the user deleted and recreated the account.
  The username is not a secret, so the template now names `admin-scripts` and says role Owner.
  `make admin-verify` on G4: ready, every check passing, including the Cloudflare one, so the Access token was not in its switched-off state at that moment.
- Delete `/srv/gramps-web` on G4 on or after 2026-10-28 (14 days after the first G7 backup, Q11).
- ~~Lid-closed reboot test of G7.~~ Done 2026-10-15. Before the reboot: lid closed, on AC, logind set to ignore the lid on external power.
  G7 refuses `systemctl reboot` over ssh without interactive authentication, so the user rebooted it with `ssh -t` and sudo.
  It came back on the tailnet with the lid closed and nobody logged in. cloudflared had 4 registered connections and no errors; nginx, Docker, the three Gramps containers and the user backup timer (linger) were up; 8090, 8091 and 8092 answered 200 on loopback; no failed units.
  The public path was not re-tested, since a curl only reaches Access at the edge.
- Optional: revert G4's always-on lid setting and linger.
- ~~Fixed restic `--host` in `backup_run.sh`.~~ Done 2026-10-15: backups run with `--host gramps-box`.
  Correction to phase 5: G4's snapshots would not have aged out as their own group. restic counts the most recent days that hold a snapshot, so a group that stops growing keeps up to 14 + 12 + 24 snapshots forever.
  So the existing snapshots were renamed too (61 from `pmn-14G4`, 2 from `g7`). The permission layer blocks Claude from `restic rewrite --forget`, so the user ran it after a clean dry run. Result: 63 snapshots, all `gramps-box`, and `make backup-check` found no errors.
  G7's clone pulled with a rebase. Its local tree snapshot commit stays unpushed, as usual. shellcheck installed on G4; it passes on `backup_run.sh` and `prune_run.sh`.
