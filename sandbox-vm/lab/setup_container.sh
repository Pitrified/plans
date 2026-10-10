#!/usr/bin/env bash
# Lab only: the container stand-in for the sandbox VM, for hosts with no KVM.
# Same bridge, ACL, profile shape, volumes and wrapper as the real thing.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
STATE=${SBX_STATE:-$HOME/.local/state/sbx}
mkdir -p "$STATE" ~/.ssh; chmod 700 "$STATE"
[ -f ~/.ssh/sbx_ed25519 ] || ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/sbx_ed25519
for v in sbx-projects sbx-caches; do
  incus storage volume show default "$v" >/dev/null 2>&1 || incus storage volume create default "$v"
done
if ! incus profile show sbx >/dev/null 2>&1; then
  incus profile create sbx
  incus profile device add sbx root disk pool=default path=/
  incus profile device add sbx eth0 nic network=sbxbr0 ipv4.address=10.77.0.10
  incus profile device add sbx projects disk pool=default source=sbx-projects path=/home/ai/projects
  incus profile device add sbx caches   disk pool=default source=sbx-caches   path=/home/ai/.cache
fi
cat > "$STATE/config" <<C
SBX_VM=0
SBX_IMAGE=sbx-base
SBX_CLOUD_INIT=$HERE/cloud-init.container.yaml
SBX_FLAVOUR=base
SBX_TEST_TARGETS="10.77.0.1:8022 192.0.2.2:8022 192.168.50.1:8022 192.168.50.2:8000 100.64.0.1:8022 100.64.0.2:8000"
export SBX_INTERNET_URL=http://archive.ubuntu.com/ubuntu/dists/noble/Release SBX_DNS_NAME=archive.ubuntu.com
C
