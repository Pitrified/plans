# Remote Control blocked by GitHub repo access check

Diagnosed 2026-07-17. Companion to `2026-06-24-01-remote-control-recovery.md`,
which covers hangs/disconnects and does **not** cover this cause.

## Goal

Restore Remote Control (RC) on this box.
RC connects but never creates a session in any repo with a GitHub remote.

## Symptom

RC prints an error and no session appears on phone/web. From the bridge debug log:

    [bridge] Session creation failed with status 400:
    GitHub repository access check failed - re-authorize GitHub in settings

Reproduced identically in `repomgr` and `linux-box-cloudflare`, so it is
**account-level, not repo-specific**.

## Root cause

The server gates RC *session creation* on the Claude GitHub App having access to
the repo the CLI reports as `git_repo_url`. That grant is currently failing.

The bridge itself is healthy; only session creation fails:

    POST /v1/environments/bridge -> 200   environment_id=env_...   # registers fine
    [bridge] Session creation failed with status 400: ...          # then dies here
    [bridge:work] Starting poll loop ...                           # polls with nothing to show

That last line is why it looks alive but useless: the bridge keeps polling
after session creation already failed.

## What was ruled out

All healthy, none of these are the cause:

- version 2.1.211/2.1.212 (floor is v2.1.51)
- auth: access token valid, refresh token good to 2026-07-24
- network: api.anthropic.com + claude.ai reachable, Tailscale up
- `remoteControlAtStartup: true` already set in `settings.local.json`
- session runs under zellij, so SSH drops do not kill it
- daemon being down is a **red herring**: `idle 5s with no clients - exiting`
  is designed behavior and unrelated to the RC bridge

## Mechanism (proven by probe)

The check is triggered purely by the CLI volunteering the local `origin` URL.
No GitHub remote means no check.

| cwd | `gitRepoUrl` reported | result |
|---|---|---|
| `repos/repomgr` (GitHub remote) | `https://github.com/Pitrified/repomgr.git` | 400, no session |
| `repos/linux-box-cloudflare` (GitHub remote) | `https://github.com/Pitrified/linux-box-cloudflare.git` | 400, no session |
| `repos/va` (not a git repo) | `null` | **Connected, session created** |

Inference, not confirmed: RC likely shares the environment/session API with
cloud sessions, where the server genuinely must clone from GitHub. For a local
bridge session the code is already on disk and git runs locally, so the check
looks redundant here. Worth an upstream report.

## Fix

Must happen in a browser. This box has no browser logins and holds no GitHub
credentials, so this is the user's to do, from phone or laptop:

1. claude.ai -> Settings -> GitHub connection -> re-authorize.
2. Ensure the grant covers `Pitrified/repomgr` and `Pitrified/linux-box-cloudflare`
   (relevant if scoped to selected repos rather than all).
3. Re-test from a repo with a GitHub remote:

       cd ~/repos/repomgr
       claude remote-control --debug-file /tmp/rc.log -v
       grep -iE "Session creation|Created initial session" /tmp/rc.log

   Success looks like `Created initial session session_...`.

Unknown: *why* the grant lapsed (expired / revoked / App installation removed).
If re-authorizing bounces, that is the next thread to pull.

## Workaround (deliberately not applied)

Removing the `origin` remote makes `git_repo_url` null and RC works.
Do **not** do this to a real repo just to get RC back; it breaks fetch/push for
a cosmetic gate. Recorded only as evidence of the mechanism.

## Rollback

Nothing to roll back. No config was changed and no system state was modified.
Probe sessions self-deregistered on exit (`DELETE /v1/environments/bridge`).
