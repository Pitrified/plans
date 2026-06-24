# plans

Box-level planning scratch for system-level (non-repo) work on this host.

Git-tracked for history and peace of mind, but **local-only**: do not push.
Each note covers Goal / Decisions / Steps / Rollback.

See `~/.claude/rules/local-box.md` for when a note is required.

## Naming

```
<YYYY-MM-DD>-<NN>-<slug>.md
```

- `<YYYY-MM-DD>` - the date the note is created.
- `<NN>` - a zero-padded two-digit sequence within that day: `00` for the first note of the
  day, `01` for the next, and so on. The date alone cannot order same-day notes; this does.
  To pick it, take `max + 1` of the existing `NN` for that date, or `00` if none yet.
- `<slug>` - short kebab-case topic, e.g. `keep-box-always-on`.

Date then `NN` then slug means a plain alphabetical sort is also chronological order.
Example: `2026-06-24-00-keep-box-always-on.md`.
