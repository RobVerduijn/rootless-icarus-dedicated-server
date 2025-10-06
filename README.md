# Rootless Icarus Dedicated Server

- [Rootless Icarus Dedicated Server](#rootless-icarus-dedicated-server)
  - [Preamble](#preamble)
  - [Build Requires](#build-requires)
    - [READ UP ON PODMAN](#read-up-on-podman)
  - [Build Container](#build-container)
  - [Container requirements](#container-requirements)
    - [Create a regular user](#create-a-regular-user)
    - [Created persistend storage folders](#created-persistend-storage-folders)
    - [Podman unshare](#podman-unshare)
  - [Manual container stopping and starting](#manual-container-stopping-and-starting)
    - [Starting with podman compose](#starting-with-podman-compose)
    - [Stopping with podman compose](#stopping-with-podman-compose)
  - [Automatic container stopping and starting](#automatic-container-stopping-and-starting)
    - [Add unit file](#add-unit-file)
    - [Update the systemd unit files](#update-the-systemd-unit-files)
    - [Enable the unit file](#enable-the-unit-file)
  - [Enable linger](#enable-linger)
    - [Disable linger](#disable-linger)
    - [Manual start the container](#manual-start-the-container)
  - [Check the container logs](#check-the-container-logs)
    - [Icarus Logs](#icarus-logs)
  - [Commands you might also use](#commands-you-might-also-use)
    - [Stopping the container](#stopping-the-container)
    - [Security hardened user option](#security-hardened-user-option)
  - [Backing up your prospect(s)](#backing-up-your-prospects)
  - [Restoring](#restoring)
  - [Container Environment Variables](#container-environment-variables)
    - [Container Options](#container-options)
    - [Icarus Dedicated Server Options](#icarus-dedicated-server-options)

## Preamble

Because I hate running containers as root I created a rootless configuration.
I was inspired on running steamcmd windows servers by the build of nerondon

## Build Requires

- podman latest

### READ UP ON PODMAN

For podman installation and usage visit <https://podman.io/docs>  
For rootless containers you must ensure that subgid en subuid is configured.
For details on subuid and subgid visit <https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md>

## Build Container

We need ```--cap-add``` to build the container as a regular user, the running container will not need any additional caps.  
Also required is ```--device /dev/fuse``` when building as a regular user.  
To minimize the image size I add ```--squash-all``` to remove all the layers.  
On fedora ```--security-opt=label=type:container_runtime_t``` is also required to allow building.  

As a regular user, to build issue the following command:

```shell
podman build -t example.registry.com:9999/library/icarus-dedicated-server:latest -f Dockerfile --cap-add=all --security-opt=label=type:container_runtime_t --device /dev/fuse --squash-all
```

## Container requirements

Enough space in the home directory of the user running the pod

### Create a regular user

On your linux system as root create a regular user.  
The userid (UID) and the groupid (GID) are not important as we run a rootless container.  
Make sure the subuid and subgid are configured for this user for details visit <https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md>

This tutorial will assume you are using fedora linux and the user will be called steam with a regular home and set a password on it

> I choose to name the user **on the container-host** steam, this is a random name that just happens to be the same as the user **in the container**.
Podman will assign an unique uid/gid when it starts the container and will try to do it's best to avoid conflicts with any uid specyfied in the /etc/passwd and /etc groups **of the container host**.
So you might as well call it qwerty, just make sure you issue all the commands as the user qwerty after that.

```bash
useradd -m steam
passwd steam
```

### Created persistend storage folders

Since the container is ephemeral (ie all the savegame and server data in it will be gone when it shuts down) you must create persistent storage to be used as a savegame location and server data location.  
The simplest way to do this is by creating 2 directories and mounting these as a volume in the container.

As the steam user create 2 directories, one for the server and one for savegames.

```bash
mkdir /path/to/steam /path/to/game
```

These will be mounted as volumes when the container is started

### Podman unshare

Because rootless containers run in a different namespace the user in the container has no access to the host filesystem.
To enable access we must change the owner of the folders using 'podman unshare chown'.
That way the subuid/subgid will be made the owner of those folders.  
To ensure the subuid/subgid matches the mapping to the uid/gid in the container this must be done using the user account on the container host

Here the UID and the GID ***MUST*** match the UID and GID used in the container.  
I used UID 1001 and GID 1001 in the Dockerfile to create the container so I use them here as well.  

```bash
podman unshare chown -R 1001:1001 /path/to/game
podman unshare chown -R 1001:1001 /path/to/steam
```

The uid/gid of the directories and subdirectories (if any) will now be changed to a random number from the subuid/subgid range.
The user in the container is now owner of those directories and can read and write to them, the user on the host can now only read them.

>Use the root account on the server host to edit or remove those directories. (or change the owner again)  
>When you manipulate the foldes make sure you:  
>
>- first as root recursivly change the owner back to the regular user  
>- then as the regular user unshare them again with the above commands

## Manual container stopping and starting

### Starting with podman compose

The best way to start the container is by using compose.
That way the configuration is always the same and easy to check/debug.

To start issue the following command as the user on the container host.
To ensure the command runs in the background I add the option ```-d```.

```bash
podman compose -f /path/to/compose.ymls up -d
```

### Stopping with podman compose

As the steam user run the following command to stop the server.

```bash
podman compose -f /path/to/compose.ymls down
```

## Automatic container stopping and starting

This requires the following steps.

- [Add unit file to the steam user home dir](#add-unit-file)
- [Update systemd unit files as user](#update-the-systemd-unit-files)
- [Enable unit file as the user](#enable-the-unit-file)
- [Enable linger for the user](#enable-linger)
- [Start unit file as the steam user](#manual-start-the-container)

### Add unit file

Systemd needs a unit file to autostart a container.  
The unit file for a container is called a quadlet, it has a lot of similarities with a docker-compose file.  
For a regular user it needs to be located in the home directory of the user in the ```.config/container/systemd``` directory.  
I've added a quadlet unit file that can be used for this: **icarus.container**

```bash
mkdir -p $HOME/.config/container/systemd
cp icarus.container $HOME/.config/container/systemd
```

>Make sure there is a game and steam folder in the user home dir

### Update the systemd unit files

Systemd needs to be made aware of the new unit files.
This can be done by issueing the following command as the steam user.

```bash
systemctl --user daemon-reload
```

### Enable the unit file

The container will be enabled automatically for the user by the ```systemctl --user daemon-reload``` command.
This section is here to make it clear that it's not longer needed to do this for container unit files for rootless containers.

## Enable linger

To allow the container to run even when not logged in you must enable linger for the regular user account.  
If you do not enable linger the container will be shut down as soon as you log out.  
When linger is enabled for the user it will also ensure that all the containers who are specified in quadlet/unit files will be started on boot.  
As root issue the following command:

```shell
loginctl enable-linger steam
```

After issueing this command systemd will automatically start the container after a reboot if the unit file is in the ~/.config/container/systemd directory.

### Disable linger

If you need to disable linger issue the following command as root.

```shell
loginctl disable-linger steam
```

### Manual start the container

As the steam user

```bash
systemctl --user start icarus.container
```

## Check the container logs

To read the logs of the container is the following command as the user:

```bash
podman logs -f icarus-dedicated-server
```

The ```-f``` causes the command to 'tail' the logs, use ctrl-c to stop tailing the logs.

### Icarus Logs

To read all the ingame logs issue the following command as the regular user:

```bash
tail -f $HOME/game/drive_c/icarus/Saved/Logs/Icarus.log
```

This command assumes you have the $HOME/game on the container host mounted in the container on /home/steam/game.

## Commands you might also use

Some more commands that you might wish to use but that are no needed to get the container automatically started.

### Stopping the container

As steam user stop the container

```bash
systemctl --user stop icarus.container
```

### Security hardened user option

This is optional!!  
You could make the steam user more secure if you do the following,
but this makes using the account a bit more difficult

Modify the user to use the nologin shell
On the container host as root (replace steam with the regular user name you used)

```bash
usermod -s /sbin/nologin steam
```

To undo this:

```bash
usermod -s /bin/bash steam
```

Do not set a password on the account when you create the user.
If you did set a password you can remove it by issuing the following command.

```bash
passwd --delete steam
```

And you can set the password back again with:

```bash
passwd steam
```

If you wish to access the account to modify the unit file. (which requires a login shell)
Using another regular account on the container host that has sudo privileges.  

```bash
sudo su --shell=/bin/bash - steam
export XDG_RUNTIME_DIR="/run/user/$UID"
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
```

Now all the systemctl and podman commands will work.

>***Do NOT add sudo privileges to the account running the container !!!!***  
Every privilege that is added to the regular user account running the container is a privilege that can potentially be exploited.
It is best to create a new account for each container so you can be sure it has no privileges that you might have forgotten.

For the regular user on the container host as root.
Remove all the shell history files, and shell configuration files.

It's best to remove all the files that are not mentioned in this README.md

Files/dirs that are needed by the container:

- .local/share/containers
- .config/containers
- game  # or whatever you set this to
- steam # or whatever you set this to

## Backing up your prospect(s)

As root on the container host (replace steam with the regular user you created):

```bash
tar -cJvf /backup_folder/prospects.tar.xz /home/steam/game/drive_c/icarus/Saved/PlayerData/DedicatedServer/Prospects
```

## Restoring

As root on the container host (replace steam with the regular user you created):

```bash
cd /
chown -R steam:steam /home/steam
tar -xvf /backup_folder/prospects.tar.xz
chown -R steam:steam /home/steam
```

As the regular user unshare the folders again:

```bash
podman unshare chown -R 1001:1001 game steam
```

## Container Environment Variables

The only option you realy need to set is the admin password.
Defaults will be applied where needed.

### Container Options

BRANCH=public
STEAM_USER=steam
STEAM_GROUP=steam
STEAM_USER_UID=1001
STEAM_USER_GID=1001
STEAM_CMD_DIR=/home/steam/Steam
STEAM_CMD=$STEAMDIR/steamcmd.sh
STEAM_CMD_URL=https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
STEAM_GAME_DIR=/home/steam/game
WINEPREFIX=$STEAM_GAME_DIR
WINEARCH=win64

### Icarus Dedicated Server Options

ADMIN_PASSWORD=""
ALLOW_NON_ADMINS_LAUNCH=""
ALLOW_NON_ADMINS_DELETE=""
CREATE_PROSPECT=""
GAMESAVEFREQUENCY=""
JOIN_PASSWORD=""
LOAD_PROSPECT=""
MAX_PLAYERS=""
SHUTDOWN_NOT_JOINED_FOR=""
SHUTDOWN_EMPTY_FOR=""
PORT=""
QUERYPORT=""
RESUME_PROSPECT=""
SAVEGAMEONEXIT=""
SERVERNAME=""
FIBERFOLIAGERESPAWN=""
LARGESTONERESPAWN=""
GAMESAVEFREQUENCY=""
SAVEGAMEONEXIT=""
