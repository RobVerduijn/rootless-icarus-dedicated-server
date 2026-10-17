#!/bin/bash
set -euo pipefail

APP_ID="2089300"
INSTALL_DIR="$HOME/$DIR_NAME"

declare -a CONFIG_ITEMS

load_config_defaults() {
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

    local ServerSettings=$INSTALL_DIR/Icarus/Saved/Config/WindowsServer/ServerSettings.ini
    local Engine=$INSTALL_DIR/Icarus/Saved/Config/WindowsServer/Engine.ini

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

init_steamcmd() {
    echo "Installing steamcmd"
    if [ ! -f "$HOME/steamcmd/steamcmd.sh" ]; then
        curl -sSL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar -xz -C "$STEAMCMD_DIR"
    fi
}

update_server() {
    echo "--> Preparing SteamCMD update..."
    local steam_args="+@sSteamCmdForcePlatformType windows +force_install_dir ${INSTALL_DIR} +login anonymous"
    local app_update_cmd="+app_update ${APP_ID}"

    if [ -n "$STEAM_BETA_BRANCH" ]; then
        echo "--> Selecting Beta Branch: ${STEAM_BETA_BRANCH}"
        app_update_cmd="${app_update_cmd} -beta ${STEAM_BETA_BRANCH}"
    fi

    app_update_cmd="${app_update_cmd} validate"

    echo "--> Running SteamCMD update..."
    "$HOME/steamcmd/steamcmd.sh" ${steam_args} "${app_update_cmd}" +quit
}

update_ini_settings() {
    local file="$1"
    local section="$2"
    local key="$3"
    local value="$4"
    local comment="$5"

    # echo "--------------------------------------------------"
    # echo "Target File    : $file"
    # echo "Target Section : [$section]"
    # echo "Target Setting : $key = $value"
    echo "$(basename ${file})  [$section]$key  $value  # $comment"
    # [ -n "$comment" ] && echo "Comment        : $comment"

    # If the path is relative, anchor it to the server base directory
    if [[ "$file" != /* ]]; then
        file="${INSTALL_DIR}/${file}"
    fi

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

    local formatted_comment=""
    [ -n "$comment" ] && formatted_comment="# $comment"

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
    for entry in "${CONFIG_ITEMS[@]}"; do
        IFS='|' read -r file section key value comment <<< "$entry"
        update_ini_settings "$file" "$section" "$key" "$value" "$comment"
    done

    # Ensure prospect dir exists for easy backup restore
    mkdir -p $INSTALL_DIR/Icarus/Saved/PlayerData/DedicatedServer/Prospects
}

start_server() {
    cd "$INSTALL_DIR"
    echo "--> Starting Icarus Dedicated Server..."

    exec wine Icarus/Binaries/Win64/IcarusServer-Win64-Shipping.exe \
    -LOG \
    -SteamServerName="${SESSIONNAME}" \
    -PORT="${PORT}" \
    -QueryPort="${QUERYPORT}"
}

main() {
    update_server
    load_config_defaults
    apply_configurations
    start_server
}

main "$@"