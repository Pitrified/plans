---
status: done
---

# Phase 2 - Make G4 the trusted machine

## Overview

G4 gains the credentials the box never holds, and pushes everything, because G7 gets fresh clones (`00_start.md` Q4): what is not on GitHub does not reach G7.
G4 still runs the box services until phase 5, so for this window it is both server and trusted machine: keep the window short.
Context: [`00_start.md`](00_start.md) Q4, Q5, Q8. Depends on [`01_prepare.md`](01_prepare.md).

## Goals

1. G4 can push to GitHub over SSH.
2. All unpushed and uncommitted work on G4 is on GitHub.
3. The `local-box.md` rule reflects the new roles.

## Plan

- GitHub (user, in a G4 terminal):
  `ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_github` with a passphrase; register in GitHub as an authentication key.
  `~/.ssh/config`: `Host github.com` with that `IdentityFile` and `IdentitiesOnly yes`.
  GitHub host key into `known_hosts` from `api.github.com/meta` (fetched over TLS), not by accepting the first-connection prompt.
  Load the key when needed with `ssh-add -t 1h ~/.ssh/id_ed25519_github` (Q16); `ssh -T git@github.com` greets the user.
  Switch remotes to ssh on G4 (`git remote set-url`), every repo plus `~/dotfiles`, `~/bootstrap`.
- Push unpushed work: `genealogy-gramps-fn` main, `epub-fixer`, `klide`, `pose-tools`, `house-renderer` (ahead branches, the 7 local-only branches, 3 dirty files), `flutter-setup-project` local-only branches, `plans`, `~/bootstrap`.
  For each local-only branch: push, or write it down as dropped.
  Rerun the dirty/ahead/no-upstream scan from the inventory over `~/repos`, `~/dotfiles` and `~/bootstrap`; it must come back empty or every leftover accepted in the log.
- `va` in `~/repos` is not a git repo: decide whether it is data to copy in phase 4 or dust.
- Browser logins on G4 as needed: GitHub, Cloudflare dashboard, Claude, Google.
- Update `linux-box-cloudflare/configs/claude/rules/local-box.md`: no GitHub credentials live on the box; pushes happen from G4, or from the box only inside an `ssh -A` session from G4; unattended sessions cannot push. Replace the `g7` mention. Commit and push from G4.
- Do **not** create `.admin.env` in `genealogy-gramps-fn` on G4 yet: its presence makes the Makefile refuse box targets, and G4 is still the box until phase 5.

## Out of scope

- Turning off Tailscale SSH on G4 (phase 6: G4 is still reached remotely until then).
- Reissuing Gramps admin credentials and `cert.pem` (phase 6 and on demand).

## Done when

- `ssh -T git@github.com` greets the user from G4.
- The unpushed scan is empty or every leftover is a written decision.

## What the implementation found

- Key at `~/.ssh/id_ed25519_github`, registered as an authentication key; `~/.ssh/config` pins it for `github.com`; host keys from `api.github.com/meta`.
- `ssh-add -c` could not work (no `/usr/bin/ssh-askpass`, and the GNOME agent started without display variables). Replaced by `ssh-add -t 1h` (`00_start.md` Q16).
  The GNOME agent lists every key in `~/.ssh` as available even when not loaded, so `ssh-add -l` showing the key does not mean it is usable.
- Remotes switched to ssh in all 41 repos plus `~/dotfiles` and `~/bootstrap` (two already were).
- Pushed 12 fast-forwards: `genealogy-gramps-fn` main, `house-renderer` main and 5 feature branches, `klide` main, `epub-fixer` effort-07, `pose-tools` face-landmarker, `plans`, `bootstrap`.
- The 10 local-only branches (3 `flutter-setup-project`, 7 `house-renderer`) are all merged into `origin/main` with no unique commits: dropped, nothing lost.
- Leftovers, accepted:
  `house-renderer` has 3 uncommitted files on `main` (bagno 5 work from 2026-10-14), left to the session working on it; phase 4 checks it again before cloning.
  `~/repos/va` (only a `.claude/` folder) is dust, not copied.
  Some branches are behind GitHub (pushed from the old G7); irrelevant for fresh clones.
- `local-box.md` rule updated and pushed in `linux-box-cloudflare`.
- Browser logins on G4 are done as needed, not as a step.
