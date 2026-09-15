# Waiting on a background job without writing a watcher that never exits

## Goal

Keep the rule for polling a long-running background job somewhere box-wide, so it survives the
project it was learned in and can be lifted into a general skill later.

Not a system change. It is here because the lesson is not about any one repo: it has now been paid
for in three of them.

## The rule

**A watcher must not be able to match itself.** `pgrep -f` and `pkill -f` read the whole command
line of every process, including the command line of the shell running the watcher.

1. **Bracket the first character of the pattern**: `pgrep -f "[m]y_job"`, never `pgrep -f my_job`.
   Bracketed, the regex matches the literal `my_job` in the target and not the `[m]y_job` the
   watcher's own command line carries.
2. **Bracket, or remove, every other mention of the job's name on that same line.** This is the one
   that is easy to miss, and is what went wrong on 2026-09-15: the loop was correct and the report
   chained after it was not.

   ```sh
   # never exits: the `ls` at the end is an unbracketed match on the watcher itself
   until ! pgrep -f "[m]y_job"; do sleep 20; done; ls out/my_job.png
   ```

   Either bracket every occurrence, or let the loop be the only thing on the line that names the
   job and report from a separate call.
3. **Watch the process, not a happy-path string.** `until ! pgrep -f "[m]y_job"` ends when the job
   ends, whatever happened to it. A watcher armed on the word a successful run prints polls straight
   through a crash. If the condition has to be a grep, it covers the failures too.
4. **Give a kill its own call.** Never chain work after `pkill`: if the pattern is self-matching, the
   kill takes the shell with it and everything after it silently never runs.
5. **Stop the watcher in the same breath as the job it was watching.**
6. **A process sweep is not proof.** `ps` does not reliably see harness-managed background shells.
   Track background work by its task id.

## Why it keeps happening

The failure is invisible. A stuck watcher is a `sleep` loop: it costs nothing, prints nothing and
blocks nothing, so the only symptom is that it is still there. Three sightings so far:

- the snap-fit project, where watchers armed on a happy-path string polled for nearly three hours
  after the jobs they were watching had been killed;
- the same project, where a self-matching `pkill` killed its own shell mid-command and the edits
  chained after it never ran;
- `~/repos/house-renderer`, 2026-09-15, two watchers on a pair of Cycles renders. The renders
  finished and were used; the watchers polled on until the user asked whether anything was still
  running. Pattern correctly bracketed, job name repeated unbracketed later on the line.

## If this becomes a skill

What it would have to carry, beyond the six rules:

- the three worked failures above, because the rule reads as pedantry without them;
- a sentence on why an interval is chosen by what is being waited for rather than by habit, and why
  polling something the harness already notifies about is waste;
- the note that this is per-host shell behaviour, not project-specific, which is the argument for a
  skill rather than a `CLAUDE.md` line in each repo.

Where the same rule is already written down, and should be kept in step:
`~/.claude/projects/-home-pmn-repos-house-renderer/memory/long-running-background-jobs.md`, and
`~/repos/house-renderer/docs/building_assets.md` under "Running it unattended".

## Rollback

Delete the file. Nothing reads it.
