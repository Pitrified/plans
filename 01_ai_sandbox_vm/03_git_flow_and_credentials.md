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

The wrapper carries its own SSH options, so nothing is added to
`~/.ssh/config` and no other tool picks them up by accident: a dedicated key
(`~/.ssh/sbx_ed25519`), `ForwardAgent=no`, `IdentitiesOnly=yes`, and its own
`known_hosts` under `~/.local/state/sbx/`, which a rebuild clears because the
new instance has new host keys. Git uses the same options through
`GIT_SSH_COMMAND`.

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
ssh ... 'git init -q -b <branch> projects/<proj>'
git remote add sandbox ai@10.77.0.10:projects/<proj>
git push sandbox <branch>
```

`updateInstead` also works on a repository with no commits yet, so the first
push populates the working tree and no checkout step is needed.

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

`sandbox-vm/sbx`, run from inside a host repo. Written and exercised in the lab
([`01.2_lab_run.md`](01.2_lab_run.md)).

- `sbx in [branch]`: add the remote if missing, create the repo in the VM if
  missing, push the branch. Records the project and its host path in
  `~/.local/state/sbx/projects`, which the rebuild guard reads.
- `sbx out [branch]`: fetch, show the new commits, ask, then fast-forward to
  **the commit that was shown**, not to whatever the sandbox has by then. It
  names other sandbox branches the host does not hold, stops on divergence, and
  updates a branch that is not checked out without checking it out. It does
  **not** push to GitHub: that stays a separate, deliberate `git push`.
- `sbx ssh`, `sbx ip`, `sbx up`, `sbx down`, `sbx test`.

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

`sbx carry-out` and `sbx carry-in` move the files, and `sbx rebuild` calls
both. Carry out happens immediately before the instance is deleted, every time:
the token refreshes itself, so an older copy may be dead. The host copies live
in `~/.local/state/sbx/carry/`, mode 600, and go back in owned by `ai`, mode
600. Tested in the lab with stand-in files.

The path of the credentials file is from memory. Confirm it on the first login
with `ls -la ~/.claude`.

### API keys

`00_start.md` Q7: a `.env` on the host at `~/.local/state/sbx/sbx.env`, mode
600, pushed to `/home/ai/.config/sbx.env` by `sbx carry-in` and exported by the
shell rc. Tested in the lab. Only keys made for the sandbox, each with a spend cap.

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
- `sbx ssh 'ssh-add -l'` reports no agent.
- `sbx ssh 'git -C projects/<proj> push origin'` fails for lack of a remote
  or a credential.
- The Claude login survives a delete and relaunch of the instance.

## Rollback

Remove the `sandbox` remotes (`git remote remove sandbox`), the wrapper,
`~/.ssh/sbx_ed25519*` and `~/.local/state/sbx`.
