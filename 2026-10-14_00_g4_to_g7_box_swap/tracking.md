# implementation tracking

Swap the unattended box from G4 to G7 and make G4 the trusted machine.
G7 is rebuilt from the linux-box-cloudflare repo and the box plan notes, services move over in one cutover, and G4 loses every box-only secret and service.
Analysis, inventory and open questions in [`00_start.md`](00_start.md).

## Key decisions

- Build G7 in parallel while G4 serves; one cutover window, downtime accepted; G4 untouched until G7 is verified.
- Same tunnel: the JSON moves from G4 to G7 at cutover, no DNS change; never two connectors running at once; G4's copy deleted in phase 6.
- Fresh clones on G7 plus a curated copy of gitignored data, so everything unpushed must be pushed from G4 first.
- G7 was wiped before the plan; lost trusted material is reissued, not recovered.
- GitHub key on G4 only; G7 reaches GitHub through `ssh -A` from G4, key loaded with `ssh-add -t 1h`; a PAT on G7 is the accepted fallback.
- G4 is reached remotely through openssh-server on the tailnet only; Tailscale SSH off on G4.
- Claude memory goes into the repos, not `~/.claude`.
- Cloudflare `cert.pem` lives on G4 only, created when next needed.
- This folder is public on GitHub: nothing secret-adjacent in it.
- Every gap found in `linux-box-cloudflare` docs while building G7 is fixed in that repo.

## Phases

| #  | Phase                              | Plan                                                       | Status  |
| -- | ---------------------------------- | ---------------------------------------------------------- | ------- |
| 1  | Prepare and close inventory gaps   | [`01_prepare.md`](01_prepare.md)                           | done    |
| 2  | Make G4 the trusted machine        | [`02_g4_trusted.md`](02_g4_trusted.md)                     | done    |
| 3  | Install G7 as the box              | [`03_g7_install.md`](03_g7_install.md)                     | done    |
| 4  | Stage G7                           | [`04_stage_on_g7.md`](04_stage_on_g7.md)                   | done    |
| 5  | Cutover                            | [`05_cutover.md`](05_cutover.md)                           | done    |
| 6  | Decommission G4's box role         | [`06_decommission_g4.md`](06_decommission_g4.md)           | in progress |

Status values: draft / planned / in progress / done / superseded / discarded.

## Log

Append-only. Newest at the bottom.

