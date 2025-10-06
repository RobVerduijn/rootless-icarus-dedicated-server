#!/bin/bash

# install steamcmd
function install_steamcmd () {
  echo =========================
  echo == Installing steamcmd ==
  echo =========================
  if [ ! -e $STEAM_CMD_DIR ] ; then mkdir -p $STEAM_CMD_DIR ; fi
  pushd $STEAM_CMD_DIR
    curl -sqL $STEAM_CMD_URL | tar zxvf -
  popd
}

# install/update the game
#   The steamcmd will always create directory Steam and steam in the container user home dir if they do not exist.
function update() {
  echo ====================
  echo == Updateing game ==
  echo ====================
  if [ ! -e $STEAM_GAME_DIR ] ; then mkdir -p $STEAM_GAME_DIR ; fi
  pushd $STEAM_CMD_DIR
  ./steamcmd.sh \
    +@sSteamCmdForcePlatformType windows \
    +force_install_dir $STEAM_GAME_DIR \
    +login anonymous \
    +app_update 2089300 -beta "${BRANCH:-public}" validate \
    +quit
  popd
}

function server_config () {


  if [ -z "$ADMIN_PASSWORD" ] ; then
    # If you neglect to set the admin password you will regret it sooner or later
    # Using openssl to generate a random 32 character string if the password is empty
    # Base64 encoding ensures there is no weird characters in the password that could mess up this script
    echo "ADMIN_PASSWORD is set to: ${ADMIN_PASSWORD:=$(openssl rand -base64 32)}"
  fi

  if [ -z "$SERVERNAME" ] ; then
    echo "SERVERNAME default set to: ${SERVERNAME:=Icarus Dedicated Server}"
  fi

  if [ -z "$SERPORTVERNAME" ] ; then
    echo "PORT default set to: ${PORT:=17777}"
  fi

  if [ -z "$QUERYPORT" ] ; then
    echo "QUERYPORT default set to: ${QUERYPORT:=27015}"
  fi

  if [ -z "$SHUTDOWN_NOT_JOINED_FOR" ] ; then
    echo "ShutdownIfNotJoinedFor default set to: ${SHUTDOWN_NOT_JOINED_FOR:=40.000000}"
  fi

  if [ -z "$SHUTDOWN_EMPTY_FOR" ] ; then
    echo "ShutdownIfEmptyFor default set to: ${SHUTDOWN_EMPTY_FOR:=30.000000}"
  fi

  if [ -z "$GAMESAVEFREQUENCY" ] ; then
    echo "GameSaveFrequency default set to: ${GAMESAVEFREQUENCY:=10.000000}"
  fi

  # Here's what we are going to configure
  echo "============================================================="
  echo "Configuring ${SERVERNAME:-Icarus Dedicated Server} with the following config"
  echo "============================================================="
  echo ""
  echo "SessionName=${SERVERNAME:-Icarus Dedicated Server}"
  echo "Port=${PORT}"
  echo "QueryPort=${QUERYPORT}"
  echo ""
  echo "JoinPassword=${JOIN_PASSWORD}"
  echo "MaxPlayers=${MAX_PLAYERS}"
  echo "ShutdownIfNotJoinedFor=${SHUTDOWN_NOT_JOINED_FOR}"
  echo "ShutdownIfEmptyFor=${SHUTDOWN_EMPTY_FOR}"
  echo "AdminPassword=${ADMIN_PASSWORD}"
  echo "LoadProspect=${LOAD_PROSPECT}"
  echo "CreateProspect=${CREATE_PROSPECT}"
  echo "ResumeProspect=${RESUME_PROSPECT}"
  echo "LastProspect="
  echo "AllowNonAdminsToLaunchProspects=${ALLOW_NON_ADMINS_LAUNCH}"
  echo "AllowNonAdminsToDeleteProspects=${ALLOW_NON_ADMINS_DELETE}"
  echo "FiberFoliageRespawn=${FIBERFOLIAGERESPAWN}"
  echo "LargeStonesRespawn=${FIBERFOLIAGERESPAWN}"
  echo "GameSaveFrequency=${GAMESAVEFREQUENCY}"
  echo "SaveGameOnExit=${SAVEGAMEONEXIT}"
  echo ""
  echo "============================================================="

  serverconfigdir="$STEAM_GAME_DIR/drive_c/icarus/Saved/Config/WindowsServer"
  serversettingsini="$serverconfigdir/ServerSettings.ini"

  # Ensure the server config dir exists
  if [ ! -e $serverconfigdir ] ; then mkdir -p $serverconfigdir ; fi
  # Ensure the serversettings.ini file exists
  if [ ! -e $serversettingsini ] ; then
  # The 'here document' '<<-' redirection deletes all leading tabs
  # Replacing the tabs with spaces will break the script.
  cat > $serversettingsini <<- EOF
	[/Script/Icarus.DedicatedServerSettings]
	SessionName=
	JoinPassword=
	MaxPlayers=
	ShutdownIfNotJoinedFor=
	ShutdownIfEmptyFor=
	AdminPassword=
	LoadProspect=
	CreateProspect=
	ResumeProspect=
	LastProspect=
	AllowNonAdminsToLaunchProspects=
	AllowNonAdminsToDeleteProspects=
	FiberFoliageRespawn=
	LargeStonesRespawn=
	GameSaveFrequency=
	SaveGameOnExit=
	EOF
  fi

  # Always apply the settings
  sed -i "/SessionName=/c\SessionName=${SERVERNAME}" ${serversettingsini}
  sed -i "/JoinPassword=/c\JoinPassword=${JOIN_PASSWORD}" ${serversettingsini}
  sed -i "/MaxPlayers=/c\MaxPlayers=${MAX_PLAYERS}" ${serversettingsini}
  sed -i "/ShutdownIfNotJoinedFor=/c\ShutdownIfNotJoinedFor=${SHUTDOWN_NOT_JOINED_FOR}" ${serversettingsini}
  sed -i "/ShutdownIfEmptyFor=/c\ShutdownIfEmptyFor=${SHUTDOWN_EMPTY_FOR}" ${serversettingsini}
  sed -i "/AdminPassword=/c\AdminPassword=${ADMIN_PASSWORD}" ${serversettingsini}
  sed -i "/LoadProspect=/c\LoadProspect=${LOAD_PROSPECT}" ${serversettingsini}
  sed -i "/CreateProspect=/c\CreateProspect=${CREATE_PROSPECT}" ${serversettingsini}
  sed -i "/ResumeProspect=/c\ResumeProspect=${RESUME_PROSPECT}" ${serversettingsini}
  sed -i "/AllowNonAdminsToLaunchProspects=/c\AllowNonAdminsToLaunchProspects=${ALLOW_NON_ADMINS_LAUNCH}" ${serversettingsini}
  sed -i "/AllowNonAdminsToDeleteProspects=/c\AllowNonAdminsToDeleteProspects=${ALLOW_NON_ADMINS_DELETE}" ${serversettingsini}
  sed -i "/FiberFoliageRespawn=/c\FiberFoliageRespawn=${FIBERFOLIAGERESPAWN}" ${serversettingsini}
  sed -i "/LargeStonesRespawn=/c\LargeStonesRespawn=${LARGESTONERESPAWN}" ${serversettingsini}
  sed -i "/GameSaveFrequency=/c\GameSaveFrequency=${GAMESAVEFREQUENCY}" ${serversettingsini}
  sed -i "/SaveGameOnExit=/c\SaveGameOnExit=${SAVEGAMEONEXIT}" ${serversettingsini}
}

function rungame () {
  echo ==============================================================
  echo Starting Server
  echo ==============================================================
  echo Find your server settings here: game/drive_c/icarus/Saved/Config/WindowsServer
  echo Find your prospects here: game/drive_c/icarus/Saved/PlayerData/DedicatedServer/Prospects
  echo Find your server logs here: game/drive_c/icarus/Saved/Logs
  echo ==============================================================
  wine $STEAM_GAME_DIR/Icarus/Binaries/Win64/IcarusServer-Win64-Shipping.exe \
    -UserDir='C:\icarus' \
    -SteamServerName="${SERVERNAME:-Icarus Dedicated Server}" \
    -PORT="${PORT:-17777}" \
    -QueryPort="${QUERYPORT:-27015}"
}

if [ ! -e $STEAM_CMD_DIR/steamcmd.sh ] ; then install_steamcmd ; fi
update
server_config
rungame
