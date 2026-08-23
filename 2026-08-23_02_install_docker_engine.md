# Install Docker engine and the compose plugin

## Goal

Get Docker and `docker compose` onto the box so `genealogy-gramps-fn` can bring up the Gramps Web
stack. Nothing else on the box uses containers today; this is the first.

Context: `~/repos/genealogy-gramps-fn/plans/02_stack_bringup/`, phase 1.

## Decisions

**Packages: `docker.io` + `docker-compose-v2` from Ubuntu universe.**
Candidates on this box are `29.1.3-0ubuntu4.1` and `2.40.3+ds1-0ubuntu1`, both current enough for
anything this project does.

*Rejected: `docker-ce` from Docker's own apt repository.* It is the more common instruction set
online, and it ships newer point releases. It also adds a third-party apt key and repository to a
box whose whole design is a small, apt-managed surface, and it needs its own attention at every
release upgrade. Nothing in this project needs a Docker feature newer than 29.1.

**Rootful Docker, the default.** Rootless would be the stronger posture, and it is worth
revisiting.

*Not now, for two reasons.* It complicates bind-mount ownership, which this project depends on
(the Gramps data directory is bind-mounted so the backup target is one path). And the security
posture of the whole service is `06_security_assessment` in the project's own plan folder, which
is where a change like this should be argued with the threat model in front of it rather than
decided as a side effect of an install.

**The ceiling that comes with that choice, stated rather than discovered later:** containers run
as root, the daemon runs as root, and a container escape is root on the box. That is the standard
posture and it is what the rest of the world runs, but it is a real ceiling and the upgrade path
is rootless mode.

**Add `pmn` to the `docker` group.** The Makefile targets in the project (`make up`, `make logs`)
have to run unprivileged, and prefixing every one of them with a privileged command defeats the
point of having them.

**`docker` group membership is equivalent to root on this box.** Anyone in that group can start a
container that mounts `/` and read or write anything. That is not a flaw in the plan, it is what
the group means, and it is acceptable here because `pmn` is the only human account and already
has full privileges. Worth writing down so nobody later reads the group as a lesser privilege.

**Storage.** `/var/lib/docker` will hold images and the container filesystems, and it grows.
`/` has 161 GiB free, and the Gramps images are on the order of hundreds of megabytes, so this is
not a constraint now. The tree data does not live there: it goes in a bind-mounted directory the
project decides in its phase 2.

**Autostart.** The Ubuntu package enables `docker.service` on install, so the stack comes back
after a reboot once the compose file sets a restart policy. No extra unit is needed.

## Steps

Run in a real terminal. Each command is teed to a log so the session can verify the result.

```bash
mkdir -p ~/handoff-logs

# 1 - install
sudo apt update 2>&1 | tee ~/handoff-logs/01a-apt-update.log
sudo apt install -y docker.io docker-compose-v2 2>&1 | tee ~/handoff-logs/01b-apt-install-docker.log

# 2 - let pmn talk to the daemon without elevation
sudo usermod -aG docker pmn 2>&1 | tee ~/handoff-logs/01c-usermod-docker.log

# 3 - verify (the group only applies to new sessions, hence the fresh login)
newgrp docker <<'EOF' 2>&1 | tee ~/handoff-logs/01d-verify-docker.log
docker --version
docker compose version
systemctl is-enabled docker
systemctl is-active docker
docker run --rm hello-world
id -nG
EOF
```

Step 3 has to run in a session that has picked up the new group. `newgrp` does that inline; a
logout and login, or restarting the VS Code remote session, works too.

## Verification

From the logs:

- `docker --version` reports 29.1.x
- `docker compose version` reports 2.40.x, as a subcommand rather than the old `docker-compose`
- `systemctl is-enabled docker` is `enabled`, `is-active` is `active`
- `docker run --rm hello-world` prints the greeting and exits 0
- `id -nG` lists `docker`

## Rollback

```bash
sudo apt purge -y docker.io docker-compose-v2
sudo apt autoremove -y
sudo gpasswd -d pmn docker
sudo rm -rf /var/lib/docker /var/lib/containerd
```

The last line destroys every image, container and named volume. It is the right thing when
abandoning the project, and the wrong thing if anything else on the box has started using Docker
in the meantime. Nothing does today.

The bind-mounted Gramps data directory is outside `/var/lib/docker` and survives all of this,
which is the point of bind-mounting it.
