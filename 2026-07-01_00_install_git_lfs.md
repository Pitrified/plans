# Install Git LFS

## Goal

Install Git LFS on this box and add a repeatable install script to the bootstrap repo.

## Decisions

- Install method: official packagecloud apt repo (github/git-lfs), then `apt install git-lfs`.
  This means apt always tracks the latest release and normal `apt upgrade` keeps it current -
  no version pinning to maintain. Falls back to no manual link needed.
- Run `git lfs install` once to set up the git hooks/filters for the user.
- Script lives in bootstrap repo as `install_git_lfs.sh`, styled like the other install\_\*.sh.

## Steps

- curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash
- sudo apt-get install -y git-lfs
- git lfs install
- Create install_git_lfs.sh + README entry.

## Rollback

- sudo apt-get remove --purge git-lfs
- sudo rm /etc/apt/sources.list.d/github_git-lfs.list
- git lfs uninstall
