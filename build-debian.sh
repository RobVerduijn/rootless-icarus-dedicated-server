#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="localhost/debian-steamcmd"
IMAGE_TAG="latest"

container=$(buildah from debian:bookworm-slim)

buildah run "$container" -- bash -c '
  set -euo pipefail

  dpkg --add-architecture i386

  apt-get update
  apt-get upgrade -y --no-install-recommends --no-install-suggests
  apt-get install -y --no-install-recommends --no-install-suggests \
    ca-certificates \
    curl \
    lib32gcc-s1

  # Aggressive system cleanup
  apt-get clean
  apt-get autoremove -y
  rm -rf /var/lib/apt/lists/*
  rm -rf /var/cache/*
  rm -rf /var/log/*
  rm -rf /var/tmp/*
  rm -rf /tmp/*
  find /var/spool -type f -delete

  # Strip dpkg metadata/database completely
  rm -rf /var/lib/dpkg/info/*
  rm -rf /var/lib/dpkg/available
  true > /var/lib/dpkg/status

  useradd -m steam
  mkdir -p /home/steam/Steam /home/steam/server
  chown -R steam:steam /home/steam
'

buildah config --user steam "$container"
buildah config --workingdir /home/steam "$container"
buildah copy "$container" entrypoint_steamcmd.sh /home/steam/entrypoint_steamcmd.sh
buildah config --entrypoint '["/bin/bash", "/home/steam/entrypoint_steamcmd.sh"]' "$container"

buildah commit --squash "$container" "${IMAGE_NAME}:${IMAGE_TAG}"
buildah rm "$container"