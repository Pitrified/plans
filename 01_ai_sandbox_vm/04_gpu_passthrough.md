---
status: draft
---

# Phase 4 - GPU passthrough

## Overview

Give the VM the Quadro RTX 3000 when wanted, by booting the host headless. This
is the only real technical unknown in the whole effort: mobile NVIDIA cards
sometimes refuse to initialize in a guest without extra tricks. It is sequenced
after the VM is usable so that a failure here costs nothing else, but it is
worth a short spike as soon as phase 2 is done.
Context: [`00_start.md`](00_start.md), host capture in
[`01.1_host_facts.md`](01.1_host_facts.md), depends on
[`02_guest_base_and_provisioning.md`](02_guest_base_and_provisioning.md).

This is system-level work on g7 (boot entries, driver binding). Pause for
approval before running it.

## Goals

1. A way to boot the host with no desktop and the NVIDIA driver not loaded.
2. A second Incus profile that adds the GPU to the same VM.
3. CUDA and OptiX working in the guest: `nvidia-smi`, then a Blender render.
4. A one-command way into GPU mode and a plain reboot back out.

## Plan

Commands are the intended shape and have not been run.

### Host: a one-shot headless boot

A second GRUB menu entry, a copy of the default one with these added to the
kernel command line:

```
systemd.unit=multi-user.target
modprobe.blacklist=nvidia,nvidia_drm,nvidia_modeset,nvidia_uvm,nouveau
vfio-pci.ids=10de:1f36,10de:10f9,10de:1ada,10de:1adb
```

Entered once, so the next reboot returns to the normal desktop with no cleanup:

```bash
sudo grub-reboot "<entry name>" && sudo reboot
```

`grub-reboot` needs `GRUB_DEFAULT=saved` in `/etc/default/grub`.

Fallback if the entry is more trouble than it is worth: boot normally, then

```bash
sudo systemctl isolate multi-user.target
sudo systemctl stop nvidia-persistenced
sudo modprobe -r nvidia_drm nvidia_modeset nvidia_uvm nvidia
```

and let Incus bind the card at VM start.

After the headless boot, check before starting the VM:

```bash
lspci -nnk -s 01:00      # each function: "Kernel driver in use: vfio-pci"
```

### Incus: the GPU as a profile

```bash
incus profile create sbx-gpu
incus profile device add sbx-gpu gpu gpu gputype=physical pci=0000:01:00.0
```

Toggle, with the VM stopped:

```bash
incus profile add sbx sbx-gpu       # GPU mode
incus profile remove sbx sbx-gpu    # back to CPU-only
```

`sbx up` and `sbx up --gpu` do the toggle. The second refuses to start while
`01:00.0` is bound to any host driver other than `vfio-pci`. Written, never
run: there was no GPU in the lab.

### Guest

The NVIDIA driver goes into the provisioning script (`ubuntu-drivers install`
or a pinned `nvidia-driver-NNN`). With no card present the driver finds nothing
and everything else works, so one image serves both modes.

```bash
nvidia-smi
blender -b -E CYCLES --python-expr "<enable OPTIX, render one frame>"
```

## Pitfalls

- **The card may not initialize in the guest** (`nvidia-smi` errors, or code 43
  style failures). Known remedies for mobile cards, in rising order of effort:
  hide the hypervisor from the guest, pass the card's vBIOS as a ROM file, add
  a fake battery ACPI table. These go through raw QEMU options in Incus
  (`raw.qemu`, `raw.qemu.conf`) and are better documented for libvirt. Three
  failed evenings here is the signal to move this VM to libvirt, per the
  fallback in `00_start.md`.
- **All four functions share one IOMMU group.** The whole group has to be off
  host drivers. Whether Incus needs the audio and USB functions added as
  separate `pci` devices, or only needs them unbound, is to be found out.
- **Headless means no screen at all**: with the card on `vfio-pci` and no
  integrated GPU exposed, the laptop panel may show nothing, not even a text
  console. The host must be reachable over SSH before trying this, and the
  one-shot entry is the safety net: a power cycle brings the desktop back.
- **No live snapshots** of a VM with a passed-through device. Volume snapshots
  are unaffected.

## Out of scope

- Sharing the GPU between host and VM. Not available on this card.
- BIOS hybrid graphics. Rejected in `00_start.md`; revisit only if rebooting to
  switch becomes annoying.

## Done when

- From a normal desktop session, one command reboots into headless mode and the
  host is reachable over SSH.
- `sbx up --gpu` starts the VM and `nvidia-smi` in the guest shows the Quadro.
- A Cycles render in the guest uses OptiX or CUDA.
- A plain reboot brings the desktop back with the NVIDIA driver working on the
  host, and `sbx up` starts the same VM without the GPU.

## Rollback

Remove the GRUB entry and run `sudo update-grub`; `incus profile remove sbx
sbx-gpu`; `incus profile delete sbx-gpu`. Nothing else on the host changes.
