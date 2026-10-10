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
[`01.1_host_facts.md`](01.1_host_facts.md), dry run in
[`01.2_lab_run.md`](01.2_lab_run.md).

This is system-level work on g7: installs, a new group membership, firewall
rules. Pause for approval before running it.

## Goals

1. Incus installed, `pmn` able to use it without sudo.
2. A storage pool that supports snapshots (`00_start.md` Q3).
3. A dedicated bridge with NAT to the internet.
4. Rules that drop traffic from that bridge to the LAN, the tailnet and the host.
5. A repeatable test that proves 4.

## Plan

Steps 2 to 4 are scripted and were run in the lab against Incus 6.0.0. Step 1
has not been run on a machine with systemd.

```bash
# 1. install (24.04+; older hosts use the Zabbly repo)
sudo apt install incus qemu-system
sudo adduser pmn incus-admin        # then log out and in
incus admin init                    # btrfs loop pool, no clustering, no remote access

# 2-3. bridge, ACL, host guard
sandbox-vm/host/network.sh

# 4. prove it, from a throwaway VM
incus launch images:ubuntu/24.04/cloud sbxtest --vm --network sbxbr0
sandbox-vm/host/isolation_test.sh sbxtest \
  10.77.0.1:22 <host LAN address>:22 <host tailnet address>:22 \
  <a LAN device>:<open port> <a tailnet device>:<open port>
incus delete -f sbxtest
```

What `network.sh` creates:

```bash
incus network create sbxbr0 ipv4.address=10.77.0.1/24 ipv4.nat=true ipv6.address=none
incus network acl create sbx-internet-only
incus network acl rule add sbx-internet-only egress action=drop \
  destination=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,100.64.0.0/10,169.254.0.0/16
incus network acl rule add sbx-internet-only egress action=allow
incus network acl rule add sbx-internet-only ingress action=allow source=10.77.0.1/32
incus network set sbxbr0 security.acls=sbx-internet-only
nft -f sandbox-vm/host/host_guard.nft
```

Two layers, and both are needed:

- **The ACL** keeps the sandbox off the private ranges. Incus ACL rules are not
  ordered; a `drop` wins over an `allow`, which is what makes "drop the private
  ranges, allow the rest" work. DHCP and DNS to the bridge's own dnsmasq keep
  working, because Incus accepts them ahead of the ACL. Both confirmed in the lab.
- **The host guard** keeps the sandbox off the host itself. The ACL only blocks
  the host through addresses that fall inside the dropped ranges; an address
  outside them (a public IPv4 on the host, for one) stayed reachable in the
  lab. The guard is a small nftables table dropping anything new that arrives
  from `sbxbr0` for the host, except DHCP and DNS.

The ACL applies to the bridge as a whole, so anything attached to `sbxbr0` is
internet-only, whether or not Incus created it.

IPv6 is off on the bridge so there is a single address family to reason about.

### Making the host guard permanent

`network.sh` loads it once; it is gone after a reboot. On g7 it has to be loaded
at boot, before the sandbox can start (`00_start.md` Q10). The isolation test
catches a missing guard only if a host address outside the private ranges is
among its targets, so on g7 the test also checks `nft list table inet
sbx_host_guard` directly.

### Choosing the test targets

The test is only as good as its targets. Each "must be blocked" target has to
be something that **would answer** if the rules were absent: an address with a
port that is really open. Run the test once with `network.sh --no-acl` to see
every target reported reachable, then apply the rules. A target that is
"blocked" in the control run proves nothing.

## Pitfalls

- **Docker on the same host.** Docker sets the forward chain's default policy
  to drop, which cuts an Incus bridge off from the internet. If Docker is on g7,
  expect to add an explicit forward rule for `sbxbr0`. Not tested in the lab.
- **Tailscale's own rules.** The lab stand-in had a tailnet address range, not
  Tailscale's routing and firewall marks. Traffic from the VM to
  `100.64.0.0/10` is what the ACL drops, so it should not matter, but the
  tailnet target in the test is the one to watch on g7.
- **A test that cannot fail.** The script stops if it cannot exec in the guest,
  because a stopped instance otherwise reports everything as blocked.

## Out of scope

- The real guest, its disk and its provisioning: phase 2.
- GPU: phase 4.

## Done when

- `incus list` works as `pmn` without sudo.
- The control run reports every blocked target as reachable.
- With the rules applied, `isolation_test.sh` exits 0.
- The host guard is loaded after a reboot with no manual step.

## Rollback

```bash
incus delete -f sbxtest
incus network delete sbxbr0
incus network acl delete sbx-internet-only
sudo nft delete table inet sbx_host_guard
sudo apt purge incus && sudo rm -rf /var/lib/incus
```
