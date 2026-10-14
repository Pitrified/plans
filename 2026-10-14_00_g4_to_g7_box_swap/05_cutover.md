---
status: draft
---

# Phase 5 - Cutover

## Overview

One window, downtime accepted (`00_start.md` Q2, Q6).
Stop everything public on G4, move the frozen Gramps data and the tunnel JSON, start on G7, verify, then let G7 own backups.
No DNS change: the tunnel is the same one.
Context: [`00_start.md`](00_start.md) Q2, Q11. Depends on [`04_stage_on_g7.md`](04_stage_on_g7.md).

## Goals

1. All three hostnames served by G7 through the existing tunnel, behind the same Access policies.
2. Gramps on G7 holds the exact data G4 had at freeze time.
3. Exactly one host runs the tunnel and the Gramps backup, and it is G7.

## Plan

- Before anything else: with G7 in its final place, closed lid, on AC, reboot it and check it comes back on the tailnet (carried over from phase 3).
- On G4: `systemctl --user disable --now gramps-backup.timer`; `make down` in `genealogy-gramps-fn`; `sudo systemctl disable --now cloudflared`.
  The site is down from here.
- On G7: `make down` in `genealogy-gramps-fn`, so the rehearsal stack does not hold the files being replaced.
- Copy `/srv/gramps-web` G4 to G7 as root, preserving ownership (sudo tar, scp, sudo untar after moving the rehearsal copy aside). Compare file counts and a checksum of `db/`.
  Same route as the phase 4 rehearsal: tar into `~` on G4 and chown it, rsync to G7, extract with `tar -C /srv` as root, delete both archives.
  Then compare the Gramps counts on both hosts, as in phase 4.
- Copy `/etc/cloudflared/<UUID>.json` G4 to G7 the same way, then on G7 `install -o root -g root -m 600` into `/etc/cloudflared/`. The transfer copy is deleted on both sides right after.
- On G7: `make up`; `cloudflared tunnel ingress validate`; `sudo cloudflared service install` (if not done) and `systemctl enable --now cloudflared`.
  `cloudflared tunnel info` from G4 is not available without `cert.pem`; check `journalctl -u cloudflared` on G7 for registered connections instead.
- Verify from the phone on mobile data: each hostname loads, Access challenges, Gramps login works, a write (edit a note) persists.
- On G7: enable `gramps-backup.timer`, run `gramps-backup.service` once, check the R2 snapshot exists and its size matches recent ones.

## Rollback

Until phase 6 removes G4's copy of the JSON:
stop cloudflared on G7, then `systemctl enable --now cloudflared` and `make up` on G4, and re-enable the timer on G4.
Any Gramps edits made on G7 after cutover are lost in a rollback unless exported first.

## Done when

- All Goals verified from outside the tailnet.
- One successful R2 backup from G7.
