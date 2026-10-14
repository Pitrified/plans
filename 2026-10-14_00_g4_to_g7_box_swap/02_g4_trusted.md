---
status: in progress
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
