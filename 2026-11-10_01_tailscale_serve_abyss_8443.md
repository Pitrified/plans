# tailscale serve for abyss on 8443, beside lang-tutor on 443

## Goal

Serve abyss on the tailnet again as `https://g7.tail5dff8b.ts.net:8443/`, proxied to `127.0.0.1:8001`, without touching the existing `443 -> 127.0.0.1:8000` mapping that lang-tutor now answers.

## Decisions

- Follows `2026-10-23_00_tailscale_serve_abyss.md`, which mapped 443 to 8000 for abyss.
  Since 2026-11-08 lang-tutor's uvicorn listens on 8000, so 443 serves lang-tutor; that mapping stays as it is.
- abyss moves to 8001 (its `DEFAULT_PORT` in the repo), nothing listened there at writing.
- 8443 for HTTPS: a separate port rather than a path under 443, because the abyss pages use absolute paths (`/vendor/`, `/splats/`, `/models/`) that a path prefix would break.
  8443 is also one of the ports Funnel would accept, should it ever be needed; it is not used here.
- Tailnet only, `--bg` so it persists across restarts, same as the 443 entry.
  The proxy answers 502 while `make serve` is not running.
- Run as root by the user, as before (operator is unset).
- Lockout risk is nil: a new serve entry does not touch ssh or the tailnet connection itself.

## Steps

1. `sudo tailscale serve --bg --https=8443 http://127.0.0.1:8001`, teed to `~/handoff-logs/13a-tailscale-serve-8443.log` (script `2026-11-10_01_tailscale_serve_abyss_8443.sh`).
2. `make serve` in `~/repos/abyss`, on 8001.
3. Check: `tailscale serve status` lists both entries; `curl -sI https://g7.tail5dff8b.ts.net:8443/phone_web/` returns 200; `https://g7.tail5dff8b.ts.net/` still serves lang-tutor.

## Rollback

- `sudo tailscale serve --https=8443 off` removes only this entry.
- Stop `make serve`.
