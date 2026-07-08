# Install Flutter + Android toolchain

**Outcome (2026-07-07):** done. Flutter 3.44.5 stable at `~/flutter`, Android SDK 36 at `~/android-sdk`,
JDK 17 + ninja via apt. `flutter doctor` green (no devices - emulator deferred), repo tests pass (141/141).
Deviation from the guide: `commandlinetools-linux-latest.zip` URL is dead; used `commandlinetools-linux-14742923_latest.zip`.

## Goal

Set up Flutter (Android target only) on this box so `flutter doctor` passes,
following `~/repos/flutter-setup-project/docs/getting-started.md`.

## Current state

- Nothing installed: no flutter, dart, java, adb, sdkmanager, ninja.
- git, curl, unzip present. /dev/kvm exists (emulator viable). 189G free, 30G RAM.
- No PATH management found in ~/.bashrc; will append exports there.

## Decisions

- Flutter SDK: git clone of stable channel to `~/flutter` (the guide's method; also Flutter's official Linux install path). No snap.
- Android SDK: Option B from the guide - command-line tools only to `~/android-sdk`. No Android Studio (headless box, SSH access).
- JDK: `openjdk-17-jdk-headless` via apt. The guide omits Java but sdkmanager and gradle require JDK 17+; 17 is the safe floor for AGP.
- ninja-build via apt (guide prerequisite for Android builds).
- API level: guide targets API 36 (Android 16); install `platforms;android-36`, `build-tools;36.0.0`, plus platform-tools.
- Emulator: defer. The AVD system image is ~1.5 GB and the box is headless; create it later only if needed (guide has the commands).
- PATH/env: append to `~/.bashrc`:
  - `export PATH="$HOME/flutter/bin:$PATH"`
  - `export ANDROID_HOME="$HOME/android-sdk"`
  - `export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"`
- Disable non-Android targets: `flutter config --no-enable-ios --no-enable-web --no-enable-linux-desktop`.

## Steps

1. User runs (sudo required): `sudo apt install ninja-build openjdk-17-jdk-headless`
2. `git clone https://github.com/flutter/flutter.git -b stable ~/flutter`
3. Download cmdline tools zip to `~/android-sdk/cmdline-tools`, unzip, `mv cmdline-tools latest`
4. Append PATH exports to `~/.bashrc`
5. `sdkmanager "platform-tools" "build-tools;36.0.0" "platforms;android-36"`
6. `yes | flutter doctor --android-licenses`
7. `flutter config --no-enable-ios --no-enable-web --no-enable-linux-desktop`
8. `flutter doctor -v` - expect green for Flutter + Android toolchain; no devices is expected (no emulator yet)
9. In the repo: `flutter pub get && dart run build_runner build --delete-conflicting-outputs`

## Rollback

- `rm -rf ~/flutter ~/android-sdk ~/.config/flutter ~/.dart-tool ~/.pub-cache ~/.gradle`
- Remove the three export lines from `~/.bashrc`
- `sudo apt remove ninja-build openjdk-17-jdk-headless`
