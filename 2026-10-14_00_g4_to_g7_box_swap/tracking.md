# implementation tracking

Swap the unattended box from G4 to G7 and make G4 the trusted machine.
G7 is rebuilt from the linux-box-cloudflare repo and the box plan notes, services move over in one cutover, and G4 loses every box-only secret and service.
Analysis, inventory and open questions in [`00_start.md`](00_start.md).

## Key decisions

- Build G7 in parallel while G4 serves; one cutover window, downtime accepted; G4 untouched until G7 is verified.
- Same tunnel: the JSON moves from G4 to G7 at cutover, no DNS change; never two connectors running at once; G4's copy deleted in phase 6.
- Fresh clones on G7 plus a curated copy of gitignored data, so everything unpushed must be pushed from G4 first.
- G7 was wiped before the plan; lost trusted material is reissued, not recovered.
- GitHub key on G4 only; G7 reaches GitHub through `ssh -A` from G4, with `ssh-add -c` confirmation.
- Claude memory goes into the repos, not `~/.claude`.
- Cloudflare `cert.pem` lives on G4 only, created when next needed.
- This folder is public on GitHub: nothing secret-adjacent in it.
- Every gap found in `linux-box-cloudflare` docs while building G7 is fixed in that repo.

## Phases

| #  | Phase                              | Plan                                                       | Status  |
| -- | ---------------------------------- | ---------------------------------------------------------- | ------- |
| 1  | Prepare and close inventory gaps   | [`01_prepare.md`](01_prepare.md)                           | draft   |
| 2  | Make G4 the trusted machine        | [`02_g4_trusted.md`](02_g4_trusted.md)                     | draft   |
| 3  | Install G7 as the box              | [`03_g7_install.md`](03_g7_install.md)                     | draft   |
| 4  | Stage G7                           | [`04_stage_on_g7.md`](04_stage_on_g7.md)                   | draft   |
| 5  | Cutover                            | [`05_cutover.md`](05_cutover.md)                           | draft   |
| 6  | Decommission G4's box role         | [`06_decommission_g4.md`](06_decommission_g4.md)           | draft   |

Status values: draft / planned / in progress / done / superseded / discarded.

## Log

Append-only. Newest at the bottom.

- 2026-10-14 : bootstrapped the plan folder from a read-only inventory of G4 (services, timers, docker, /srv, ~/cred layout, repo dirty/unpushed state, gitignored data, untracked /etc state). Learned that `~/saved_state` is the snapshot of G7's current install. Raised Q1-Q11.
- 2026-10-14 : folded Q1-Q11. G7 already wiped; same tunnel with the JSON moved (downtime fine); fresh clones plus curated data; SSH key on G4; all toolchains on G7; Tailscale SSH off on G4; no DNS workaround on G7; keep /srv/gramps-web on G4 for 14 days. Found G4 has no git credential helper and no repomgr App key, so private-repo clones on G7 have no read path yet: raised Q12. Q10 left the ~/.claude part open: raised Q13. Rewrote phases 1, 2, 4, 5, 6 for the moved tunnel and fresh clones.
- 2026-10-14 : folded Q12 (agent forwarding from G4, no credential on G7; added `ssh-add -c` and per-session `-A` as mitigations, and a phase 3 check that forwarding works through Tailscale SSH) and Q13 (memory in repos; all `~/.claude/projects/*/memory/` on G4 are empty, nothing to move). Updated the plans README: public on GitHub, underscore naming, folders for multi-phase efforts.
