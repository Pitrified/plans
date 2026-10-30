# Install GIMP

- **Goal** - GIMP 3 on this box, to hand-refine cutout masks for the wallpapers in `~/Pictures/sfondi/blackpink`.

## Decisions

- apt package `gimp` 3.2.2-1ubuntu0.26.04.1 (Ubuntu archive), not snap/flatpak:
  the apt build ships `gimp-console-3.x` and Python-Fu via `python3-gi` + `gir1.2-gimp-3.0`, which the batch scripts need;
  a sandboxed snap/flatpak makes headless batch calls and file access under `~/Pictures` more awkward.
- ~37 packages pulled in, ~33MB for gimp itself plus deps (gegl, babl, gimp-data, graphviz, ...). No PATH or shell rc changes.
- Runs on the existing Wayland session (`DISPLAY=:0`, `WAYLAND_DISPLAY=wayland-0`).

## Steps

Run by the user (sudo-handoff), teed to a log:

    sudo apt-get update 2>&1 | tee ~/handoff-logs/01a-apt-update.log
    sudo apt-get install -y gimp 2>&1 | tee ~/handoff-logs/01b-apt-install-gimp.log

Verify (unprivileged): `gimp-console-3.2 --version` (or `ls /usr/bin/gimp*`), and a no-op batch call:
`gimp-console-3.2 -i --batch-interpreter=python-fu-eval -b "print('ok')" -b "Gimp.get_pdb().run_procedure('gimp-quit', [True])"`.

## Rollback

    sudo apt-get remove --purge gimp gimp-data && sudo apt-get autoremove --purge

User config lives in `~/.config/GIMP/3.2`; delete it to remove all traces.
