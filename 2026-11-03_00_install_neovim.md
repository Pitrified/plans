# Install neovim

- **Goal** - `nvim` on this box, as the test bed for the vim to Neovim migration (`~/dotfiles/plans/02-modernize-vim-setup/`, phase 2 onward).

## Decisions

- apt package `neovim` 0.11.6-1 (Ubuntu 26.04 archive), not the upstream tarball, AppImage or snap:
  0.11 is recent enough for lazy.nvim and the native `vim.lsp.config`/`vim.lsp.enable` API, and it updates with the rest of the system.
- The same apt install goes into `~/bootstrap` in phase 5 of the plan, so every machine gets the same source.
- Installs `/usr/bin/nvim`. No PATH or shell rc changes.
  No config is written: `~/.config/nvim` does not exist yet and arrives later as a dotfiles symlink.

## Steps

Run by the user (sudo-handoff), teed to a log:

    sudo apt-get update 2>&1 | tee ~/handoff-logs/08a-apt-update.log
    sudo apt-get install -y neovim 2>&1 | tee ~/handoff-logs/08b-apt-install-neovim.log

Verify (unprivileged): `nvim --version`.

## Rollback

    sudo apt-get remove --purge neovim neovim-runtime

Nothing under `~/.config`, `~/.local/share` or `~/.local/state` is written by the install itself.

**Superseded 2026-11-03** by `2026-11-03_01_neovim_0_12_tarball.md`: apt 0.11.6 is too old for nvim-treesitter `main`.
