# Unity Editor on the box, headless

## Goal

Unity 6000.4.4f1 with the Android module on the box, run headless (batch mode, under Xvfb when it must render), so the asset loop of unity-setup-project's `plans/03_asset_method` and the project's tests and Android builds run here without a person at a GUI.

## Decisions

- **Installer: the Unity CLI, not the Hub.** Unity's newer `unity` CLI installs editors and modules from a terminal, is documented for headless machines, supports Ubuntu 22.04 and later with glibc 2.34+ (the box has 2.43), and installs per user to `~/.local/bin/unity` with no sudo and no apt repo.
  The Hub (apt repo at `hub.unity3d.com`, needs sudo and an X display even with `--headless`) is the fallback, only if the CLI cannot activate the licence.
  Sources: [Use the Unity CLI](https://docs.unity.com/en-us/unity-cli/use-unity-cli), [Unity CLI reference](https://docs.unity.com/en-us/unity-cli/unity-cli-reference), [Hub on Linux](https://docs.unity.com/en-us/hub/install-hub-linux).
- **Install script read before it runs.** `https://unity.com/install.sh` is downloaded to a scratch file, read, then run with `bash`; never `curl | bash` unread.
- **Editor version: the project's,** `6000.4.4f1` (changeset `360f97ecca93`, from `ProjectSettings/ProjectVersion.txt`), not `lts`, so the editor matches the repo.
- **Modules: Android, with the SDK, NDK and OpenJDK** it needs, so device builds run here too (the user, 2026-11-17). Install location is the CLI's default; the note records it once known.
- **Ubuntu 26.04 is newer than the editor's supported list.** Unity 6 lists Ubuntu 22.04 and 24.04 for the editor ([Unity 6 system requirements](https://docs.unity3d.com/6000.0/Documentation/Manual/system-requirements.html), and a [6.4 release report](https://www.cgchannel.com/?p=174730)). It may run unsupported; step 6 is where that is found out, and a failure there stops the note rather than being worked around.
- **Xvfb from apt** (`xvfb`), for captures that need a display: `-nographics` renders black frames. Sudo, so handed over per the `sudo-handoff` skill.
- **Licence: Unity Personal, activated once on this box.** Personal has no serial, so it cannot be activated by the old `-serial` flag. The CLI has `unity auth login` (described as a browser-based flow) and a `license` command that activates and returns licences; whether either works over SSH with no browser, for Personal, is not documented and is checked in step 5. If not: the Hub once, over `ssh -X`.
  The licence file ties the user's Unity account to a box otherwise kept free of account credentials: the user's call, 2026-11-17. Its path is recorded in step 5. Revoked by returning it (CLI or Hub) or by removing the activation in the Unity account.
- **Nothing touches shell rc or systemd.** `~/.local/bin` is already on PATH. No service, no cron.
- **GPU:** the Quadro RTX 3000 on NVIDIA 595.99; Unity picks Vulkan or OpenGL. Under Xvfb rendering may fall back to software or need `-force-opengl`; that is the spike's question, not this note's.

## Steps

Read-only first, then one state change per call.

1. Check: `ldd --version` (2.43, done), free disk (795 GB, done), `vulkaninfo --summary` if present.
2. `curl -fsSL https://unity.com/install.sh -o <scratch>/unity-install.sh`; read it; then `bash <scratch>/unity-install.sh`. Check `unity --version`.
3. `unity install --help`, then `unity install 6000.4.4f1 -m android` plus the SDK/NDK/OpenJDK module ids if `android` does not bring them as children (the Hub names them `android-sdk-ndk-tools`, `android-open-jdk`). Record the install path and size.
4. HUMAN via sudo-handoff: `sudo apt install xvfb`, plus any shared library step 6 reports missing.
5. Licence: `unity auth login` over SSH and see what it prints; `unity license --help`; activate Personal. Record where the licence file lands. Fallback: the Hub through `ssh -X`, its own sudo hand-off.
6. Smoke, on a scratch clone of unity-setup-project at `main`:
   `<editor> -batchmode -quit -projectPath <clone>/UnitySetupPrpj -logFile -` finishes with no compile errors, and
   `<editor> -batchmode -projectPath <clone>/UnitySetupPrpj -runTests -testPlatform EditMode -testResults <scratch>/editmode.xml` passes.
   The first open builds `Library/` and takes a while; it is one command, not a sweep.
7. Write what was found back into this note: paths, sizes, versions, what the licence step needed.

## What the run found, 2026-11-17

Approved by the user and carried out the same day. Every step passed; the editor runs on Ubuntu 26.04 despite not being on the supported list.

- **CLI**: Unity CLI 1.0.1 in `~/.local/bin/unity`. Install script read first, checksum verified by the script.
  Run with `UNITY_CLI_SKIP_SETUP=1`, because by default it ends with `unity skill install --all`, which installs Unity's agent skills into every AI client found, Claude Code included; that was not in this note.
  `~/.bashrc` and `~/.profile` hash the same before and after: `~/.local/bin` was already persistently on PATH, so the script edited no rc file.
  Usage analytics turned off with `unity analytics opt-out`; the CLI otherwise sends them by default.
- **Editor**: `unity install 6000.4.4f1 --changeset 360f97ecca93 -m android --cm --accept-eula --non-interactive`.
  About 7.3 GB downloaded at about 3 MB/s, one retried download. Installed at `~/Unity/Hub/Editor/6000.4.4f1/`, 18 GB on disk with the modules: Android Build Support, OpenJDK 17.0.9, NDK r27c, CMake 3.22.1, SDK build-tools and platform-tools 36.0.0, platforms 34 to 36, command-line tools 16.0. The download cache was emptied by the install.
- **Xvfb**: `xvfb` 2:21.1.22-1ubuntu1.3, by the user (`~/handoff-logs/14a-apt-xvfb.log`).
- **Licence**: the user ran `unity auth login` and `unity license activate --personal --accept-eula`; `unity license status` shows Unity Personal and Asset Store, assigned. Batch runs log `[Licensing::Module] Error: Access token is unavailable; failed to update` and work regardless.
- **First open** of a scratch clone of unity-setup-project (`91c71db`) in batch mode: about 200 s of import, exit 0.
  The first compile failed inside the Shader Graph package (`error CS0246: 'GUID' could not be found`, two files in `Library/PackageCache/com.unity.shadergraph@ba64c3eae297`); Unity's API updater rewrote 8 files of that package and the next two compiles succeeded. A first-import artefact, absent from every later run.
  The project's own code compiles with one warning, CS4014 at `Assets/Scripts/Core/GameBootstrap.cs:139`, a repo finding.
- **EditMode tests**: `-batchmode -nographics -runTests -testPlatform EditMode`: 114 of 114 passed.
- **PlayMode tests**: under `xvfb-run` with `-force-vulkan`: 3 of 3 passed (boot, menu, game, menu loop; pause and resume; save and continue).
- **Rendering headless**, with a scratch editor script that renders a cube through a camera into a PNG:
  - `-batchmode` with no X display: the editor does not start (`Error opening default X display`, from GTK). Xvfb is needed even for batch mode with rendering.
  - `xvfb-run -a -s "-screen 0 1280x1024x24"` with `-batchmode`: renders, but on Mesa `llvmpipe` through OpenGL Core, which is the CPU.
  - The same with `-force-vulkan`: renders on the Quadro RTX 3000 through Vulkan, NVIDIA driver 595.99.02. **This is the combination to use**: `xvfb-run ... Unity -batchmode -force-vulkan ...`.
- **Android dev build**: `Tools/build-android.sh dev` built `artificial-pi-dev.apk`, 70 MB, `arm64-v8a` only, target SDK 35, in 6 min 25 s with a cold IL2CPP cache. The existing `~/.android/debug.keystore` signed it.
  It needed `UNITY_PATH` set: the script's editor auto-detect never finds anything, a repo bug (it builds NUL-separated paths with `echo -n "$p"$'\0'`, but a bash string cannot hold a NUL, so `read -d ''` gets no delimiter and the loop body never runs).
  The APK still has the Unity template package id, `com.UnityTechnologies.com.unity.template.urpblank`.
- **Not done**: installing the APK on a device (no device attached to the box); `profile` and `release` builds.
- **Scratch left behind**: the clone, logs and APK in the session's scratchpad, which goes with the session.

## Pause

Installs a large tool and a licence tied to an account: approval before step 2.

## Rollback

- Return the licence first (the CLI's `license` return, or the Hub), so the activation is not left counting against the account.
- `unity uninstall 6000.4.4f1` or the CLI's equivalent (from its `--help`), else delete the install path recorded in step 3.
- `unity self-uninstall -y` for the CLI itself; else remove `~/.local/bin/unity`.
- Caches and config: `~/.local/share/unity3d`, `~/.cache/unity3d`, `~/.config/unity3d`, and the CLI's own config directory once known.
- `sudo apt remove xvfb` (and the Hub with its apt source and keyring, if the fallback was used).
- The scratch clone from step 6.
