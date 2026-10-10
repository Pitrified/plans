---
status: draft
---

# Phase 1 - Host: Incus and the internet-only network

## Overview

Install Incus on g7 and build the one thing the whole design rests on: a bridge
the VM can use to reach the internet and nothing else. It comes first because it
is cheap, it needs no guest decisions, and the isolation test at the end is
worth having before anything valuable goes into a VM.
Context: [`00_start.md`](00_start.md), host capture in
[`01.1_host_facts.md`](01.1_host_facts.md).

This is system-level work on g7: installs, a new group membership, firewall
rules. Pause for approval before running it.

## Goals

1. Incus installed, `pmn` able to use it without sudo.
2. A storage pool that supports snapshots (`00_start.md` Q3).
3. A dedicated bridge with NAT to the internet.
4. Rules that drop traffic from that bridge to the LAN, the tailnet and the host.
5. A repeatable test that proves 4.

## Plan

Commands are the intended shape and have not been run. Check each against the
installed Incus version before running it.

```bash
# 1. install (24.04+; older hosts use the Zabbly repo)
sudo apt install incus qemu-system
sudo adduser pmn incus-admin        # then log out and in
incus admin init                    # btrfs loop pool, no clustering, no remote access

# 2. dedicated bridge, IPv4 only
incus network create sbxbr0 \
  ipv4.address=10.77.0.1/24 ipv4.nat=true ipv6.address=none

# 3. ACL: internet only
incus network acl create sbx-internet-only
incus network acl rule add sbx-internet-only egress action=drop \
  destination=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,100.64.0.0/10,169.254.0.0/16
incus network acl rule add sbx-internet-only egress action=allow
incus network acl rule add sbx-internet-only ingress action=allow source=10.77.0.1/32
incus network set sbxbr0 security.acls=sbx-internet-only
```

Notes on the rules:

- Incus ACL rules are not ordered; a `drop` wins over an `allow`. That is what
  makes "drop the private ranges, allow the rest" work.
- The bridge address is inside `10.0.0.0/8`, so the drop also covers the host's
  own address on the bridge, which is the intent. DHCP and DNS from the bridge's
  own dnsmasq are expected to keep working through Incus's baseline rules. If
  the guest gets no address or no DNS, this is the first place to look.
- IPv6 is off on the bridge so there is a single address family to reason about.
- The ingress rule is what lets the host (and nothing else) open connections
  into the VM.

A throwaway VM for the test:

```bash
incus launch images:ubuntu/24.04/cloud sbxtest --vm --network sbxbr0
incus exec sbxtest -- bash
```

Inside it:

```bash
curl -sI https://example.com | head -1          # must answer
curl -m 5 http://10.77.0.1:22                   # host on the bridge: must time out
curl -m 5 http://<a LAN device>                 # must time out
curl -m 5 http://<a tailnet device, 100.x.y.z>  # must time out
ping -c1 -W2 <the host's LAN address>           # must fail
```

Then `incus delete -f sbxtest`.

## Pitfalls

- **Docker on the same host.** Docker sets the forward chain's default policy
  to drop, which cuts an Incus bridge off from the internet. If Docker is on g7,
  expect to add an explicit forward rule for `sbxbr0`.
- **The ACL may not cover traffic addressed to the host itself** on every
  firewall backend. The tests above are the truth, not the rule list. If the
  host is reachable, add a host-side nftables rule dropping new connections
  from `sbxbr0` to the host other than DHCP and DNS.
- **Tailscale routes.** Traffic from the VM to `100.64.0.0/10` would be
  masqueraded and leave through `tailscale0` as the host. The tailnet test is
  the one that matters most.

## Out of scope

- The real guest, its disk and its provisioning: phase 2.
- GPU: phase 4.

## Done when

- `incus list` works as `pmn` without sudo.
- All five checks in the test block give the stated result.
- The test is saved as a script so it can be re-run after any network change.

## Rollback

```bash
incus delete -f sbxtest
incus network delete sbxbr0
incus network acl delete sbx-internet-only
sudo apt purge incus && sudo rm -rf /var/lib/incus
```
