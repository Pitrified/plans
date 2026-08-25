# Install restic for the Gramps Web offsite backup

## Goal

Put `restic` on the box so the Gramps Web backup can push an encrypted copy to Cloudflare R2.

Context: `~/repos/genealogy-gramps-fn/plans/04_backup_and_restore/`, phase 2.

## Decisions

**`restic` from the Ubuntu archive.** Candidate on this box is `0.18.1-3ubuntu1+esm1`.

An earlier reading of `apt-cache policy` suggested restic was only available through Ubuntu Pro's
ESM apps pocket. That was wrong: it is in `resolute/main` at priority 500, and ESM supplies a
patched build at 510 which wins. Ubuntu Pro is attached on this box with `esm-apps` enabled, so
either way `apt install restic` works, and the ESM build is the one that gets security updates.

*Rejected: the upstream binary from GitHub releases.* It is newer, and it means carrying a binary
nobody updates. The version gap does not matter for what this does, and apt-managed is the whole
shape of this box.

**Nothing is installed for alerting.** Hosted `ntfy.sh` is an HTTP POST with `curl`, which is
already here. The Gramps project plan originally listed `ntfy` as a package to install, from back
when self-hosting was still on the table; it was not chosen, and this note supersedes that line.

*Rejected: self-hosted ntfy.* It would put the alerting on the machine being alerted about, which
is the one arrangement guaranteed to be silent in the case that matters most.

**No new user, no new service account.** restic runs as `pmn` from a user systemd timer. Linger is
already enabled on this box (see `2026-08-23_01_enable_linger_for_remote_sessions.md`), so the
timer fires without a login session.

**Credentials do not live in this note.** They are in `.restic.env` inside the project repo,
gitignored, mode 600. The R2 token is an account-owned API token scoped to a single bucket.

## Steps

Only the install needs elevation. Everything after it runs as `pmn`.

```bash
mkdir -p ~/handoff-logs

sudo apt install -y restic 2>&1 | tee ~/handoff-logs/04a-apt-install-restic.log

restic version 2>&1 | tee ~/handoff-logs/04b-restic-version.log
```

## Verification

From the logs:

- `restic version` reports 0.18.x and the platform
- `which restic` is `/usr/bin/restic`, not a hand-placed binary

The R2 side is verified separately, in the project repo's phase 2: `init`, `backup`, `check`,
`restore`, then a second `backup`, which is what proves the whole path rather than the
credentials alone.

## Rollback

```bash
sudo apt purge -y restic
sudo apt autoremove -y
```

Nothing else on the box uses restic. The R2 bucket and its contents are untouched by this and are
removed from the Cloudflare dashboard if that is ever wanted.

## Notes on ntfy

No install. The box sends alerts with:

```bash
curl -H "Title: gramps backup" -d "backup failed" ntfy.sh/<topic>
```

The topic for this project is `gramps-fn-pliANAoBSJDJRCbiYtSIGOa6`. It is long and random because
**the topic name is the only access control**: anyone who knows it can read the notifications and,
more to the point, send them. A spoofed "backup succeeded" is worse than a leaked "backup failed".

To receive them on a phone: install the **ntfy** app (Play Store, App Store, or F-Droid), tap to
subscribe to a topic, and enter that topic name. No account, no login. Notifications arrive from
then on, including ones sent before subscribing only if they are still within the server's
retention window, which is short.

Worth doing once by hand before relying on it:

```bash
curl -H "Title: test" -d "hello from the box" ntfy.sh/gramps-fn-pliANAoBSJDJRCbiYtSIGOa6
```

If the phone does not buzz, the alerting does not work, and finding that out now is the point.
