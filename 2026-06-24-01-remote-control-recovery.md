# Claude Code Remote Control: recovery + keeping sessions alive

QA dump (2026-06-24). Context: two Remote Control (RC) sessions started on this
box hung half way. This box is a disposable sandbox reached over SSH + Tailscale.

## Key facts

- An RC session is a normal local `claude` process. The conversation history is
  written to disk continuously (`~/.claude/projects/<project-hash>/*.jsonl`), so
  a hang does not lose the transcript.
- RC needs Claude Code v2.1.51+ (`claude --version`).
- `--resume` / `/resume` is **local-only** by design - it cannot be driven from
  phone/web, which is exactly why it is the recovery tool.

## What "hung" likely means

Two distinct causes, different fixes:

- **Process wedged** (stuck mid-tool, frozen UI). Transcript intact up to last step.
- **RC connection timed out** but process maybe alive. RC drops the *remote link*
  if the box can't reach the network for ~10 min; the local process may keep
  running or may have exited.

First, SSH in and check:

    ps aux | grep -i '[c]laude'      # are the processes still alive?
    tmux ls 2>/dev/null              # were they started under tmux?
    claude --version                 # RC needs v2.1.51+

## 1. Pick them up cleanly

Resume the conversation locally, then re-enable RC:

    cd /path/to/the/project          # same dir you started in
    claude --resume                  # picker; RC sessions appear by title

Then inside the session:

    /remote-control                  # or /rc - re-registers for phone/web

If the old process is still alive and wedged, kill it first so it isn't holding
the RC registration (else you get "environment already has an active session -
continue or start new?"):

    ps aux | grep -i '[c]laude'      # find PIDs
    kill <pid>                       # SIGTERM first; kill -9 only if it won't die

Then `claude --resume` -> `/remote-control`. Repeat once per hung session.

Known rough edge: RC session resume is undiscoverable in the CLI
(issues #56294, #55406). If a session is missing from `--resume`, look in
`~/.claude/projects/<project-hash>/` for the most recent `*.jsonl`, then resume
from the matching project directory.

## 2. Keeping sessions alive

Two independent failure modes; only one is in our control.

**Terminal/SSH disconnect kills the process.** RC is just a local process - if
you close the terminal, drop SSH, or quit VS Code, the `claude` process (and the
session) ends. On an SSH box this is the most likely cause of the hangs. Fix:
run RC inside **tmux** so it survives SSH ending:

    tmux new -s rc1
    cd /path/to/project
    claude remote-control            # server mode (multi-session), or:
    # claude --remote-control "My Project"   # single interactive session
    # detach: Ctrl-b then d - process keeps running

Reattach with `tmux attach -t rc1`. Now closing the terminal / dropping SSH /
closing the laptop leaves the process running and phone/web stays connected.
This is the single most important change.

To auto-enable RC for every session: `/config` -> **Enable Remote Control for
all sessions** = true.

**Network outage > ~10 min is a hard timeout.** If the box is awake but can't
reach the network for >~10 min, the session times out and the process exits.
tmux does **not** save you - the process itself exits. After such an outage,
start fresh: `claude --resume` -> `/remote-control`. With Tailscale, watch for a
flapping link; that explains repeated mid-task deaths better than anything else.

**Gotcha:** starting an ultraplan session disconnects an active RC session (both
occupy the claude.ai/code interface). Don't kick off ultraplan on a session
you're remote-controlling.

## 3. Zellij as a modern alternative to tmux

Zellij (Rust-based multiplexer) does the same job as tmux for RC - keep the
`claude` process alive across SSH/terminal disconnects - and is generally nicer
for phone use. It auto-detaches on a dropped connection and persists the session,
so a flaky link leaves the session resumable rather than killed.

Basic flow on the box (mirrors the tmux flow above):

    zellij -s rc1                    # create/attach named session "rc1"
    cd /path/to/project
    claude remote-control            # or: claude --remote-control "My Project"
    # detach: Ctrl-o then d

    zellij ls                        # list sessions (running + exited)
    zellij attach rc1                # reattach (alias: zellij a rc1)
    zellij kill-session rc1          # remove a dead/stale session

Why it's better than tmux on a phone:

- A keybinding hint bar sits at the bottom of the screen and updates per mode
  (Ctrl-p pane mode, Ctrl-t tab mode, etc.), so you don't have to remember
  bindings on a small screen with no muscle memory.
- Mouse/touch support is on by default - tap to switch panes/tabs, drag to
  resize. Useful with a touchscreen.
- Session resurrection: an exited session can often be reattached with its layout
  intact, which pairs well with a flaky mobile link.

### Meshing with Termux from a phone

The pattern from an Android phone is: Termux -> `ssh` into this box -> run
`zellij` there. Zellij runs on the box, not in Termux, so it's the box's process
that persists; Termux is just the viewport. (Zellij is also packaged for Termux
itself via `pkg install zellij` if you ever want a local multiplexer, but for RC
you want it on the box.)

Gotchas specific to Termux:

- **Modifier keys.** Zellij leans on Ctrl and Alt. Termux's soft keyboard has no
  physical Ctrl/Alt, so enable the **extra-keys** row (CTRL, ALT, ESC, arrows,
  TAB) in `~/.termux/termux.properties`. They act as sticky modifiers: tap CTRL,
  then `o`, to send Ctrl-o. Without this row, zellij is close to unusable on a
  phone.
- **Alt collisions.** Some of zellij's default Alt-based shortcuts (Alt-n, Alt
  +arrows) can clash with how Termux/the soft keyboard emits Alt. If they misfire,
  switch zellij to the **"unlock-first" / non-colliding keybinding preset**
  (selectable on first run or via `keybinds` in `~/.config/zellij/config.kdl` on
  the box) - it routes everything through an explicit unlock key (Ctrl-g) and
  avoids the bare-Alt bindings.
- **Use a real ssh keepalive** so the phone's link drop is detected cleanly:
  set `ServerAliveInterval 30` in `~/.ssh/config` (or Termux's). Combined with
  zellij's auto-detach, a dropped mobile connection then leaves a clean,
  reattachable session instead of a half-dead pane.

Caveat unchanged from tmux: zellij keeps the process alive across *disconnects*,
but it cannot beat the RC **~10 min network-outage timeout** - if the box itself
is offline that long, the RC session still exits and you restart with
`claude --resume` -> `/remote-control`.

## Short version

- Recover: SSH in -> kill any wedged `claude` -> `claude --resume` in the project
  dir -> `/remote-control`. Transcripts are safe on disk.
- Stay alive: run RC **inside tmux** so SSH/terminal close doesn't kill it. tmux
  fixes disconnects but NOT the ~10 min network-outage timeout - watch Tailscale
  link stability for that.

## Sources

- https://code.claude.com/docs/en/remote-control
- https://github.com/anthropics/claude-code/issues/56294  (resume undiscoverable in CLI)
- https://github.com/anthropics/claude-code/issues/55406  (cannot resume after /remote-control)
- https://github.com/anthropics/claude-code/issues/28402  (RC session not in list, cannot reconnect)
- https://zellij.dev/faq/  (zellij; non-colliding "unlock-first" keybinding preset)
- https://zellijcheatsheet.dev/  (zellij command/keybinding reference)
