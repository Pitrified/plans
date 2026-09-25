# Headless Android emulator on this box

## Goal

Run an Android emulator here, with no screen and no root privileges, so `fala` can be exercised end
to end (install, tap, screenshot, read logs) without the Pixel and without a g7 session.

## What was checked first (2026-09-25)

- `/dev/kvm` is `root:kvm 0660` and `pmn` is **not** in the `kvm` group, but an explicit ACL grants
  `user:pmn:rw-`, and opening the device from an unprivileged process succeeds. Hardware acceleration
  is therefore available **without elevated privileges and without a group change**. This is the fact
  the whole plan rests on: without KVM an x86_64 image is too slow to use.
- `~/android-sdk` is user-owned, so `sdkmanager` installs need no elevation.
- Neither `emulator` nor any system image is installed yet.
- Every shared library the emulator needs is already on the box: libpulse, libX11, libxcb, libGL,
  libEGL, libnss3.
- 4 cores, 30 GB RAM (22 available), 150 GB free disk.
- No `DISPLAY`, no Wayland, no Xvfb. Not needed: `-no-window` renders in software.
- The app ships an `x86_64` ABI (phase 12 kept arm64-v8a + x86_64 precisely so emulators work), so
  `app-x86_64-release.apk` installs on an x86_64 AVD.

## Decisions

- **API 36, `default` (AOSP) x86_64 image**, not `google_apis`. The app needs network and nothing
  from Play services, the AOSP image is smaller, and it allows `adb root` with a writable `/system`,
  which keeps the hosts-file route open as a fallback for endpoint mocking.
- **x86_64, not arm64 emulation.** KVM accelerates same-architecture guests only; an arm64 image on
  this x86_64 host would be full emulation.
- **Install with `sdkmanager` into `~/android-sdk`**, matching the existing toolchain
  (`~/repos/plans/2026-07-07-00-install-flutter.md`). Not apt, not a snap: the SDK is user-local and
  `flutter` already looks there.
- **Headless launch wrapped in a script in the repo**, not a shell alias, so the flags are versioned
  with the project that needs them: `-no-window -gpu swiftshader_indirect -no-audio -no-boot-anim`.
- **`-no-snapshot-save` on each boot for now.** A cold boot each time is slower but avoids a stale
  snapshot hiding a first-launch bug, which is exactly what the app's model-download path is. Revisit
  if boot time becomes annoying.
- **One AVD, `fala_api36`.** No device-farm ambitions.

## Steps

```bash
export ANDROID_HOME="$HOME/android-sdk"
SDK="$ANDROID_HOME/cmdline-tools/latest/bin"

# 1. packages (~1.5 GB download, a few GB on disk)
"$SDK/sdkmanager" --install "emulator" "system-images;android-36;default;x86_64" "platforms;android-36"

# 2. the AVD
"$SDK/avdmanager" create avd -n fala_api36 \
  -k "system-images;android-36;default;x86_64" -d pixel_6 --force

# 3. boot it headless
"$ANDROID_HOME/emulator/emulator" -avd fala_api36 \
  -no-window -gpu swiftshader_indirect -no-audio -no-boot-anim -no-snapshot-save &

# 4. wait for it and check
adb wait-for-device
adb shell getprop sys.boot_completed   # 1 when ready
flutter devices                        # should list emulator-5554
```

## Rollback

```bash
"$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager" delete avd -n fala_api36
rm -rf "$ANDROID_HOME/emulator" "$ANDROID_HOME/system-images" ~/.android/avd/fala_api36.avd
```

Nothing outside `$HOME`. No packages from apt, no services, no `/etc` changes, no group membership
changes. Disk is the only cost.

## Risks

- **Boot may fail in ways a headless box hides.** The check is `sys.boot_completed`, not the absence
  of an error message.
- **Software GPU.** Fine for this app (a text UI); would not be fine for judging animation.
- **The KVM ACL is not mine.** If something re-creates `/dev/kvm` without the ACL (a kernel or udev
  change), acceleration silently disappears and the emulator crawls. A symptom to remember rather
  than a thing to pre-empt.

## Result (2026-09-25)

Installed and working, exactly as planned, no elevation needed at any point.

| item | value |
| --- | --- |
| emulator | 37.1.11, `~/android-sdk/emulator`, 821 MB |
| system image | `system-images;android-36;default;x86_64`, 2.0 GB |
| AVD | `fala_api36` (pixel_6 profile), `~/.android/avd` |
| boot | headless cold boot to `sys.boot_completed=1` in about 2 minutes |
| app | debug x86_64 APK (130 MB) installs and draws in 5.3 s |

`flutter devices` lists it as `emulator-5554 - android-x64 - Android 16 (API 36)`.

Two things worth remembering:

- **A cold boot shows an Android "System UI isn't responding" dialog** for a while, on top of the app.
  The app is fine underneath (logcat says `Fully drawn`), but `uiautomator dump` only ever shows the
  topmost window, so it looks like the app failed. Tap "Wait" and carry on.
- **Flutter widgets appear as `content-desc`, not `text`**, in the view tree. Driving the UI means
  reading `content-desc` and tapping the centre of the node's `bounds`.

Used immediately to verify two behaviours that unit tests could not reach, recorded in
`~/repos/flutter-setup-project/plans/17_emulator_e2e/01_feat_emulator_smoke.md`.

The emulator is still running in this session. To stop it: `adb emu kill`.
