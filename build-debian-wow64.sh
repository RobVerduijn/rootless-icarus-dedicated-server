#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="registry.tjako.thuis:9999/library/icarus-dedicated-server"
IMAGE_TAG="1.22"
APP_ID="2089300"

container=$(buildah from debian:trixie-slim)

buildah run "$container" -- bash -c '
  set -xeuo pipefail

  dpkg --add-architecture i386

  # Remove the default DEB822 sources file to prevent duplicate repository warnings
  rm -f /etc/apt/sources.list.d/debian.sources

  # Write clean traditional sources with main and contrib for trixie
  echo "deb http://deb.debian.org/debian trixie main contrib" > /etc/apt/sources.list
  echo "deb http://deb.debian.org/debian-security trixie-security main contrib" >> /etc/apt/sources.list

  apt-get update
  apt-get install -y --no-install-recommends --no-install-suggests \
    ca-certificates \
    curl \
    lib32gcc-s1 \
    libwine \
    wine \
    wine64

  # Aggressive system cleanup
  apt-get clean
  apt-get autoremove -y
  rm -rf /var/lib/apt/lists/*
  rm -rf /var/cache/*
  rm -rf /var/log/*
  rm -rf /var/tmp/*
  rm -rf /tmp/*
  find /var/spool -type f -delete

  ## Delete unnecessary binaries/docs/man to reduce image size
  rm -rf /usr/share/man /usr/share/doc /usr/share/info /usr/share/lintian /usr/share/locale/*

  # Strip dpkg metadata/database completely
  rm -rf /var/lib/dpkg/info/*
  rm -rf /var/lib/dpkg/available
  true > /var/lib/dpkg/status

  useradd -m steam
  mkdir -p /home/steam/Steam /home/steam/server /home/steam/.wine
  chown -R steam:steam /home/steam
'

buildah config --user steam "$container"
buildah config --workingdir /home/steam/server "$container"

# Set App ID and server configuration environment variables
buildah config --env APP_ID="${APP_ID}" "$container"
buildah config --env SESSIONNAME="" "$container"
buildah config --env JOINPASSWORD="" "$container"
buildah config --env MAXPLAYERS="" "$container"
buildah config --env ADMINPASSWORD="" "$container"
buildah config --env RESUMEPROSPECT="" "$container"
buildah config --env LASTPROSPECTNAME="" "$container"
buildah config --env LOADPROSPECT="" "$container"
buildah config --env CREATEPROSPECT="" "$container"
buildah config --env SHUTDOWNNOTJOINEDFOR="" "$container"
buildah config --env SHUTDOWNEMPTYFOR="" "$container"
buildah config --env ALLOWNONADMINSLAUNCH="" "$container"
buildah config --env ALLOWNONADMINSDELETE="" "$container"
buildah config --env FIBERFOLIAGERESPAWN="" "$container"
buildah config --env GAMESAVEFREQUENCY="" "$container"
buildah config --env LARGESTONERESPAWN="" "$container"
buildah config --env SAVEGAMEONEXIT="" "$container"
buildah config --env PORT="" "$container"
buildah config --env QUERYPORT="" "$container"

buildah copy "$container" runsteamcmd.sh /home/steam/runsteamcmd.sh
buildah config --entrypoint '["/bin/bash", "/home/steam/runsteamcmd.sh"]' "$container"

# Commit the container as a single flattened image layer
buildah commit "$container" "${IMAGE_NAME}:${IMAGE_TAG}"
if [ ${IMAGE_TAG} -ne latest ] ; then buildah commit "$container" "${IMAGE_NAME}:latest" ; fi
buildah rm "$container"