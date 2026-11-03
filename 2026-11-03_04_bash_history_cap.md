# Bash history cap in ~/.bashrc

- **Goal** - stop `~/.bashrc` from truncating `~/.bash_history` to 2000 lines at every shell start, and set the real cap to 10000 in the dotfiles.

## Decisions

- Assigning `HISTFILESIZE` truncates the file at once, so the stock `HISTFILESIZE=2000` in `~/.bashrc` runs before the dotfiles override is sourced.
  Reproduced on bash 5.3.9 with a 5000-line scratch file.
- Remove `HISTSIZE=1000` and `HISTFILESIZE=2000` from `~/.bashrc`; the dotfiles stay the only place that sets them.
- `HISTSIZE` and `HISTFILESIZE` both 10000 in `dotfiles/bash/bash_aliases.bash`: a list larger than the file has no use.
- `HISTCONTROL=ignoreboth:erasedups` in the same file; it overrides the `ignoreboth` set earlier in `~/.bashrc`.
  Tested: it dedupes the in-memory list only, the file still gets duplicates because `history -a` appends.
- Notes go in the README of the dotfiles and bootstrap repos; no automation added to the install scripts.
- No PATH change. Nothing committed.

## Steps

    cp ~/.bashrc ~/.bashrc.bak-before-histcap
    sed -i '/^HISTSIZE=1000$/d;/^HISTFILESIZE=2000$/d' ~/.bashrc

Then edit `~/dotfiles/bash/bash_aliases.bash`, `~/dotfiles/README.md` and `~/bootstrap/README.md`.

## Rollback

    cp ~/.bashrc.bak-before-histcap ~/.bashrc

Revert the uncommitted edits in the two repos with `git restore`.
