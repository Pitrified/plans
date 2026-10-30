# Install shellcheck

- **Goal** - `shellcheck` on this box, to lint the `spin_worktree` template in the dotfiles worktree skill (`~/dotfiles/plans/07-feat-worktree-skill.md`) and the repo copies of it.

## Decisions

- apt package `shellcheck` 0.11.0-2 (Ubuntu archive), not snap or a static binary from GitHub:
  it is in the archive, updates with the rest of the system, and has no runtime dependencies to speak of.
- Installs `/usr/bin/shellcheck`. No PATH or shell rc changes.

## Steps

Run by the user (sudo-handoff), teed to a log:

    sudo apt-get update 2>&1 | tee ~/handoff-logs/07a-apt-update.log
    sudo apt-get install -y shellcheck 2>&1 | tee ~/handoff-logs/07b-apt-install-shellcheck.log

Verify (unprivileged): `shellcheck --version`.

## Rollback

    sudo apt-get remove --purge shellcheck

No user config is written.
