---
status: in progress
priority: 1
description: |
  Swap machine roles: G7 is wiped and becomes the unattended box (tunnel, nginx, Gramps Web, Claude sessions);
  G4 stops being the box and becomes the trusted machine (GitHub key, browser logins, Cloudflare management, Gramps admin).
comment: |
  Box-level effort, spans two hosts. Executed partly by the user (sudo, browser logins, the G7 install),
  partly by Claude sessions on each host. Not a repo plan: it lives in ~/repos/plans.
---

# G4 to G7 box swap

## The idea

User's framing (2026-10-14):
"We are swapping the box used as unattended machine.
The current one, where this session is being run, is G4. The future one will be G7.
G4 holds a cloudflare tunnel, a few applications, some settings and so on.
Most of the setup should be tracked in the linux-box-cloudflare repository.
If we need some login or SSH, G4 will be a trusted box from now on.
We will do browser logins, register the SSH connection to GitHub and so on.
Of course we want to do that safely."

Follow-up: `~/saved_state` on G4 holds a snapshot of the G7 being dismissed (its current install).

Reading of that: a two-way role swap, not only a server move.

| Host | Today | After |
| --- | --- | --- |
| G4 (`pmn-14g4`) | unattended low-secret box | trusted machine: GitHub SSH key, browser logins, `cloudflared` management (`cert.pem`), Gramps admin machine (`.admin.env`) |
| G7 (`pmn-g7`) | trusted machine (fine-grained PAT, pushes, presumably Gramps admin) | wiped, reinstalled, unattended low-secret box |

The box rule in `configs/claude/rules/local-box.md` (no GitHub credentials, root-only revocable service credentials, `/etc` from repo copies) moves with the role: it applies to G7 afterwards and stops applying to G4.

## Inventory of G4 (read-only, 2026-10-14)

### Tracked in linux-box-cloudflare and redeployable

- `configs/cloudflared/config.yml`: tunnel `ea1edca9-...`, ingress for `pitrified.qzz.io` (8090), `cc-kb` (8091), `family` (8092).
- `configs/nginx/hub`, `configs/nginx/cc-kb`, `configs/sysctl/99-hardening.conf`, all via `scripts/deploy-configs.sh`.
- `/var/www/hub` symlink to `sites/landing/`, `/var/www/cc-kb` symlink to `../controcanto/site` (needs a mkdocs build of controcanto on G7).
- `scripts/setup-always-on.sh` (gsettings lid, logind `keep-awake.conf`, lm-sensors).
- `scripts/setup-disposable-box.sh` (symlinks the `local-box.md` rule).
- `configs/repomgr/repos.toml` (repo list; `REPOMGR_CONFIG` exported in `~/.bash_aliases.local`).
- `docs/01_box_setup.md`: hardening, Ubuntu Pro, UFW, fail2ban, cloudflared from apt (codename fallback to `noble`), HSTS-on-migration note, decommission checklist.

### Live on G4 but not in that repo

Recorded only in the box plan notes in this repo, so those notes are the checklist:

- Tailscale SSH (`tailscale up --ssh`), no openssh listening.
- Linger for `pmn` (`2026-08-23_01`).
- IPv6 DNS workaround on the wired link: `ipv6.dns` = Cloudflare v6, `ipv4.ignore-auto-dns=yes` (`2026-08-23_00`). Still applied today.
- `www-data` traverse ACL on `/home/pmn` (from `01_box_setup.md` phase 3).
- `/dev/kvm` ACL `user:pmn:rw-` (`2026-09-25_00`).
- `pmn` in the `docker` group (`2026-08-23_02`).
- Ubuntu Pro attached: esm-apps, esm-infra, livepatch.
- apt sources: `cloudflared.list`, `tailscale.list`, `gierens.list` (eza).
- Installed via notes: git-lfs (Ubuntu repo), Flutter at `~/flutter`, Android SDK at `~/android-sdk`, JDK 17, emulator + AVD, calibre (`--no-install-recommends`), Playwright Chromium + Firefox, docker.io + compose v2, restic.
- PATH fix for non-interactive shells (`2026-09-24_00`).
- Unverified without sudo: UFW rules, fail2ban, `modprobe.d` usb-storage block, sshd config. To check in phase 1.

### Applications and state