- 2026-10-14 : bootstrapped the plan folder from a read-only inventory of G4 (services, timers, docker, /srv, ~/cred layout, repo dirty/unpushed state, gitignored data, untracked /etc state). Learned that `~/saved_state` is the snapshot of G7's current install. Raised Q1-Q11.
- 2026-10-14 : folded Q1-Q11. G7 already wiped; same tunnel with the JSON moved (downtime fine); fresh clones plus curated data; SSH key on G4; all toolchains on G7; Tailscale SSH off on G4; no DNS workaround on G7; keep /srv/gramps-web on G4 for 14 days. Found G4 has no git credential helper and no repomgr App key, so private-repo clones on G7 have no read path yet: raised Q12. Q10 left the ~/.claude part open: raised Q13. Rewrote phases 1, 2, 4, 5, 6 for the moved tunnel and fresh clones.
- 2026-10-14 : folded Q12 (agent forwarding from G4, no credential on G7; added `ssh-add -c` and per-session `-A` as mitigations, and a phase 3 check that forwarding works through Tailscale SSH) and Q13 (memory in repos; all `~/.claude/projects/*/memory/` on G4 are empty, nothing to move). Updated the plans README: public on GitHub, underscore naming, folders for multi-phase efforts.
- 2026-10-14 : phase 1 started. Reviewed the plan (no corrections; filtered the Tailscale prefs read so no key material reaches a log). Took the G4 snapshot into `~/saved_state_g4/`. Read UFW and Tailscale state via handoff. Found fail2ban and the usb-storage block missing despite the doc, and an enabled iperf3 server: raised Q14, Q15. Waiting on the Cloudflare dashboard check.
- 2026-10-14 : folded Q14 (skip fail2ban and the usb-storage block on G7, fix the doc) and Q15 (no iperf3 on G7) into phase 3. Replaced the manual dashboard check with a read-only API dump script (`~/handoff-logs/g4_to_g7/cf_dump.sh` on G4, output stays local because Access policies hold email addresses).
- 2026-10-14 : phase 1 done. Cloudflare dump: HSTS on without preload, Full (strict), TLS 1.2, three proxied CNAMEs to the one healthy tunnel (named `pmn-14g4`), and an Access application for each of apex, wildcard and `family`. Nothing in the zone needs changing for the swap. Closing review: no corrections; phase 5 already has no HSTS step since the tunnel is kept.
- 2026-10-14 : phase 2 started. Review: the agent is `gcr-ssh-agent` with its own askpass, so `ssh-add -c` should work; added a check that the confirm dialog appears and that denying it fails, a dedicated key path so the agent cannot auto-load it unconstrained, and GitHub host keys from `api.github.com/meta`.
- 2026-10-14 : phase 2, GitHub key created and registered. `ssh-add -c` failed: no `/usr/bin/ssh-askpass` for OpenSSH's agent, and the GNOME agent had no display variables. Dropped the confirm constraint for `ssh-add -t 1h` (Q16). Also found G4 has no openssh-server, so Q8a would cut remote access: phase 6 now installs openssh-server on the tailnet only before turning Tailscale SSH off.
- 2026-10-14 : phase 2 done. `ssh-add -t 1h` key works from G4 and from Claude sessions sharing the agent. Remotes to ssh everywhere, 12 branches pushed, 10 merged local-only branches dropped, `va` dropped, house-renderer dirty files left to their session. Box rule updated in `linux-box-cloudflare` (84ad86e). Closing review: phase 4 needed a gate for the house-renderer files, added.
- 2026-10-14 : phase 3 started; G7 is freshly installed. Review: the bootstrap README fetched `bootstrap.sh` from `main`, which 404s (branch is `master`), fixed; `install_basics.sh` duplicates `bootstrap.sh`, so it is skipped. Console order: bootstrap.sh, install_tools.sh, then Tailscale up, the rest remote.
- 2026-10-14 : correction: `install_basics.sh` does not duplicate `bootstrap.sh` (which is only git and a clone); the earlier reading misattributed concatenated output. On G7 it was skipped, so `install_tools.sh` ran without `~/.local/bin` and failed in four places (batcat link, btop needing `make`, `fonts-hack-ttf` gone in 26.04, `p7zip-desktop` snap gone). Fixed `install_tools.sh` and the README order in `~/bootstrap`. G7 joined the tailnet as `g7` with Tailscale SSH; its host key pinned on G4 from `tailscale status`. User authorized running commands on G7 over ssh from this G4 session.
- 2026-10-14 : phase 3, G7 bootstrap done: install_basics, tools fixups, gitconfig.local, setup_gnome. rtk: hook removed from dotfiles settings at the user's call, rtk install on G7 rolled back. Reboot pending on G7 for the kernel.
- 2026-10-14 : phase 3 done. G7 hardened (Pro, UFW, sysctl, linger, unattended-upgrades), always-on applied, packages and toolchains installed, Claude logged in, `ssh -A` GitHub path verified both ways. `sensors-detect` dropped from `setup-always-on.sh` after it flooded the log on the NVIDIA laptop. Closing review: lid-closed test moved to phase 5, Playwright to phase 4.
- 2026-10-14 : phase 4 staged: 41 repos cloned via `ssh -A`, home and gitignored data copied, nginx (8090, 8091) and Gramps (8092) answering on G7 loopback, Gramps counts match G4. Fixes pushed along the way: `hub` site enabled by `deploy-configs.sh`, `klide` in `repos.toml`, global git ignore in dotfiles; `~/.local/bin` PATH block in both `~/.bashrc`; `build-essential` on G7. Waiting on a Gramps login test through a port forward.
- 2026-10-14 : phase 4 done, closed on matching Gramps counts instead of a login test. Closing review: phase 5 must stop G7's rehearsal stack before replacing its data, and copies the frozen data by the same tar route as the rehearsal.
- 2026-10-14 : phase 5 started. Lid-closed reboot test skipped for now at the user's call; still open.
- 2026-10-14 : phase 5 done. G7 serves all three hostnames through the same tunnel, verified from a phone on mobile data; frozen Gramps data matches; first G7 backup to R2 clean. G4 keeps the stopped stack, its tunnel JSON and /srv/gramps-web for rollback until phase 6. Open: lid-closed reboot test, Gramps edit-and-reload check, fixed restic --host (phase 6).
- 2026-10-15 : phase 6 started on the user's call, without the few days of G7 running alone. Review corrections: keep the cloudflared package on G4 (management CLI); `.admin.env` can only be partly filled (restic values, box host), the three admin credentials are reissued by the user; G4 Docker images and volumes added to the cleanup; the Gramps edit check gates the deletion of G4's tunnel JSON, which ends rollback.
- 2026-10-15 : phase 6 mostly done. G4 holds no box service or box-only secret: tunnel JSON shredded, nginx and Docker leftovers gone, admin env started. G4 reached through openssh-server on the tailnet, Tailscale SSH off. Docs: Q14 changes and the same-tunnel move procedure. Open items with the user listed in `06_decommission_g4.md`; the phase stays in progress until they close.
- 2026-10-15 : user keeps the old GitHub PAT (not revoked). Filled the three Cloudflare ids in G4's `.admin.env` from the phase 1 dump; five admin secrets remain for the user.
- 2026-10-15 : admin credentials restored on G4 instead of reissued (old admin machine wiped with care, file only forgotten): token values from the password manager, `admin-scripts` recreated for a new password, template names the account. `make admin-verify` ready on G4. Open: delete G4 `/srv/gramps-web` from 2026-10-28, G7 lid-closed reboot test, optional items.
- 2026-10-15 : restic backups run under the fixed host `gramps-box`; the user renamed all 63 existing snapshots to it with `restic rewrite --forget` (blocked for Claude), check clean. Corrects phase 5: an idle host group never ages out. G7 clone updated. Open: delete G4 `/srv/gramps-web` from 2026-10-28, G7 lid-closed reboot test, optional G4 lid and linger revert.
- 2026-10-15 : G7 lid-closed reboot test passed: back on the tailnet with the lid closed and no login, tunnel registered 4 connections, nginx, Gramps and the backup timer up. Open: delete G4 `/srv/gramps-web` from 2026-10-28, optional G4 lid and linger revert.
- 2026-10-15 : G4 always-on reverted (lid back to suspend, logind drop-in removed) and linger disabled. The logind restart broke the GNOME session; warning added to `always-on-server.md`. G4 reboot pending with the user. Open: delete G4 `/srv/gramps-web` from 2026-10-28.
- 2026-10-15 : gap check of the setup against the repos (bash history on both hosts): box apt list, docker group, linger, nginx default site removal and the toolchain script added to `linux-box-cloudflare` (`01_box_setup.md`, `deploy-configs.sh`, `setup-toolchains.sh`); new `03_trusted_machine.md` for the GitHub key and G4 remote access; bootstrap writes the `~/.local/bin` PATH block into `.bashrc` and installs xtermcontrol, shellcheck, zellij. Finding: the `docker` group makes the box user root-equivalent, so it can read the tunnel JSON despite the box rule; fix not chosen yet.
