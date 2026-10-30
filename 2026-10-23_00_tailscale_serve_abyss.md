# tailscale serve for the abyss phone page on g7

## Goal

Expose `make serve` (abyss, `127.0.0.1:8000`) on the tailnet over HTTPS as `https://g7.tail5dff8b.ts.net/`, for g4 and the Pixel.

## Decisions

- `tailscale serve`, not `funnel`: tailnet only, nothing public.
  Not the Cloudflare tunnel either; it is not needed for tailnet devices.
- HTTPS on 443 is required: the camera API only exists in a secure context.
- The abyss server keeps binding loopback; tailscale proxies to it. No abyss code change.
- `--bg` makes the serve config persist across tailscaled restarts and reboots.
  That is acceptable since it proxies to a port that is dead unless `make serve` runs; it answers 502 then.
- `make serve` runs unprivileged, started by hand or from a Claude session, not as a service.
  A systemd user unit is deferred until it is needed.
- Read-only state at writing: `tailscale serve status` says "No serve config";
  `CertDomains` is empty in `tailscale status --json`, so HTTPS certificates may not be enabled for the tailnet yet;
  this user is not shown as tailscale operator, so `tailscale serve` may need root.

## Steps

1. If HTTPS certificates are off: enable MagicDNS and HTTPS Certificates in the Tailscale admin console (DNS page). Tailnet-wide; the user does it.
2. If `tailscale serve` refuses without root: `sudo tailscale set --operator=pmn` (sudo-handoff), once.
3. `tailscale serve --bg --https=443 http://127.0.0.1:8000`
4. `make serve` in `~/repos/abyss`, left running.
5. Check: `tailscale serve status`; `curl -sI https://g7.tail5dff8b.ts.net/phone_web/` from g7; then the page from g4.

## Outcome so far

- Ports checked first: nothing listened on 8000 or 443; the Cloudflare tunnel (deployed config identical to the repo's) uses 8090-8092, outbound only.
- `make serve` started on 127.0.0.1:8000, answering 200.
- `tailscale serve --bg ...` waited on "Serve is not enabled on your tailnet" with an admin link (`https://login.tailscale.com/f/serve?node=...`); no root prompt, so the operator step was not needed to get that far. No serve config was written.

## Done

- Serve enabled for the tailnet by the user, then the serve command run as root by the user (log `~/handoff-logs/06a-tailscale-serve.log`). Operator left unset, so unattended sessions cannot run `tailscale down`.
- Verified: `tailscale serve status` shows the proxy, tailnet only; GET over HTTPS returns 200; headless Chromium runs the page and the probe through the URL.

## Rollback

- `tailscale serve --https=443 off` (or `tailscale serve reset` to clear every serve entry).
- Stop `make serve`.
- Operator, if set: `sudo tailscale set --operator=`.
- HTTPS certificates in the admin console can stay on; they issue nothing until something serves.
