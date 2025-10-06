# see: https://icarus.wiki.gg/wiki/Dedicated_Servers
#      https://github.com/RocketWerkz/IcarusDedicatedServer/wiki
#      https://developer.valvesoftware.com/wiki/SteamCMD

# LTS is for physical and virtual systems that exist for prolonged times,
# containers are short lived and easely re-created from scratch.
# And if containers fail, we can simply revert to the old image or fix the new build.
FROM ubuntu:25.04

# These environment vars MUST be set or the container won't work
#   The steam user only exists in the container, no need to create it on the host
#   All the paths mentioned in this dockerfile exist only in the container
#   There is no need to create any of these paths on the container host.
#
# When running rootless there is no need to rename steam user,UID,GID etc.
# It only exists in the container, on the container host it will be assigned a random UID/GID without any privileges.
#

ENV BRANCH=public
ENV STEAM_USER=steam
ENV STEAM_GROUP=$STEAM_USER
ENV STEAM_USER_UID=1001
ENV STEAM_USER_GID=1001
ENV STEAM_CMD_DIR=/home/$STEAM_USER/Steam
ENV STEAM_CMD=$STEAM_CMD_DIR/steamcmd.sh
ENV STEAM_CMD_URL=https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
ENV STEAM_GAME_DIR=/home/$STEAM_USER/game
ENV WINEPREFIX=$STEAM_GAME_DIR
ENV WINEARCH=win64

# Summarizing the environment vars for reference use.
# Defaults will be set by the runicarus.sh script if they are needed.
ENV ADMIN_PASSWORD=""
ENV ALLOW_NON_ADMINS_LAUNCH=""
ENV ALLOW_NON_ADMINS_DELETE=""
ENV CREATE_PROSPECT=""
ENV GAMESAVEFREQUENCY=""
ENV JOIN_PASSWORD=""
ENV LOAD_PROSPECT=""
ENV MAX_PLAYERS=""
ENV SHUTDOWN_NOT_JOINED_FOR=""
ENV SHUTDOWN_EMPTY_FOR=""
ENV PORT=""
ENV QUERYPORT=""
ENV RESUME_PROSPECT=""
ENV SAVEGAMEONEXIT=""
ENV SERVERNAME=""
ENV FIBERFOLIAGERESPAWN=""
ENV LARGESTONERESPAWN=""
ENV GAMESAVEFREQUENCY=""
ENV SAVEGAMEONEXIT=""

# Using heredoc reduces the need for RUN entries thus creating less layers which results in smaller images
# It also makes the script more readable
RUN <<EOF
  # be verbose and exit on error
  set -xeuo pipefail

  # steam needs this
  dpkg --add-architecture i386

  # Installing locales adds an additional 20Mb to the image
  # apt-get update
  # apt-get install -y --no-install-recommends --no-install-suggests locales
  # sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
  # dpkg-reconfigure --frontend=noninteractive locales

  # lib32gcc-s1 ca-certificates and curl are required for steamcmd
  # wine wine64 are required to run a windows based server
  apt-get update
  apt-get install -y --no-install-recommends --no-install-suggests \
    ca-certificates \
    curl \
    lib32gcc-s1 \
    wine \
    wine64

  # create steam user and group in the container
  groupadd -g $STEAM_USER_GID $STEAM_GROUP
  useradd -m -u $STEAM_USER_UID -g $STEAM_USER_GID $STEAM_USER

  # clean up to reduce image size
  apt-get clean -y
  rm /var/{log,cache,lib}/* -rf
EOF

# now switch from root to the steam user
USER $STEAM_USER

# set current working dir to steam user home
WORKDIR /home/$STEAM_USER

# copy the script to current work directory
COPY runicarus.sh .

# Our script needs the entry point to be bash
ENTRYPOINT ["/bin/bash"]

# Run script by default on launch
CMD ["/home/steam/runicarus.sh"]

# Add the squash option when building the container to reduce it's size even more.
# Modify the compose.yml/icarus.container to match your container host setup
# Easiest way to start is with docker compose up