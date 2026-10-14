# plans

Box-level planning notes for system-level (non-repo) work on the box and the machines around it.

Tracked on GitHub and **public**.
Never write secrets or secret-adjacent details here: no tokens, passwords, private IPs, network names, or IDs that are not already public elsewhere.

See `~/.claude/rules/local-box.md` for when a note is required.

## Single notes

One file per change, covering Goal / Decisions / Steps / Rollback.

```
<YYYY-MM-DD>_<NN>_<slug>.md
```

- `<YYYY-MM-DD>` - the date the note is created.
- `<NN>` - a zero-padded two-digit sequence within that day: `00` for the first note of the day, `01` for the next, and so on.
  The date alone cannot order same-day notes; this does.
  To pick it, take `max + 1` of the existing `NN` for that date (notes and folders together), or `00` if none yet.
- `<slug>` - short snake_case topic, e.g. `install_restic`.

Date then `NN` then slug means a plain alphabetical sort is also chronological order.
Example: `2026-08-25_00_install_restic.md`.

Notes before 2026-08 use dashes (`2026-06-24-00-keep-box-always-on.md`); they are kept as they are.

## Multi-phase efforts

Work that spans several phases or sessions gets a folder with the same naming, following the `tracked-development` skill:
`00_start.md` (idea, analysis, decisions, open questions), `tracking.md` (phases table and log), and one `NN_<name>.md` per phase.
Example: `2026-10-14_00_g4_to_g7_box_swap/`.
