FROM debian:trixie-slim

RUN set -xeuo pipefail && \
    dpkg --add-architecture i386 && \
    rm -f /etc/apt/sources.list.d/debian.sources && \
    echo "deb http://deb.debian.org/debian trixie main contrib" > /etc/apt/sources.list && \
    echo "deb http://deb.debian.org/debian-security trixie-security main contrib" >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
      ca-certificates \
      curl \
      lib32gcc-s1 \
      libwine \
      wine \
      wine64 && \
    apt-get clean && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /var/cache/* && \
    rm -rf /var/log/* && \
    rm -rf /var/tmp/* && \
    rm -rf /tmp/* && \
    find /var/spool -type f -delete && \
    rm -rf /usr/share/man /usr/share/doc /usr/share/info /usr/share/lintian /usr/share/locale/* && \
    rm -rf /var/lib/dpkg/info/* && \
    rm -rf /var/lib/dpkg/available && \
    true > /var/lib/dpkg/status && \
    useradd -m steam && \
    mkdir -p /home/steam/Steam /home/steam/server /home/steam/.wine && \
    chown -R steam:steam /home/steam

USER steam
WORKDIR /home/steam/server

ENV APP_ID="2089300" \
    SESSIONNAME="" \
    JOINPASSWORD="" \
    MAXPLAYERS="" \
    ADMINPASSWORD="" \
    RESUMEPROSPECT="" \
    LASTPROSPECTNAME="" \
    LOADPROSPECT="" \
    CREATEPROSPECT="" \
    SHUTDOWNNOTJOINEDFOR="" \
    SHUTDOWNEMPTYFOR="" \
    ALLOWNONADMINSLAUNCH="" \
    ALLOWNONADMINSDELETE="" \
    FIBERFOLIAGERESPAWN="" \
    GAMESAVEFREQUENCY="" \
    LARGESTONERESPAWN="" \
    SAVEGAMEONEXIT="" \
    PORT="" \
    QUERYPORT=""

COPY --chown=steam:steam runsteamcmd.sh /home/steam/runsteamcmd.sh

ENTRYPOINT ["/bin/bash", "/home/steam/runsteamcmd.sh"]