- **Gramps Web** (`genealogy-gramps-fn`): 3 containers (grampsweb, celery, valkey) on `127.0.0.1:8092`.
  Irreplaceable data in `/srv/gramps-web/{db,media,users,index}`, root-owned.
  Secrets in the repo root: `.env` (Flask secret key; changing it logs everyone out), `.backup.env`, `.restic.env` (R2 + repo password).
  User systemd `gramps-backup.timer` (symlinked from the repo) pushes nightly to R2 and commits a tree snapshot.
  `main` is 5 commits ahead of origin (nightly snapshots the box cannot push).
- **cc-kb**: static mkdocs build of `controcanto`, served by nginx.
- **Landing page**: static, from this repo.
- **Claude Code**: `~/.claude` (credentials, project transcripts, memory under `projects/-home-pmn/memory/`), settings and skills symlinked from `~/dotfiles`.

### Home data outside git

- `~/cred/{controcanto,laife,pose-tools,repomgr}/.env`.
- `~/data` 155M, `~/ephem` 66M, `~/other` 27M, `~/opencamera_backups`, `~/handoff-logs`, `~/cf-setup-logs`.
- `~/dotfiles`, `~/bootstrap` (clean, pushed), `~/setup_bootstrap` (not a git repo).
- `~/repos` 19G total, 41 git repos plus `va` (not a git repo).
- Gitignored but not rebuildable, about 1.5G: `house-renderer` renders/plans/sources/textures (~1G) and `.r2.env`, `epub-fixer/books/*`, `controcanto/kb/sources` snapshots, `snap_fit` cache/data, `abyss/cache`, `genealogy-gramps-fn` env files, exports, photos.
- Unpushed work: `genealogy-gramps-fn` main, `epub-fixer` effort-07 branch, `klide` main, `pose-tools` feat/face-landmarker, `house-renderer` (main + 5 ahead branches + 7 with no upstream + 3 dirty files), `flutter-setup-project` (3 branches with no upstream).

### Not found on G4

No user crontab, no `/etc/cron.d` entries of ours, no other running app services (`iperf3.service` is running; origin unknown, to check in phase 1).

## Proposed approach

Prepare G7 in parallel while G4 keeps serving, then cut over in one window, then strip G4.
Downtime is acceptable (Q2, Q6), so the cutover favours simplicity over a seamless switch.

1. Prepare: freeze the inventory, check the sudo-only gaps, list what has to be reissued.
2. Make G4 trusted: GitHub SSH key, push all unpushed work, Tailscale SSH server off.
3. Install G7 as a box from the repo docs, fixing the docs wherever they turn out wrong.
4. Stage G7: clone repos, copy the curated gitignored data and home data, bring nginx and Gramps up on loopback. No tunnel on G7 yet.
5. Cutover: stop the tunnel and Gramps on G4, move the frozen Gramps data and the tunnel JSON to G7, start both there, verify.
6. Decommission G4's box role: remove the tunnel JSON and services from G4, install the admin role, reissue what was lost with G7.

Rollback stays cheap until phase 6: G4's copy of the JSON and its stopped Gramps stack stay in place until G7 has been verified.

## Decisions so far

- **Build in parallel, cut over once.** The alternative, moving service by service, means two boxes serving the zone at the same time and two Gramps instances that can both be written to. One window is simpler and shorter in total.
- **Same tunnel, JSON moved to G7** (Q2). No DNS change at all.
  Consequence: the JSON is not revoked, so the copy on G4 must be deleted in phase 6, and no backup of it may exist elsewhere.
  Pitfall: two `cloudflared` instances with the same JSON both register as connectors and Cloudflare spreads traffic between them, so G4's must be stopped before G7's starts.
- **Cloudflare management login (`cert.pem`) only on G4, and only when next needed** (a new hostname or `route dns`). The swap itself needs none. Per `01_box_setup.md` it never goes on the serving box.
- **Secrets travel G4 to G7 over Tailscale only** during this migration, directly host to host. The existing password-protected `~/cred` archive on OneDrive stays as the user's backup and is not part of the transfer path.
- **G7 is already wiped** (Q1). Whatever it held and is not in `~/saved_state` or `~/cred` is reissued, not recovered (Q3).
- **Repos are cloned fresh on G7** (Q4); only a curated list of gitignored data is copied. The `house-renderer` renders are already on R2.
  So every unpushed branch and dirty file on G4 must be pushed in phase 2, or it does not reach G7.
- **GitHub on G7 through agent forwarding from G4** (Q12). The key never leaves G4; G7 can clone, pull and push only while an `ssh -A` session from G4 is open.
  Consequences: G7 remotes use ssh URLs; unattended work on G7 (Remote Control sessions, timers) cannot reach private repos or push, which matches the box rule.
  Risk: while a forwarded session is open, root on G7 can use the agent. Mitigations: forward per session with `-A`, never `ForwardAgent yes` in config; load the key with `ssh-add -c` so each use asks for confirmation on G4.
  To verify in phase 3: agent forwarding works through Tailscale SSH on G7.
