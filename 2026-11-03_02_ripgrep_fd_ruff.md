# ripgrep, fd-find and ruff for the Neovim config

- **Goal** - the tools the phase 3 plugins call on this box: ripgrep (fzf-lua's live grep), fd-find (fzf-lua's file search) and ruff (conform's Python formatter, later phase 4's Python server); plan `~/dotfiles/plans/02-modernize-vim-setup/03_migrate_plugins.md`, step 1.

## Decisions

- ripgrep and fd-find from apt: Ubuntu 26.04 has ripgrep 15.1.0 and fd-find 10.3.0, recent enough, and both get security updates from apt.
  Phase 5 adds the same packages to the `~/bootstrap` repo for the other machines.
- No `fd` symlink: Ubuntu installs the binary as `fdfind`, and fzf-lua looks for `fdfind` after `fd`.
- ruff with `uv tool install ruff` (the user's choice, decision 22): user-owned, binary in `~/.local/bin`, already on PATH. No sudo.
- No shell rc or PATH change.

## Steps

User (sudo-handoff):

    sudo apt-get install -y ripgrep fd-find 2>&1 | tee ~/handoff-logs/10a-apt-ripgrep-fd.log

Claude, unprivileged:

1. `uv tool install ruff`.
2. Verify: `rg --version`, `fdfind --version`, `ruff --version`, each resolving to the expected path (`/usr/bin` for the first two, `~/.local/bin` for ruff).

## Rollback

    sudo apt-get remove --purge -y ripgrep fd-find
    uv tool uninstall ruff
