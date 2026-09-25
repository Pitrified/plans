# Flutter/Android PATH for non-interactive shells

## Goal

Have `flutter` and the Android SDK on the PATH in every shell on this box, including the
non-interactive ones, so agent sessions and scripts do not each re-export it.

## The actual problem

`~/.bashrc` returns at line 8 when the shell is not interactive:

```bash
case $- in
    *i*) ;;
      *) return;;
esac
```

The Flutter and Android exports sit at the *bottom* of the file (added 2026-07-07), so they are
below that return and only ever run for interactive shells. `~/.bash_aliases` is sourced from
`.bashrc` as well, so putting them there would change nothing.

Today's sessions do have flutter on the PATH, because the environment is inherited from the
VS Code remote server, which was itself started from an interactive shell. What breaks is a shell
that has no such parent: `ssh box 'flutter --version'`, a systemd user unit, a cron job.

## Decisions

- **Move the existing exports above the interactivity guard in `~/.bashrc`**, rather than adding a
  second copy elsewhere. Bash sources `.bashrc` for non-interactive shells run by sshd, so this one
  move covers interactive, login (`.profile` sources `.bashrc`) and remote-command shells.
  One definition, in the file that already owns it.
- **Not `~/.profile`**: login shells only, so `ssh box 'cmd'` would still miss it.
- **Not `~/.config/environment.d/`**: it would cover systemd user units, which is a real gap, but
  nothing on this box currently needs flutter from a unit, and it would mean two places defining
  the same PATH. Revisit if a unit ever needs it.
- **Keep the `command -v flutter` fallback in `flutter-setup-project/scripts/check.sh`.** It is
  what makes the repo work on a machine that has not had this edit; the edit is the convenience,
  the fallback is the contract.

## Steps

1. Back up: `cp ~/.bashrc ~/.bashrc.bak-2026-09-24`.
2. Delete the three-line Flutter/Android block from the end of `~/.bashrc`.
3. Re-insert it immediately above the `# If not running interactively` comment, keeping the
   pointer comment to the install note.
4. Verify in a fresh non-interactive shell:
   `env -i HOME=$HOME bash -c 'source ~/.bashrc; which flutter; echo $ANDROID_HOME'`.
5. Verify the interactive path still works: `bash -ic 'which flutter'`.
6. Update the flutter-toolchain memory and the repo instructions, which both state the caveat.

## Rollback

`cp ~/.bashrc.bak-2026-09-24 ~/.bashrc`, or move the block back to the end of the file. No packages,
no system files, nothing outside `$HOME`.

## Result (2026-09-24)

Done as planned, with one addition: the block is now idempotent (`case ":$PATH:"` guard), because
`.bashrc` gets sourced twice in a login + interactive shell and the old block prepended twice.

Verified in four shell flavours, each from an empty environment:

| shell | `command -v flutter` |
| --- | --- |
| non-interactive, `source ~/.bashrc` | `/home/pmn/flutter/bin/flutter` |
| interactive (`bash -ic`) | resolves, and `adb` too |
| login (`bash -lc`, via `.profile`) | resolves, one copy on PATH |
| `.bashrc` sourced twice | one copy on PATH |

`ssh host 'cmd'` could not be tested locally: sshd is inactive on this box and access is over
Tailscale SSH, which spawns a login shell for an interactive session and a non-interactive one for a
remote command. Both branches are covered by the placement above the guard.

Sessions reach this box from Termux over ssh, and this one runs under
`systemd -> zellij -> bash -> claude`, so its environment comes from the shell zellij was started
from. That inheritance is why flutter was already on the PATH before this change and why the gap
only showed in a shell with no such parent.

Downstream edits: `flutter-setup-project/.github/copilot-instructions.md` and the `check.sh` comment
no longer claim the caveat; the `flutter-toolchain-on-box` memory is updated.
