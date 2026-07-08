# Remove packagecloud git-lfs apt repo

## Goal

Stop `apt update` from erroring on the packagecloud git-lfs repo (404 on `resolute`),
by removing that repo entirely - git-lfs already comes from Ubuntu's own repos.

## Background / why

- `apt update` errors:
  `packagecloud.io/github/git-lfs/ubuntu resolute Release` -> 404 Not Found.
- The repo was added by `~/bootstrap/install_git_lfs.sh`, which runs the packagecloud
  installer (`curl .../script.deb.sh | sudo bash`). It wrote
  `/etc/apt/sources.list.d/github_git-lfs.list` pinned to codename `resolute`.
  See plan `2026-07-01-00-install-git-lfs.md`.
- This box is Ubuntu 26.04 "resolute" (new). packagecloud has not built git-lfs for
  `resolute` yet, so the Release file 404s. The install script hardcoded the current
  codename, which has no upstream build.
- Nobody needs packagecloud: the installed git-lfs is `3.7.1-1ubuntu0.26.04.1~esm1`
  from Ubuntu ESM (`apt-cache policy git-lfs` shows it at priority 510). Ubuntu also
  ships `git-lfs 3.7.1-1` in `resolute/universe`. The packagecloud repo is redundant
  and never supplied the installed binary.

## Decisions

- Remove the packagecloud repo rather than patch its codename. git-lfs from Ubuntu
  universe/ESM gets security updates through the normal channel; no version pinning
  needed. Losing "always the newest upstream release" is acceptable - we didn't rely on it.
- Keep git-lfs itself installed (it stays, sourced from Ubuntu).
- Fix the bootstrap script so new machines don't re-add packagecloud.

## Steps

On this box:
- `sudo rm /etc/apt/sources.list.d/github_git-lfs.list`
- `sudo rm /etc/apt/keyrings/github_git-lfs-archive-keyring.gpg`
- `sudo apt-get update`  (confirm no more packagecloud error)
- `git-lfs version`      (confirm still installed)

Bootstrap repo (`~/bootstrap/install_git_lfs.sh`) - replace the packagecloud lines
with a plain Ubuntu install:
- drop the `curl ... packagecloud ... | sudo bash` line
- keep `sudo apt-get install -y git-lfs` (now resolves from Ubuntu universe/ESM)
- keep `git lfs install --skip-repo` and `git lfs version`
- update the plan note `2026-07-01-00-install-git-lfs.md` decision text to reflect
  Ubuntu-repo install (optional; historical note).
- Push happens from a g7 session, not this box.

## Rollback

- Re-run the packagecloud installer:
  `curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash`
  (only works once packagecloud publishes a `resolute` build; until then the repo
  would 404 again - which is exactly why we're removing it).