- **Claude memory lives in the repos, not in `~/.claude`** (Q13). Nothing to move today; the rule applies from now on.
- **The plans repo is on GitHub and public** (Q10). Nothing secret-adjacent goes in this folder: no tokens, no IPs, no Gramps tree IDs, no network names.
  The plans `README.md` still says local-only; that is out of scope here.

## Reissue list (from Q3)

Lost with G7, to recreate on G4 in phase 6:

- Fine-grained GitHub PAT: revoke it in the GitHub UI (the token still exists server-side), replaced by the G4 SSH key.
- Gramps `.admin.env`: new R2 token with delete rights, new Cloudflare Access token, Gramps admin credential.
  The restic repository password is the same one already in `.restic.env` on G4, so it is not lost; copy it before phase 6 deletes `.restic.env` from G4.
- Cloudflare `cert.pem`: `cloudflared tunnel login` on G4, when next needed.
- Browser logins: redone on G4 as needed.

## Open questions

- Q1: Is G7 being wiped and reinstalled (fresh Ubuntu 26.04), or kept with its current install and repurposed?
  `~/saved_state` (apt/snap/dconf lists, NetworkManager profiles, home tree) suggests a wipe.
  - a. Fresh install of Ubuntu 26.04, same as G4.
  - b. Keep the install, remove trusted material from it.
  - Recommended: a, because a former trusted machine keeps tokens, browser profiles and keyrings in places a cleanup will miss; a wipe is the only clean low-secret starting point.
  - ANS: it's already scratched completely.
- Q2: Tunnel: create a new tunnel for G7, or move the existing `ea1edca9` JSON?
  - a. New tunnel, created from G4 (`cloudflared tunnel login` there), JSON copied to G7, DNS repointed with `--overwrite-dns`, old tunnel deleted in phase 6.
  - b. Copy the existing JSON to G7, no DNS change.
  - Recommended: a, because deleting the old tunnel revokes every copy of its JSON (G4 disk, backups), and the new tunnel can run on G7 with no routes before cutover, so the DNS switch is the only downtime.
  - ANS: b. we do not care about downtime. we can stop for how much we need.
- Q3: Where is G7's trusted material today, and is it safely off G7 before the wipe?
  Candidates: the fine-grained GitHub PAT, Cloudflare `cert.pem` (if management ran there), Gramps `.admin.env` (R2 delete token, Access token, admin credential, repo password), browser logins, `20261013_cred.7z` (listed in the G7 home tree).
  - ANS: who knows. we will reissue them. we have the `~/cred` folder zipped with password on onedrive. the rest is dust
- Q4: Repos transfer.
  - a. `rsync ~/repos` G4 to G7 over Tailscale, excluding rebuildable dirs (`.venv`, `node_modules`, `.dart_tool`, `build`, caches), then rebuild envs on G7.
  - b. Fresh clones via repomgr on G7, plus a curated copy of the gitignored files listed above.
  - Recommended: a, because it carries the 1.5G of gitignored data, the unpushed branches and the dirty files in one step with nothing to curate; b loses whatever the curated list misses.
  - ANS: b. the big ass render folder in house is already on r2.
- Q5: GitHub access on G4.
  - a. New ed25519 SSH key with a passphrase, held by the GNOME keyring agent, registered as an authentication key; switch remotes from https to ssh on G4.
  - b. Keep using a fine-grained PAT over https, moved from G7.
  - Recommended: a, as requested; the PAT on G7 is then revoked in the GitHub UI once G4 pushes work (it can be scoped out with the G7 wipe).
  - ANS: a.
- Q6: Gramps downtime window: the cutover stops the family site for roughly 15 to 30 minutes. Announce it to the family users, or just pick a quiet hour?
  - ANS: not a problem.
- Q7: Which toolchains go on G7? Claude sessions will run on G7, so dev work moves there too.
  Candidates from G4: Flutter + Android SDK + emulator, calibre, Playwright browsers, docker, restic, git-lfs.
  - a. All of them, each from its existing plan note.
  - b. Only what the services need (docker, restic, nginx, cloudflared), the rest on demand.
  - Recommended: a, because the notes already hold the exact commands and gotchas, and a missing toolchain is found mid-task otherwise.
  - ANS: a.
