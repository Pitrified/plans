#!/usr/bin/env bash
# Lab only: boot the real guest/cloud-init.yaml in a true VM where Incus cannot
# run one (no KVM here, so QEMU emulates the CPU in software: slow, but a real
# kernel, real disks, real cloud-init). The VM's NIC is a tap on the Incus
# bridge, so the same ACL and host guard apply to it.
#   qemu_vm.sh start|stop|console
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
W=${SBX_BUILD:-/var/tmp/sbxbuild}; V=$W/vm; IP=${SBX_VM_IP:-10.77.0.20}
case "${1:-start}" in
stop) [ -f "$V/pid" ] && kill "$(cat "$V/pid")" 2>/dev/null || true; ip link del sbxtap0 2>/dev/null || true ;;
console) tail -n "${2:-40}" "$V/console.log" ;;
start)
  mkdir -p "$V/seed"
  # Root disk: built once from the guest tree. Deleting root.img is a rebuild.
  [ -f "$V/root.img" ] || { truncate -s 6G "$V/root.img"; mkfs.ext4 -q -L root -d "$W/vmroot" "$V/root.img"; }
  # The two persistent volumes: blank on first use, kept afterwards.
  for d in projects caches; do [ -f "$V/$d.img" ] || truncate -s 2G "$V/$d.img"; done
  sed "s|__SSH_PUBKEY__|$(cat ~/.ssh/sbx_ed25519.pub)|" "$HERE/../guest/cloud-init.yaml" > "$V/seed/user-data"
  printf 'instance-id: sbxvm-%s\nlocal-hostname: sbxvm\n' "$(stat -c %W "$V/root.img")" > "$V/seed/meta-data"
  cat > "$V/seed/network-config" <<N
version: 2
ethernets:
  nic0:
    match: {name: "e*"}
    addresses: [$IP/24]
    routes: [{to: default, via: 10.77.0.1}]
    nameservers: {addresses: [10.77.0.1]}
N
  genisoimage -quiet -output "$V/seed.iso" -volid cidata -joliet -rock "$V/seed"/{user-data,meta-data,network-config}
  ip link del sbxtap0 2>/dev/null || true
  ip tuntap add sbxtap0 mode tap; ip link set sbxtap0 master sbxbr0 up
  : > "$V/console.log"
  qemu-system-x86_64 -machine q35 -accel tcg,thread=multi -cpu max -smp 2 -m 2048 \
    -kernel "$W/kernel" -initrd "$W/initrd" -append "root=LABEL=root ro console=ttyS0" \
    -drive file="$V/root.img",if=none,id=d0,format=raw     -device virtio-blk-pci,drive=d0 \
    -drive file="$V/caches.img",if=none,id=d1,format=raw   -device virtio-blk-pci,drive=d1,serial=incus_caches \
    -drive file="$V/projects.img",if=none,id=d2,format=raw -device virtio-blk-pci,drive=d2,serial=incus_projects \
    -drive file="$V/seed.iso",if=none,id=d3,format=raw,readonly=on -device virtio-blk-pci,drive=d3 \
    -netdev tap,id=n0,ifname=sbxtap0,script=no,downscript=no \
    -device virtio-net-pci,netdev=n0,mac=52:54:00:77:00:20 \
    -display none -serial "file:$V/console.log" -pidfile "$V/pid" -daemonize
  echo "started, console in $V/console.log, address $IP" ;;
esac
