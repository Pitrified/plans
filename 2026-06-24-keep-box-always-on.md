# Keep linux box always-on with lid closed

## Goal

Laptop (Ubuntu 26.04, GNOME, reached over SSH/Tailscale) stays running 24/7 with the
lid shut **while on AC**: physical screen off, system on, SSH up. On battery, treat it as a
regular laptop - no explicit "AC failing" check, just the stock battery behavior (idle
suspend, default low/critical-battery handling). Off-AC handling is whatever the OS defaults
already do.

## Findings (verified on box, 2026-06-24)

- Chassis laptop, AC + BAT0 (100%, Full). 8G swap (`/swap.img`) -> hibernate/hybrid-sleep works.
- GNOME (gnome-settings-daemon) DOES expose lid keys and handles the lid itself, overriding
  logind while its session is active:
  - `lid-close-ac-action = 'suspend'`      <- the gap to fix (want 'nothing')
  - `lid-close-battery-action = 'suspend'` <- correct, leave as is
- Idle handling already correct:
  - `sleep-inactive-ac-type = 'nothing'` (set by bootstrap/setup_gnome.sh)
  - `sleep-inactive-battery-type = 'suspend'`, timeout 900s
- AC-fail / drain protection already correct: UPower `CriticalPowerAction=HybridSleep`
  (`AllowRiskyCriticalPowerAction=false`). At critical battery it hybrid-sleeps -> state on
  disk, resumes later. No change needed.
- Thermal: `thermald` installed, enabled, running (Intel proactive throttling). Kernel has
  hard critical trips. `lm-sensors` NOT installed. Idle pkg temp ~42C.
- `/etc/systemd/logind.conf`: all defaults (`HandleLidSwitch=suspend` active).

## Remote access (why always-on-AC matters)

- Reached via **Tailscale SSH**, started with `sudo tailscale up --ssh`. No openssh-server;
  nothing listens on :22. Access = tailscaled's built-in SSH server.
- tailscaled is a system service (`WantedBy=multi-user.target`), independent of the GNOME
  session; prefs persist (`RunSSH: true`, `WantRunning: true`) so it auto-starts on boot.
- Therefore whenever the box is AWAKE it is reachable (login screen, crashed session,
  headless). The only unreachable state is suspend (CPU halted, tailscaled stops, no WoL
  over Wi-Fi). => keep AC = stay awake; do not let it sleep on AC.

## Decisions

- Masking sleep/suspend targets is REJECTED: would break wanted battery suspend + critical
  hybrid-sleep. Do not mask.
- Critical-battery action: leave default (HybridSleep). Satisfies "quit rather than drain".
- Lid fix is GNOME-side (the real handler) with a logind drop-in as backstop for non-GNOME
  states (login screen, session crash):
  - GNOME: `lid-close-ac-action 'nothing'`; battery action unchanged.
  - logind drop-in: `HandleLidSwitchExternalPower=ignore`, `HandleLidSwitchDocked=ignore`;
    leave `HandleLidSwitch` (battery) at default suspend; do NOT set `IdleAction`.
- Reproducibility (bootstrap): user chose NOT to edit bootstrap yet. When done, add the
  `lid-close-ac-action 'nothing'` line to `setup_gnome.sh` next to the existing power line,
  and optionally a `setup_power.sh` that writes the logind drop-in.

### User choices (2026-06-24)

- Lid fix: SHOW COMMANDS ONLY for now. Do not apply live, do not edit bootstrap yet.
- Thermal: install `lm-sensors` only. Timer + Telegram alerts and soft auto-shutdown are
  deferred options (kept below), not being done now.

## Steps to apply later (lid fix)

    # GNOME (live)
    gsettings set org.gnome.settings-daemon.plugins.power lid-close-ac-action 'nothing'

    # logind backstop
    sudo install -d /etc/systemd/logind.conf.d
    sudo tee /etc/systemd/logind.conf.d/keep-awake.conf <<'EOF'
    [Login]
    HandleLidSwitchExternalPower=ignore
    HandleLidSwitchDocked=ignore
    EOF
    sudo systemctl restart systemd-logind   # or reboot to avoid disturbing tty2 GNOME session

## Thermal monitoring - now

    sudo apt update && sudo apt install -y lm-sensors
    sudo sensors-detect --auto    # probe and write /etc/modules-load.d
    sensors                       # read temps

## Thermal monitoring - deferred options (not doing now)

- systemd timer + script polling `x86_pkg_temp`, warning above a threshold (~85C).
- Route that warning to `tg-central-hub-bot` (Telegram) so a closed-lid box can't cook silently.
- Soft auto-shutdown safety net at a high threshold (~92C), above thermald.

## Rollback (lid fix, once applied)

    gsettings reset org.gnome.settings-daemon.plugins.power lid-close-ac-action
    sudo rm /etc/systemd/logind.conf.d/keep-awake.conf
    sudo systemctl restart systemd-logind

## Notes

- Closed-lid 24/7 reduces airflow -> heat. Keep ventilated / on a stand.