- Q8: Tailscale SSH on G4 after the swap. Today G4 runs the Tailscale SSH server so other devices can reach it.
  Once G4 holds secrets, an SSH path from the box into G4 is the wrong direction.
  - a. Turn the SSH server off on G4 (`tailscale set --ssh=false`); G4 is a client only.
  - b. Keep it, and add a Tailscale ACL so only your personal devices (not G7) may connect to G4.
  - Recommended: a, unless you need to reach G4 remotely; then b.
  - ANS: a.
- Q9: The IPv6 DNS workaround (`2026-08-23_00`) is still applied on G4's wired link. Carry it to G7?
  - a. No, start with stock DHCP DNS on G7 and reapply the note only if the IPv4 outage returns.
  - b. Yes, apply on day one.
  - Recommended: a, because it was a workaround for a specific ISP outage and pins DNS to IPv6 only.
  - ANS: a.
- Q10: The plans repo and `~/.claude` history: which host keeps them?
  Box-level plans describe the box, so they belong on G7; Claude transcripts and memory are per host.
  - a. `~/repos/plans` moves to G7 with the rest of `~/repos`; copy `~/.claude/projects/*/memory/` to G7; G4 starts a fresh `~/.claude` for its new role (keeping dotfiles links).
  - b. Copy all of `~/.claude` except `.credentials.json`.
  - Recommended: a, because transcripts are bulky and host-specific, while memory is the part that carries knowledge.
  - ANS: plans is actually tracked on github do not believe the readme. also means that this plan folder will be public.
- Q11: Keep a copy of `/srv/gramps-web` on G4 after cutover, as a cold fallback?
  - a. Yes, for 14 days after a verified R2 backup from G7, then delete.
  - b. No, delete at decommission; R2 is the backup.
  - Recommended: a, because it costs 1.5M and covers the case where the first G7 backup is broken in a way that only shows on restore.
  - ANS: a.
- Q12: Private repos on G7 (raised while folding Q4).
  Q4 chose fresh clones on G7, but `epub-fixer`, `controcanto`, `genealogy-gramps-fn` and `house-renderer` are private, and the box holds no GitHub credentials.
  G4 today has no git credential helper and no repomgr GitHub App key (`~/.config/github-apps/` does not exist), so there is no existing read path to reuse.
  The same question decides how G7 pulls updates later (for example the controcanto rebuild behind cc-kb).
  - a. Read-only deploy key per private repo, generated on G7 and registered from G4. Scoped to one repo, cannot push, revocable per repo.
  - b. Clone the private repos on G4 and rsync them to G7; G7 never talks to GitHub for them, and updates are pushed from G4 the same way.
  - c. The repomgr GitHub App with a read-only installation, its PEM on G7.
  - Recommended: a, because it keeps fresh clones and later pulls working on G7 while the worst case of a box compromise is read access to four repos; b turns every update into a manual step from G4; c puts an app-wide key on the box.
  - ANS: none of them. G4 has the GitHub SSH key; `ssh -A` from G4 into G7 and clone, pull and push from that session.
- Q13: Claude Code state. Q10's answer settled the plans repo; the `~/.claude` part is still open.
  - a. Copy only `~/.claude/projects/*/memory/` to G7; G4 keeps its `~/.claude` as is, minus the `local-box.md` rule.
  - b. Copy all of `~/.claude` except `.credentials.json`.
  - c. Nothing; G7 starts fresh.
  - Recommended: a, because memory carries knowledge while transcripts are bulky and host-specific.
  - ANS: memories that are useful go into the respective repos, so they are not local to one Claude install.
    Checked 2026-10-14: every `~/.claude/projects/*/memory/` on G4 is empty, so nothing moves now.
- Q14: Two hardening steps in `01_box_setup.md` phase 1 were never applied on G4: fail2ban and the usb-storage block (findings in `01_prepare.md`).
  - a. Skip both on G7 and change the doc: fail2ban only when openssh-server is installed; the usb-storage block as optional.
  - b. Apply both on G7 as the doc says.
  - Recommended: a, because fail2ban has no log to watch on a box with no sshd and no open port, and blocking USB storage gets in the way on a laptop you may plug a disk into; the doc should describe the box as it is.
  - ANS: a.
- Q15: iperf3 runs as an enabled server on G4 (`*:5201`, reachable from Tailscale peers).
  - a. Do not install it on G7; run `iperf3 -s` by hand when measuring.
  - b. Install it on G7 like G4.
  - Recommended: a, because a listening daemon nobody uses is attack surface with no benefit.
  - ANS: a.
