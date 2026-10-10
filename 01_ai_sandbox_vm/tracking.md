# implementation tracking

A KVM virtual machine on g7 where an AI assistant runs as root with permissions
skipped, reachable only from the host and able to reach only the internet.
Analysis and decisions in [`00_start.md`](00_start.md); host capture in
[`01.1_host_facts.md`](01.1_host_facts.md); dry run of phases 1, 2, 3 and 5 on
another machine in [`01.2_lab_run.md`](01.2_lab_run.md).

## Key decisions

- VM, not container; Incus on KVM, libvirt as the fallback if the GPU fights.
- Ubuntu guest, rebuilt from a base image by a reviewed provisioning script.
- The host reaches in, the VM never reaches the host: no agent forwarding, no
  GitHub credential in the VM, no Tailscale in the VM.
- Internet only: the LAN, the tailnet and the host are blocked from the bridge,
  by an Incus ACL plus a host-side nftables guard. The ACL alone does not keep
  the sandbox off the host (lab finding).
- Persistent disks are labelled by serial and mounted by label, never by
  position.
- Work goes in by `git push sandbox` and comes out by fetch, review,
  `merge --ff-only`, then a push to GitHub from the host.
- Projects and caches survive a rebuild; the home directory and `~/.claude` do
  not. Claude config comes from the dotfiles repo; the login file is carried
  out and in by the host.
- GPU off by default; GPU mode is a headless boot of the host plus an extra
  Incus profile on the same VM.
- Threat model is mistakes, not attackers.

## Phases

| #  | Phase                                  | Plan                                                                   | Status |
| -- | -------------------------------------- | ---------------------------------------------------------------------- | ------ |
| 1  | Host: Incus and internet-only network  | [`01_host_incus_and_network.md`](01_host_incus_and_network.md)         | draft  |
| 2  | Guest: base VM and provisioning        | [`02_guest_base_and_provisioning.md`](02_guest_base_and_provisioning.md) | draft  |
| 3  | Git flow, credentials, `sbx` wrapper   | [`03_git_flow_and_credentials.md`](03_git_flow_and_credentials.md)     | draft  |
| 4  | GPU passthrough                        | [`04_gpu_passthrough.md`](04_gpu_passthrough.md)                       | draft  |
| 5  | Rebuild, snapshots, maintenance        | [`05_rebuild_and_maintenance.md`](05_rebuild_and_maintenance.md)       | draft  |

Status values: draft / planned / in progress / done / superseded / discarded.

Phase 4 depends only on phase 2 and holds the one real unknown, so a short
spike on it right after phase 2 is cheaper than finding out last.

## Log

Append-only. Newest at the bottom. One bullet point per meaningful step,
can be longer than a one-liner if relevant information is needed.

- 2026-10-10 : bootstrapped the folder from the design conversation of
  2026-10-09/10. Wrote `00_start.md` with the settled decisions and Q1-Q9, the
  host capture, and draft sub-plans for phases 1-5. Nothing has been run on g7:
  every command block is unverified. No review pass yet.
- 2026-10-10 : lab run on a cloud container with no KVM, g7 untouched. Incus
  6.0.0 against a system container for the network, profile, volumes, wrapper
  and rebuild; QEMU software emulation for a real VM booting the real
  cloud-init file. Wrote `sandbox-vm/` (wrapper, network script, host guard,
  isolation test, cloud-init, provisioning script, lab stand-ins). Details in
  `01.2_lab_run.md`.
- 2026-10-10 : lab findings folded into the plans. (1) The ACL as planned left
  the host reachable on an address outside the private ranges; added
  `host_guard.nft`, and Q10 for loading it at boot. (2) The isolation test
  passed falsely against a stopped instance; it now refuses to run. (3)
  `fs_setup` replaced by a label-by-serial script; a first version labelled
  disks by position and was rewritten before it ran. (4) `updateInstead` works on
  an empty repo, so the first-time flow lost a step. (5) Volume restore needs
  the instance stopped. Confirmed as planned: drop beats allow, DHCP and DNS
  survive the drop, volumes and login survive a rebuild, the git round trip and
  its three refusals.
- 2026-10-10 : review of phases 1, 2, 3 and 5 after the lab run. Claims checked
  by running them are listed above; corrections made in the sub-plans. Still
  unverified and marked so in place: an Incus `--vm` instance and its disk
  serials, nested KVM, btrfs snapshots, Docker and Tailscale on the same host,
  everything in phase 4, and `provision.sh` past its base section. All phases
  stay `draft`: nothing has run on g7 and Q1-Q10 are open.
