#!/usr/bin/env bash
# Provision the sandbox. Run as the sandbox user (ai), with passwordless sudo.
# Idempotent: safe to run again on a live sandbox.
#
# This file is the reviewed list of what the sandbox contains. The assistant
# installs what it needs while working, and appends here what is worth keeping.
#
#   SBX_FLAVOUR=full   everything (default)
#   SBX_FLAVOUR=base   the base section only
#
# Tested: base. NOT yet run anywhere: python, claude, flutter, android,
# blender, nvidia. Treat those sections as a first draft.
set -euo pipefail
FLAVOUR=${SBX_FLAVOUR:-full}
log() { printf '\n== %s\n' "$*"; }
apt_install() { sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q "$@" >/dev/null; }

base() {
  log base packages
  sudo apt-get update -q >/dev/null
  apt_install git curl ca-certificates tmux ripgrep build-essential unzip xz-utils

  log git identity
  git config --global user.name  "${SBX_GIT_NAME:-sandbox assistant}"
  git config --global user.email "${SBX_GIT_EMAIL:-sandbox@localhost}"
  git config --global init.defaultBranch main
  # Lets the host push into a checked-out branch; the working tree follows,
  # and the push is refused if that tree has uncommitted changes.
  git config --global receive.denyCurrentBranch updateInstead

  log cache locations
  # ~/.cache is its own volume and survives a rebuild. Point the big
  # downloaders at it.
  mkdir -p "$HOME/.cache" "$HOME/projects"
  cat > "$HOME/.sbx_env" <<'E'
export UV_CACHE_DIR="$HOME/.cache/uv"
export GRADLE_USER_HOME="$HOME/.cache/gradle"
export PUB_CACHE="$HOME/.cache/pub"
export ANDROID_HOME="$HOME/.cache/android-sdk"
export PATH="$HOME/.local/bin:$HOME/.cache/flutter/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
[ -f "$HOME/.config/sbx.env" ] && set -a && . "$HOME/.config/sbx.env" && set +a
E
  grep -qxF '. "$HOME/.sbx_env"' "$HOME/.bashrc" 2>/dev/null || echo '. "$HOME/.sbx_env"' >> "$HOME/.bashrc"
}

python() {
  log uv
  command -v uv >/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh
}

claude() {
  log claude code
  command -v claude >/dev/null || curl -fsSL https://claude.ai/install.sh | bash
}

dotfiles() {
  # The dotfiles repo arrives through `sbx in`, like any project.
  if [ -f "$HOME/projects/dotfiles/install/install.py" ]; then
    log dotfiles
    (cd "$HOME/projects/dotfiles/install" && uv run install.py)
  else
    log "dotfiles: not in ~/projects yet, skipped"
  fi
}

flutter() {
  log flutter
  apt_install clang cmake ninja-build pkg-config libgtk-3-dev openjdk-17-jdk-headless
  [ -d "$HOME/.cache/flutter" ] ||
    git clone -q --depth 1 -b stable https://github.com/flutter/flutter.git "$HOME/.cache/flutter"
}

android() {
  log android sdk and emulator
  . "$HOME/.sbx_env"
  if [ ! -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
    echo "install the command line tools into $ANDROID_HOME/cmdline-tools/latest first" >&2
    return 0
  fi
  yes | sdkmanager --licenses >/dev/null
  sdkmanager --install "platform-tools" "emulator" "platforms;android-36" \
    "system-images;android-36;default;x86_64"
  [ -e /dev/kvm ] || echo "warning: no /dev/kvm in the guest, the emulator will crawl" >&2
}

blender() {
  log blender
  sudo snap install blender --classic
}

nvidia() {
  log nvidia driver
  # Harmless with no card attached: the driver loads and finds nothing.
  apt_install ubuntu-drivers-common
  sudo ubuntu-drivers install || true
}

base
if [ "$FLAVOUR" = full ]; then
  python; claude; dotfiles; flutter; android; blender; nvidia
fi
log "done"
