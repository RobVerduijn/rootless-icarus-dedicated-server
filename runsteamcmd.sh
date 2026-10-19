#!/usr/bin/env bash
set -euo pipefail

if [ "${DEBUG:=0}" = "1" ]; then
  set -x
fi

BETA_BRANCH="${BETA_BRANCH:=}"
declare -a CONFIG_ITEMS

load_config_defaults() {
  if [ "$DEBUG" = "1" ]; then
    set -x
  fi

  # see https://github.com/RocketWerkz/IcarusDedicatedServer/wiki/Server-Config-&-Launch-Parameters

  # If you neglect to set the admin password you will regret it sooner or later
  # Using urandom to generate a random 32 character string if the password is empty

  echo "--> Setting configuration defaults"

  local SessionName=${SESSIONNAME:=Icarus Dedicated Server}
  local JoinPassword=${JOINPASSWORD:=''}
  local MaxPlayers=${MAXPLAYERS:=8}
  local AdminPassword=${ADMINPASSWORD:=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 32)}
  local ResumeProspect=${RESUMEPROSPECT:=''}
  local LastProspectName=${LASTPROSPECTNAME:=''}
  local LoadProspect=${LOADPROSPECT:=''}
  local CreateProspect=${CREATEPROSPECT:=''}
  local ShutdownIfNotJoinedFor=${SHUTDOWNNOTJOINEDFOR:=40.000000}
  local ShutdownIfEmptyFor=${SHUTDOWNEMPTYFOR:=30.000000}
  local AllowNonAdminsToLaunchProspects=${ALLOWNONADMINSLAUNCH:=true}
  local AllowNonAdminsToDeleteProspects=${ALLOWNONADMINSDELETE:=false}
  local FiberFoliageRespawn=${FIBERFOLIAGERESPAWN:=true}
  local GameSaveFrequency=${GAMESAVEFREQUENCY:=10.000000}
  local LargeStonesRespawn=${LARGESTONERESPAWN:=true}
  local SaveGameOnExit=${SAVEGAMEONEXIT:=true}
  local Port=${PORT:=17777}
  local QueryPort=${QUERYPORT:=27015}

  local ServerSettings=/home/steam/server/Icarus/Saved/Config/WindowsServer/ServerSettings.ini
  local Engine=/home/steam/server/Icarus/Saved/Config/WindowsServer/Engine.ini

  CONFIG_ITEMS=(
    "$ServerSettings|/Script/Icarus.DedicatedServerSettings|SessionName|${SessionName}|Sets the session name in the server browser"
    "$ServerSettings|/Script/Icarus.DedicatedServerSettings|JoinPassword|${JoinPassword}|Password required to join the server. Leave empty to not use a password"
    "$ServerSettings|/Script/Icarus.DedicatedServerSettings|MaxPlayers|${MaxPlayers}|Max Players that can be on the server at once. Minimum 1, Maximum 8"
    "$ServerSettings|/Script/Icarus.DedicatedServerSettings|AdminPassword|${AdminPassword}|Password required for using admin RCON commands"
    "$ServerSettings|/Script/Icarus.DedicatedServerSettings|ResumeProspect|${ResumeProspect}|If true, automatically resume the last prospect on startup"
    "$ServerSettings|/Script/Icarus.DedicatedServerSettings|LastProspectName|${LastProspectName}|The last prospect that was run on the server. Used by ResumeProspect"
    "$ServerSettings|/Script/Icarus.DedicatedServerSettings|LoadProspect|${LoadProspect}|Prospect name to load on startup"
    "$ServerSettings|/Script/Icarus.DedicatedServerSettings|CreateProspect|${CreateProspect}|Create and launch a prospect on start up"
    "$ServerSettings|/Script/Icarus.DedicatedServerSettings|ShutdownIfNotJoinedFor|${ShutdownIfNotJoinedFor}|When the server starts up, if no players join within this time, the server will shutdown and return to lobby."
    "$ServerSettings|/Script/Icarus.DedicatedServerSettings|ShutdownIfEmptyFor|${ShutdownIfEmptyFor}|When the server becomes empty the server will shutdown and return to lobby after this time (in seconds)."
    "$ServerSettings|/Script/Icarus.DedicatedServerSettings|AllowNonAdminsToLaunchProspects|${AllowNonAdminsToLaunchProspects}|If true, automatically resume the last prospect on startup"
    "$ServerSettings|/Script/Icarus.DedicatedServerSettings|AllowNonAdminsToDeleteProspects|${AllowNonAdminsToDeleteProspects}|If true, automatically resume the last prospect on startup"
    "$ServerSettings|/Script/Icarus.DedicatedServerSettings|FiberFoliageRespawn|${FiberFoliageRespawn}|If true, (open world only) fibrous plants respawn during load"
    "$ServerSettings|/Script/Icarus.DedicatedServerSettings|LargeStonesRespawn|${LargeStonesRespawn}|If true, (open world only) large stones respawn during load"
    "$ServerSettings|/Script/Icarus.DedicatedServerSettings|GameSaveFrequency|${GameSaveFrequency}|After this time the game will automatically saved (in minutes)"
    "$ServerSettings|/Script/Icarus.DedicatedServerSettings|LastProspectName|${LastProspectName}|The name of the last prospect session"
    "$Engine|OnlineSubsystemSteam|AsyncTaskTimeout|${ASYNCTASKTIMEOUT:=60}|Give slow systems and connections more time to connect"
  )
}

