# IPv4 outage: IPv6 DNS workaround on the wired link

## Goal

Restore Claude API access on the box while the ISP's IPv4 path is down, by pointing the wired connection's resolver at Cloudflare's IPv6 DNS instead of the router.

## Context

Symptoms on 2026-08-23 around 01:30 CEST: Tailscale SSH from `g7` worked, `apt update` failed,
GitHub was unreachable, the Cloudflare tunnel was down, Claude was unreachable.

Diagnosis, run from a `g7` session over Tailscale SSH:

| Check | Result |
| --- | --- |
| `ping 192.168.0.1` (LAN gateway) | works, 1.4 ms |
| `ping 1.1.1.1` / `ping 8.8.8.8` | 100% loss |
| `ping6 2606:4700:4700::1111` | works, 50 ms |
| `dig @192.168.0.1 github.com` | empty answer |
| `dig @2606:4700:4700::1111 github.com` | works |
| `tailscale netcheck` | `IPv4: (no addr found)`, `IPv6: yes` |
| router UPnP `GetStatusInfo` | `Connected`, `ERROR_NONE`, external IP `10.13.235.255` |

The `10.x` external address is the ISP's CGNAT. Native IPv6 is up, the carrier's IPv4 path is dead.
Nothing on the box was misconfigured, and the 01:34 reboot neither caused nor fixed it.

Everything failed at a single point: `/etc/resolv.conf` points at the `systemd-resolved` stub,
whose only link resolver was `192.168.0.1`, and the router cannot resolve without IPv4 upstream.
`cloudflared` said so directly in its journal:

```
ERR edge discovery: error looking up Cloudflare edge IPs: the DNS query failed
    error="lookup _v2-origintunneld._tcp.argotunnel.com on 127.0.0.53:53: no such host"
```

Reusable triage sequence for this failure mode:

```bash
ping -c2 192.168.0.1                            # LAN: box vs network
ping -c2 1.1.1.1                                # IPv4 WAN: routing vs DNS
ping6 -c2 2606:4700:4700::1111                  # IPv6 WAN
dig +short github.com @192.168.0.1
dig +short github.com @2606:4700:4700::1111     # only this works -> resolver problem
tailscale netcheck                              # v4/v6 verdict in one line
```

## Decisions

- **Scope cut to Claude only.** The tunnel and GitHub were explicitly not needed. `cloudflared` was left alone
  and keeps failing its start timeout in the journal; that is expected, not a new fault.
- **GitHub cannot be fixed from here.** `github.com` is IPv4-only (`20.26.156.215`, no AAAA).
  No DNS change helps until the ISP restores IPv4.
- **NetworkManager, not `/etc/systemd/resolved.conf`.** The link is managed by NM
  (connection `Wired connection 1`, device `enx8a735c0a7a48`, a USB ethernet dongle).
  A global `DNS=` in `resolved.conf` would have been ignored: `systemd-resolved` prefers per-link
  servers, and the link had `192.168.0.1` from DHCP. The fix has to replace the link's list.
- **`nmcli device reapply`, not `nmcli con up`.** The Tailscale SSH session rides that interface,
  so deactivating the connection risks locking us out. `reapply` applies the change in place.
- **`ipv4.ignore-auto-dns yes` as well.** The router's IPv4 resolver is not merely useless right now,
  it makes queries time out. Dropping it is what makes resolution fast rather than slow-then-fallback.
- **Stored in the connection profile, deliberately not permanent.** It survives reboots, which is the point
  (the box must come back unattended), and also why the rollback below matters once IPv4 returns.

## Steps

Run in the user's own terminal, per the handoff convention (elevated, tee'd to logs):

```bash
mkdir -p ~/handoff-logs
nmcli con mod "Wired connection 1" ipv6.dns "2606:4700:4700::1111,2606:4700:4700::1001" ipv6.ignore-auto-dns yes ipv4.ignore-auto-dns yes 2>&1 | tee ~/handoff-logs/20a-nmcli-mod-dns.log
nmcli device reapply enx8a735c0a7a48 2>&1 | tee ~/handoff-logs/20b-nmcli-reapply.log
resolvectl status enx8a735c0a7a48 2>&1 | tee ~/handoff-logs/20c-resolvectl-status.log
```

Both `nmcli` lines need elevation. `20a` logs empty on success; `nmcli con mod` prints nothing.

Verification (no privileges needed):

```bash
resolvectl status enx8a735c0a7a48       # DNS Servers: 2606:4700:4700::1111 2606:4700:4700::1001
resolvectl query api.anthropic.com
curl -sS -o /dev/null -w '%{http_code} via %{remote_ip}\n' https://api.anthropic.com/
```

Result on the day: resolution in 1.2 ms, HTTP 404 from the API root via `2607:6bc0::10`,
and `POST /v1/messages` returning 401, which proves the request reached Anthropic and was processed.
Claude Code `2.1.240` at `~/.local/bin/claude` (login shell only, not on the non-interactive PATH).

## Rollback

Once the ISP restores IPv4, put the router's DHCP-supplied resolver back.
Both `nmcli` lines need elevation:

```bash
nmcli con mod "Wired connection 1" ipv6.dns "" ipv6.ignore-auto-dns no ipv4.ignore-auto-dns no
nmcli device reapply enx8a735c0a7a48
resolvectl status enx8a735c0a7a48   # expect: DNS Servers: 192.168.0.1
```

Confirm IPv4 is genuinely back first, otherwise this re-breaks name resolution:

```bash
ping -c2 1.1.1.1
```

Only the NM connection profile was touched. No `/etc` file was added, no service was changed,
so this is a complete undo.

## Risk

Low. One connection property, reverted by one command. The lockout risk was real
(the SSH path rides the interface being reconfigured) and was handled by using `reapply`
and keeping a second session open; the session did not drop.

The standing cost of leaving it in place after IPv4 returns: DNS keeps going to Cloudflare
rather than the router, so any LAN-local hostnames the router serves would stop resolving.
Nothing on this box currently depends on those.

## Note on this repo's naming

`README.md` documents hyphens (`<YYYY-MM-DD>-<NN>-<slug>.md`) while
`~/.claude/rules/local-box.md` documents underscores (`<YYYY-MM-DD>_<NN>_<slug>.md`).
This file follows the rules file and the most recent note (`2026-08-11_00_install_calibre_ebook_convert.md`).
Worth reconciling the two.
