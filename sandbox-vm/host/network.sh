#!/usr/bin/env bash
# Create the sandbox bridge and its internet-only ACL. Idempotent.
set -euo pipefail
BR=${SBX_BRIDGE:-sbxbr0}
GW=${SBX_GW:-10.77.0.1}
ACL=${SBX_ACL:-sbx-internet-only}
BLOCKED=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,100.64.0.0/10,169.254.0.0/16

incus network show "$BR" >/dev/null 2>&1 ||
  incus network create "$BR" ipv4.address="$GW/24" ipv4.nat=true ipv6.address=none

if ! incus network acl show "$ACL" >/dev/null 2>&1; then
  incus network acl create "$ACL"
  incus network acl rule add "$ACL" egress action=drop destination="$BLOCKED"
  incus network acl rule add "$ACL" egress action=allow
  incus network acl rule add "$ACL" ingress action=allow source="$GW/32"
fi
if [ "${1:-}" != "--no-acl" ]; then
  incus network set "$BR" security.acls="$ACL"
  # Not persistent: this table is gone after a reboot until it is loaded
  # again. See the plan for how it is made permanent on the host.
  $(command -v sudo || true) nft -f "$(dirname "$(readlink -f "$0")")/host_guard.nft"
fi
incus network show "$BR"
