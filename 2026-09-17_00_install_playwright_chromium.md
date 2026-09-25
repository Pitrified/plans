# Install Playwright and a headless Chromium for driving the klide viewer

## Goal

Put a browser on this box that an agent can drive, so the klide viewer's page can be operated and
screenshotted rather than reasoned about from the outside.

Context: `~/repos/klide/plans/04_klide_app/05_viewer.md`, phase 5. The viewer became a browser page
today and its JavaScript has never run on this host, because there is no browser here. A click that
fails and a click that is correctly ignored currently look identical.

## Decisions

**Playwright's Chromium, not the Firefox already installed.** Playwright drives browser builds it
ships itself; it cannot drive `/usr/bin/firefox`. Driving the system Firefox instead would mean
geckodriver and Selenium, which is a second install and a worse API for reading the console.

**Firefox too, added the same day.** Chromium ran the page correctly on the first try, while the
person reporting the bug is using Firefox, so the interesting browser turned out to be the one not
installed. Playwright's Firefox goes in the same cache directory and needs no elevation either, and
a bug that only one engine has is exactly what a single-engine harness cannot see.

*Rejected: Puppeteer.* It is Node, and there is no node, npm or npx on this box. Installing a Node
toolchain to drive a browser from a Python repo is a larger footprint than the thing it enables.

**No elevation needed, checked rather than assumed.** Headless Chromium wants a specific set of
shared libraries and `playwright install-deps` is the usual way to get them, which needs root. Every
one of them is already present here, checked against `ldconfig -p`: `libnss3`, `libnspr4`,
`libatk-1.0`, `libatk-bridge-2.0`, `libcups`, `libdrm`, `libxkbcommon`, `libatspi`, `libXcomposite`,
`libXdamage`, `libXfixes`, `libXrandr`, `libgbm`, `libpango-1.0`, `libcairo`, `libasound`,
`libexpat`. So the browser unpacks under `~/.cache/ms-playwright` and runs as `pmn`.

If Chromium fails to start anyway, its error names the missing file. That is the point at which a
`sudo apt install` handoff gets written, through the `sudo-handoff` skill, rather than guessed at
now. `sudo -n` fails in this shell, so nothing elevated runs from here in any case.

**The Python package is a dev dependency of the klide repo, not a box-wide install.** `uv add --dev
playwright` puts it in `uv.lock` where every other tool in that repo lives. Only the browser binary
is box-level, which is the part this note covers.

*Rejected: a `browser` dependency group.* It would keep CI from syncing the wheel, and costs a
`--group browser` flag on every invocation forever. The browser itself is not in the lock file
either way, so CI never downloads the expensive part.

**Disk.** Chromium and Firefox together are roughly 800 MB under `~/.cache/ms-playwright`. It is a
cache directory: deleting it costs a re-download and nothing else.

## Steps

Nothing here needs elevation.

```bash
cd ~/repos/klide
uv add --dev playwright
uv run playwright install chromium firefox
uv run python -c "
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b = p.chromium.launch()
    print('chromium', b.version)
    b.close()
"
```

The last command is the check that matters: `import playwright` succeeding proves nothing about
whether a browser will start, which is the same mistake made earlier today with `import tkinter`
against a Tk that could not open a window.

## Rollback

```bash
rm -rf ~/.cache/ms-playwright          # the browser binaries
cd ~/repos/klide && uv remove --dev playwright
```

Nothing is written outside `~/.cache/ms-playwright` and the repo. No system packages, no PATH
change, no shell rc edit, no service, no boot step.
