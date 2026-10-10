---
status: draft
---

# Phase 3 - Git flow, credentials and the `sbx` wrapper

## Overview

Everything that crosses the boundary: repos in, commits out, the Claude login,
the API keys. After this phase the VM is usable for real work, CPU-only.
Context: [`00_start.md`](00_start.md), depends on
[`02_guest_base_and_provisioning.md`](02_guest_base_and_provisioning.md).

## Goals

1. Host SSH config for the VM, with agent forwarding off.
2. A `sandbox` git remote per project, and the in and out commands.
3. A `sbx` wrapper so the two flows are one command each.
4. The Claude login done in the VM, and the carry step that keeps it across a
   rebuild.
5. The API keys in place.

## Plan

### SSH

`~/.ssh/config` on the host:

```
Host sbx
    HostName 10.77.0.10
    User ai
    ForwardAgent no
    IdentitiesOnly yes
    IdentityFile ~/.ssh/<key>
```

### Git identity in the VM

In the provisioning script, name and email only. No credential helper, no
GitHub host key, no token.

```bash
git config --global user.name  "<name>"
git config --global user.email "<email>"
git config --global receive.denyCurrentBranch updateInstead
```

`updateInstead` lets the host push into a checked-out branch and updates the
working tree, as long as that tree is clean. A dirty tree makes the push fail,
which is the right outcome: commit or stash in the VM first.

### A project, the first time

```bash
ssh sbx 'git init -q ~/projects/<proj>'
git remote add sandbox sbx:projects/<proj>
git push sandbox <branch>
ssh sbx 'git -C ~/projects/<proj> checkout <branch>'
```

### In

```bash
git push sandbox <branch>
```

### Out

```bash
git fetch sandbox
git log -p ..sandbox/<branch>          # review
git merge --ff-only sandbox/<branch>   # host branch and working tree take it
git push
```

- Merge the fetched ref, never `git pull sandbox`: pull fetches again.
- `--ff-only` refuses when the host also committed on that branch, and leaves
  the resolution to a person.
- Commits arrive with the VM's identity and unsigned.

### `sbx` wrapper

Two verbs over the above, run from inside a host repo:

- `sbx in [branch]`: add the remote if missing, create the repo in the VM if
  missing, push the current branch.
- `sbx out [branch]`: fetch, show `git log -p ..sandbox/<branch>` in the pager,
  ask, then fast-forward. It does **not** push to GitHub: that stays a separate,
  deliberate `git push`.

Plus `sbx ssh` (attach to the tmux or zellij session) and `sbx ip`. Where the
file lives follows `00_start.md` Q1.

### Dotfiles

The dotfiles repo goes in like any project (`sbx in` from the host's clone) and
the provisioning script runs its installer, which links the Claude config into
`~/.claude`. Changes the assistant makes to it come out through `sbx out`.

Files that Claude Code rewrites (`settings.json`) may replace their symlink with
a regular file. The next rebuild restores the link; edits made in between do not
reach the dotfiles repo unless copied back.

### Claude login

Once, in the VM, over SSH: run `claude`, open the URL in any browser, paste the
code back.

Carry out, immediately before deleting the instance, every time (the token
refreshes itself, so an older copy may be dead):

```bash
mkdir -p ~/.local/state/sbx && chmod 700 ~/.local/state/sbx
incus file pull sbx/home/ai/.claude/.credentials.json ~/.local/state/sbx/
incus file pull sbx/home/ai/.claude.json              ~/.local/state/sbx/   # Q8
chmod 600 ~/.local/state/sbx/*
```

Carry in, after the provisioning script has run:

```bash
incus file push --uid 1000 --gid 1000 --mode 600 \
  ~/.local/state/sbx/.credentials.json sbx/home/ai/.claude/.credentials.json
incus file push --uid 1000 --gid 1000 --mode 600 \
  ~/.local/state/sbx/.claude.json sbx/home/ai/.claude.json
```

The path of the credentials file is from memory. Confirm it on the first login
with `ls -la ~/.claude`.

### API keys

`00_start.md` Q7: a `.env` on the host at `~/.local/state/sbx/sbx.env`, mode
600, pushed to `/home/ai/.config/sbx.env` by the same carry-in step and sourced
from the shell rc. Only keys made for the sandbox, each with a spend cap.

## Pitfalls

- **A dirty tree in the VM blocks `sbx in`.** Expected; the wrapper should say
  so plainly.
- **`sbx out` across several branches.** The assistant may create branches the
  host has never seen. `git fetch sandbox` brings them all; the wrapper lists
  the ones ahead of their host counterpart.
- **Suspected compromise.** Do not carry the credentials out. Log the session
  out from the Claude account, rotate the keys in `sbx.env`, rebuild, log in
  again.

## Out of scope

- The rebuild script that calls the carry steps: phase 5.

## Done when

- A real project round-trips: pushed in, changed and committed by the assistant
  in the VM, fetched, reviewed, fast-forwarded and pushed to GitHub from the
  host.
- `ssh sbx 'ssh-add -l'` reports no agent.
- `ssh sbx 'git -C ~/projects/<proj> push origin'` fails for lack of a remote
  or a credential.
- The Claude login survives a delete and relaunch of the instance.

## Rollback

Remove the `sandbox` remotes (`git remote remove sandbox`), the `Host sbx`
block, the wrapper, and `~/.local/state/sbx`.
