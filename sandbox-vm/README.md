# sandbox-vm

Scripts for the AI sandbox VM. The plan, the decisions and the record of what
was tried are in the tracked development folder for this effort; this folder is
only the code.

Provisional location: these were written during a lab run and may move.

| Path | What it is | Where it runs |
| ---- | ---------- | ------------- |
| `sbx` | the wrapper: up, ssh, in, out, carry, provision, rebuild, test | host |
| `host/network.sh` | the bridge, the internet-only ACL, the host guard | host |
| `host/host_guard.nft` | drops connections from the bridge to the host itself | host |
| `host/isolation_test.sh` | proves internet works and everything else is blocked | host |
| `guest/cloud-init.yaml` | user, SSH, the two persistent disks | guest, first boot |
| `guest/provision.sh` | the reviewed list of what the sandbox contains | guest |
| `lab/` | stand-ins used to test all of the above on a machine with no KVM | lab only |

## What has been run

Everything except the GPU, on a cloud container with no KVM (Incus 6.0.0,
QEMU 8.2.2, Ubuntu 24.04): the Incus side against a system container, and
`guest/cloud-init.yaml` in a real VM under QEMU software emulation.

Not run anywhere: an Incus VM (`--vm`), GPU passthrough, nested KVM, and every
section of `provision.sh` other than `base`.

## Use

```bash
host/network.sh                 # once
sbx up                          # creates the sandbox on first use
sbx provision
cd ~/repos/<project> && sbx in  # push the current branch in
sbx ssh                         # work
sbx out                         # fetch, review, fast-forward
git push                        # publish, from the host
sbx rebuild                     # fresh sandbox; volumes and login survive
```

Settings are environment variables with defaults at the top of `sbx`, read
from `~/.local/state/sbx/config` when that file exists.
