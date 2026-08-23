# Enable linger so remote-control sessions survive logout

## Status

**Applied 2026-08-23 03:03.** `Linger=yes`, `/var/lib/systemd/linger/pmn` exists,
`user@1000.service` active.

## Goal

Stop `claude` remote-control sessions on this box from being killed when the last login session
closes. One command: `loginctl enable-linger pmn`.

## Context

Symptom: a remote-control session (`gene-g4`) went offline and vanished from the peer list. A
replacement (`gene-g4-2`) did the same after ten minutes. Suspected the IPv4/CGNAT outage, or that
remote control uses a separate network channel.

Neither. The sessions were killed locally by systemd.

```
02:07:05  systemd-logind: New session '22' of user 'pmn' with class 'manager'
02:17:37  systemd-logind: Removed session 22.
02:17:37  systemd[13768]: Stopped snap.zellij.zellij-49b4d5aa-....scope
02:17:37  systemd[13768]:   Consumed 45.287s CPU over 10min 29.073s wall clock, 456.3M peak
02:17:37  systemd[13768]: Removed slice app.slice - User Application Slice
02:17:37  systemd[1]: Stopped user@1000.service - User Manager for UID 1000.
02:17:37  systemd[1]: Removed slice user-1000.slice
```

`gene-g4-2` (transcript `~/.claude/projects/-home-pmn-repos-genealogy-gramps-fn/1d3756ae-*.jsonl`)
started 02:07:26 and last wrote at 02:17. The zellij scope holding it ran 10min29s across the same
window. When the last login session went away, systemd stopped `user@1000.service` and tore down
`user-1000.slice`.

Ruled out, with evidence:

- **Not the network.** Remote control bridges to `claude.ai`, which has AAAA records and is
  reachable over IPv6 from here. Not a separate channel, does not need IPv4.
- **Not the DNS workaround reverting.** `ipv6.dns` still on the profile, `resolvectl` still shows
  the Cloudflare servers. See `2026-08-23_00_ipv4_outage_ipv6_dns_workaround.md`.
- **Not OOM.** No kill messages; 2.6 GiB used of 30 GiB.
- **Not a crash.** The 01:34 reboot was a clean `systemd-reboot.service`. It explains the three
  sessions that died at 01:34, not the 02:17 one.

## Why it is the snap specifically

`KillUserProcesses` is unset, so the compiled default `no` applies. Under that default a plain
multiplexer started from a shell lands in `session-cNN.scope`, is *abandoned* at logout, and keeps
running - the classic "tmux survives logout" behaviour.

Zellij here is a snap (`/snap/bin/zellij`, rev 65, classic). snapd does not leave snap apps in the
session scope: it starts them as a transient scope under the **user manager's** `app.slice`. The
journal above shows the kill coming from `systemd[13768]`, the user manager, not from PID 1 and not
from a session scope. That re-parents zellij's lifetime from "the session" to
"`user@1000.service`" - which is exactly what stops on last logout without linger.

So the snap packaging quietly converts zellij from logout-surviving to logout-dying. A non-snap
build would land in the session scope and behave the classic way. (Inference from the journal, not
a controlled test, but the scope name and the killing PID are both direct evidence.)

## Why it worked for two weeks anyway

It is worth being clear that this is a *new* fragility, not a standing one. In the previous boot
(2026-08-05 to 2026-08-23, 18 days):

```
snap.zellij.zellij-bb5341d2-....scope:  2w 16h 23min wall clock, 1.7G peak
snap.zellij.zellij-7a471799-....scope:  1w  6d  3h 22min wall clock, 15.5G peak
snap.zellij.zellij-3bd9bea1-....scope:  1w  4d 10h 37min wall clock, 4.6G peak

user@1000.service: Deactivated successfully.   Aug 05 20:15
user@1000.service: Deactivated successfully.   Aug 07 23:55
user@1000.service: Deactivated successfully.   Aug 23 01:34   <- the reboot
```

The user manager stopped three times in eighteen days. After Aug 8 it ran continuously for fifteen
days, so `Linger=no` never mattered: at least one pmn session was open the whole time, and days-long
remote-control sessions worked with nothing consciously kept connected.

The likely holder is the VS Code remote server, not an SSH client. It keeps running long after the
client disconnects, and while it runs its session stays open. Right now `session-c23.scope` contains
a full `~/.vscode-server` tree doing exactly that. Not provable for August after the fact, but it
fits: nothing had to be deliberately held open.

The 01:34 reboot cleared that accidental keeper. Nothing long-lived holds a session now, so the user
manager starts and stops with each short connection - and `gene-g4-2` was caught in one teardown.

**Linger does not add a capability that was missing. It makes a property that held by accident hold
deterministically.**

Also worth noting from those numbers: 15.5G, 4.6G and 1.7G memory peaks. Two-week sessions on a 30G
box are not free.

## Decisions

- **`loginctl enable-linger pmn`**, not a systemd user service per session. Linger is the mechanism
  built for this: keep `user@1000.service` running independently of login sessions. Persistent
  (a file under `/var/lib/systemd/linger/`), survives reboots.
- **Not `nohup`, `setsid` or `systemd-run --scope`.** Those detach from the session but stay in the
  user slice, so `user@1000.service` stopping still kills them.
- **Keep the zellij snap for now.** Linger fixes it and covers everything else in the user slice
  too. Replacing the snap with the upstream binary would make zellij's persistence independent of a
  systemd setting, but it only helps zellij. Optional cleanup, not done.
- Fits the always-on intent in `linux-box-cloudflare/docs/always-on-server.md`, which covers the lid
  and power side but says nothing about user processes surviving logout. This is the missing half.

## Steps

Run in the user's own terminal, per the sudo-handoff convention:

```bash
mkdir -p ~/handoff-logs
sudo loginctl enable-linger pmn 2>&1 | tee ~/handoff-logs/21a-enable-linger.log
```

Verify (no privileges needed):

```bash
loginctl show-user pmn -p Linger     # Linger=yes
ls -l /var/lib/systemd/linger/       # a file named pmn
```

Real test: start a session in zellij, detach, close the terminal entirely, wait, and check the
`claude` process is still alive and the peer shows online rather than offline. Not yet done.

## Rollback

```bash
sudo loginctl disable-linger pmn
```

Removes `/var/lib/systemd/linger/pmn`. Nothing else touched; behaviour returns to "user processes
die when the last session closes" immediately.

## Risk

Low, and the trade is deliberate: forgotten sessions now keep running and consuming CPU and memory
after logout. That is the point on an always-on box, but a runaway session no longer cleans itself
up at logout. Check `pgrep -af claude` and `systemctl --user status` when the box feels busy - see
the multi-gigabyte peaks above.