update_ini_settings() {
  if [ "$DEBUG" = "1" ]; then
  set -x
  fi

  local file="$1"
  local section="$2"
  local key="$3"
  local value="$4"
  local comment="$5"

  echo "$(basename ${file})  [$section]$key  $value  # $comment"

  # Ensure the target directory exists
  mkdir -p $(dirname "$file")

  # Ensure the configuration file exists
  if [ ! -f "$file" ]; then
      # echo "File '$file' does not exist. Creating it."
      touch "$file"
  fi

  # Check if the section header exists in the file
  if ! grep -qE "^\\[[[:space:]]*$section[[:space:]]*\\]" "$file"; then
      printf "\n[%s]\n" "$section" >> "$file"
  fi

  # Escape forward slashes in the section name for safe use in sed address ranges
  local escaped_section="${section//\//\\/}"

  # Check if the key already exists within that specific section
  if sed -n "/^\\[[[:space:]]*$escaped_section[[:space:]]*\\]/,/^\\[/p" "$file" | grep -qE "^[[:space:]]*$key[[:space:]]*="; then
      sed -i "/^\\[[[:space:]]*$escaped_section[[:space:]]*\\]/,/^\\[/ { /^[[:space:]]*$key[[:space:]]*=/ s|=.*|=$value| }" "$file"
  else
      sed -i "/^\\[[[:space:]]*$escaped_section[[:space:]]*\\]/a $key=$value" "$file"
  fi
}

apply_configurations() {
  if [ "$DEBUG" = "1" ]; then
    set -x
  fi

  for entry in "${CONFIG_ITEMS[@]}"; do
      IFS='|' read -r file section key value comment <<< "$entry"
      update_ini_settings "$file" "$section" "$key" "$value" "$comment"
  done

  # Ensure prospect dir exists for easy backup restore
  mkdir -p /home/steam/server/Icarus/Saved/PlayerData/DedicatedServer/Prospects
}

validate_environment() {
  if [ "$DEBUG" = "1" ]; then
    set -x
  fi

  if [ -z "${APP_ID}" ]; then
    echo "ERROR: APP_ID is not set." >&2
    exit 1
  fi
}

init_steamcmd() {
    if [ "$DEBUG" = "1" ]; then
      set -x
    fi

    if [ ! -f "/home/steam/Steam/steamcmd.sh" ]; then
        curl -sSL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar -xz -C /home/steam/Steam
    fi
}

run_steamcmd() {
  if [ "$DEBUG" = "1" ]; then
    set -x
  fi

  local steam_args=(
    +@sSteamCmdForcePlatformType windows
    +force_install_dir "/home/steam/server"
    +login anonymous
    +app_update "${APP_ID}"
  )

  if [ -n "$BETA_BRANCH" ]; then
    steam_args+=("-beta" "${BETA_BRANCH}")
  fi

  steam_args+=("validate")

  pushd /home/steam/Steam
    local attempt=1
    local max_attempts=3

    # Temporarily disable exit-on-error so the loop can catch and handle non-zero exit codes gracefully
    set +e
    while [ $attempt -le $max_attempts ]; do
      echo "Running SteamCMD for App ID ${APP_ID} (Attempt $attempt/$max_attempts)..."
      ./steamcmd.sh "${steam_args[@]}" +quit
      local exit_code=$?

      if [ $exit_code -eq 0 ]; then
        echo "SteamCMD installation/update completed successfully."
        set -e
        popd
        return 0
      else
        echo "WARNING: SteamCMD failed with exit code $exit_code. Retrying..."
        sleep 1
        ((attempt++))
      fi
    done
    set -e

    echo "ERROR: SteamCMD failed to install App ID ${APP_ID} after $max_attempts attempts."
    popd
    exit 1
}

start_server() {
  echo "--> Starting Icarus Dedicated Server..."

  exec wine Icarus/Binaries/Win64/IcarusServer-Win64-Shipping.exe \
    -LOG \
    -SteamServerName="${SESSIONNAME}" \
    -PORT="${PORT}" \
    -QueryPort="${QUERYPORT}" \
    -MaxSearchResults="4000"
}

main() {
  if [ "$DEBUG" = "1" ]; then
    set -x
  fi

  load_config_defaults
  apply_configurations
  validate_environment
  init_steamcmd
  run_steamcmd
  start_server

  # keep the container alive if we are debugging
  if [ "$DEBUG" = "1" ] && [ "$#" -gt 0 ]; then
    exec "$@"
  fi
}

main "$@"