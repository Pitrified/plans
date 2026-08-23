# Install calibre for `ebook-convert` (EPUB -> AZW3)

## Goal

Get `ebook-convert` on the box so `epub-fixer` can emit an AZW3 of the areia footnote epub for sideloading to Kindle.

## Context

The artifact that already exists is `books/areia/renderings/footnotes/dist/Capitães da Areia - footnotes.epub`, 433 KB, with 6,430 EPUB3 popup-footnote glosses. Nothing about the epub needs calibre; this is purely a format conversion for sideloading.

Stated up front because it bears on whether this is worth 122 packages: **Send-to-Kindle takes the EPUB directly and converts it to KFX, which has the best popup-footnote support of any Kindle format.** AZW3 is KF8, and its footnote-popup behaviour is weaker than KFX's. So this install buys a sideload path, not better popups, and the user chose it knowing that.

## Decisions

- **apt, not the official installer script.** `calibre` 9.2.1+ds is in the Ubuntu 26.04 archive. The upstream route is `curl https://download.calibre-ebook.com/linux-installer.sh | sudo sh`, which self-updates, installs to `/opt/calibre`, and is not tracked by any package manager. On a box whose whole convention is that `/etc` and system state are reproducible, an untracked self-updating install in `/opt` is the wrong trade for a newer version nobody needs.
- **`--no-install-recommends`.** 171 packages with recommends, **122** without. The difference is largely GUI and font extras; `ebook-convert` is a CLI and this box is headless and reached over SSH. Qt6 still comes in as a hard dependency of `calibre-bin` and is not avoidable through apt.
- **Not attempting to avoid Qt.** There is no `calibre-cli` package. The Python `ebooklib`/`kindlegen` alternatives either cannot write AZW3 or are discontinued binaries Amazon no longer distributes.
- **Scope is one command.** No `/etc` changes, no service, no PATH edit - apt puts `ebook-convert` in `/usr/bin`.

## Steps

Run in the user's own terminal, per the sudo-handoff convention:

```bash
mkdir -p ~/handoff-logs
sudo apt-get install -y --no-install-recommends calibre 2>&1 | tee ~/handoff-logs/00a-install-calibre.log
```

Then verify (no privileges needed, I can run this):

```bash
ebook-convert --version
```

## Rollback

```bash
sudo apt-get purge -y calibre calibre-bin 2>&1 | tee ~/handoff-logs/00b-purge-calibre.log
sudo apt-get autoremove -y 2>&1 | tee -a ~/handoff-logs/00b-purge-calibre.log
```

`autoremove` is what actually reclaims the 122 packages; purging calibre alone leaves the Qt stack behind. Nothing outside the package manager is touched, so this is a complete undo.

## Risk

Low and reversible. The install is large but archive-tracked, touches no config this repo or any other deploys, and `autoremove` reverses it. The realistic downside is disk use on a box that also holds a 19 GB uv cache.
