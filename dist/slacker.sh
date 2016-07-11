#!/bin/bash
#set -x TODO
#exec 3>&1 4>&2                # Save original FDs
#trap 'exec 2>&4 1>&3' 0 1 2 3 # Restore FDs for some signals
#exec 1>"/slacker.log" 2>&1    # Redirect normal output to log

# Script-wide non-configurables (needed before `config` is called)
declare -gx NC="\033[0m"
declare -gx RED="\033[0;31m"
declare -gx GREY="\033[90m"
declare -gx CYAN="\033[36m"

declare -gx READPROMPT="> "
declare -gx LOGFILE="/slacker.log"
declare -gx DEBUGMODE=false

[ "$DEBUGMODE" == true ] && set -x

exec > >(tee -a "${LOGFILE}" )
exec 2> >(tee -a "${LOGFILE}" >&2)

################### functions/fifo/config.sh ###################
#!/bin/bash

config()
{
    declare_vars
    prompt_settings
    
    # config partitions
    BOOT_PART="$DRIVE"1
    ENCR_PART="$DRIVE"2
    if [ "$ENCRYPT" == true ]
    then
        DECR_PART="/dev/mapper/$DECR_MAPPER"
    else
        DECR_PART="$ENCR_PART"
    fi
}

# Also sets defaults
declare_vars()
{
    ### NON-CONFIGURABLE ###
    declare -gx SLACK_VERS="14.2" # Be sure to update sbopkg release url when changing this
    declare -gx SLACK_MIRROR="ftp://mirrors1.kernel.org/slackware/slackware64-$SLACK_VERS/"
    declare -gx CHROOT_DIR="/mnt/root" # Where root will be mounted in live environment
    declare -gx EXTRA_PKGS_OFFICIAL="sudo Thunar mozilla-firefox ntp kbd"
    declare -gx EXTRA_PKGS_SBO="i3 i3status feh autocutsel lxappearance rxvt-unicode"

    declare -gx LVM_NAME_VG=vg00
    declare -gx LVM_NAME_ROOT=root
    declare -gx LVM_NAME_SWAP=swap
    declare -gx DECR_ROOT="/dev/$LVM_NAME_VG/$LVM_NAME_ROOT"
    declare -gx DECR_SWAP="/dev/$LVM_NAME_VG/$LVM_NAME_SWAP"

    ### BASED ON CONFIGURABLES ###
    declare -gx BOOT_PART
    declare -gx ENCR_PART
    declare -gx DECR_MAPPER=decrpv
    declare -gx DECR_PART # Encrypted ? /dev/mapper/$DECR_MAPPER : $ENCR_PART

    
    ### CONFIGURABLES ###
    
    declare -gx DRIVE='/dev/sda'            # Default drive to install to.
    declare -gx HOSTNAME='slack'            # Default hostname of the installed machine.
    declare -gx ENCRYPT=true                # Encrypt everything (except /boot).
    declare -gx USER_NAME='user'            # Default user to create (by default, added to wheel group, and others).
    declare -gx TIMEZONE='America/Winnipeg' # Default system timezone.
    declare -gx EXTENDED_CONFIG=false       # Prompt user for extended settings.
    declare -gx PKG_DIR
    declare -gx WIRELESS_DEVICE=$(get_wireless_device)
    declare -gx WIRED_DEVICE=$(get_wired_device)
    declare -gx DECR_PASS
    declare -gx USER_PASS
    declare -gx ROOT_PASS
    # Extended
    declare -gx ATTEMPTS_TILL_HINT=2
    declare -gx TMP_ON_TMPFS=true
    declare -gx KEYMAP='us'
    declare -gx AUR_PKG_MANAGER="packer"
    declare -gx TEST_INSTALL=false
    # Encryption
    declare -gx DECRYPT_HINT=true
    declare -gx DECRYPT_HINT_CONTACT='sam@shelt.ca'
    # Dotfiles
    declare -gx DOTFILES=true
    declare -gx DOTFILES_URL='https://www.bitbucket.com/shelt/dots'
    declare -gx DOTFILES_EXEC="sudo python2 clone.py -u $USER_NAME"
    # Keyring
    declare -gx KEYRING=true
    declare -gx KEYRING_DIR
    
    declare -gx SETTINGS_COMPLETE=false
}

prompt_settings()
{
    tell "## Configuration ##"
    read_dflt "Drive to install to" DRIVE
    read_dflt "Hostname" HOSTNAME
    read_dflt "Encrypt drive? true/false" ENCRYPT
    [ "$ENCRYPT" == true ] && read_pass "Encryption password" DECR_PASS
    read_dflt "User name" USER_NAME
    read_pass "User password" USER_PASS
    read_pass "Root password" ROOT_PASS
    [ -z "$WIRED_DEVICE" ] && read_init "Wired device (autodetect failed)" WIRED_DEVICE          #TODO make not mandatory
    [ -z "$WIRELESS_DEVICE" ] && read_init "Wireless device (autodetect failed)" WIRELESS_DEVICE #TODO make not mandatory
    read_init "Slackware package directory" PKG_DIR
    
    read_dflt "Extended configuration? true/false" EXTENDED_CONFIG
    if [ "$EXTENDED_CONFIG" == true ]; then
        tell "## Extended Configuration ##"
        if [ "$ENCRYPT_DRIVE" == true ]; then
            tell "# Decryption #"
            
            read_dflt "Decryption hint? true/false" DECRYPT_HINT
            if [ "$DECRYPT_HINT" == true ]; then
                read_dflt "Decryption hint contact email" DECRYPT_HINT_CONTACT
                read_dflt "Failed attempts before hint" ATTEMPTS_TILL_HINT #TODO only a madman would ever modify this
            fi
        fi
        
        tell "# Dotfiles #"
        read_dflt "Clone dotfiles repository?" DOTFILES
        if [ "$DOTFILES" == true ]; then
            read_dflt "Repository Git URL" DOTFILES_URL
            read_dflt "Command to execute in repo" DOTFILES_EXEC
        fi

        tell "# Keyring #"
        read_dflt "Clone keyring (gnupg) directory?" KEYRING
        if [ "$KEYRING" == true ]; then
            read_init "Keyring directory" KEYRING_DIR
        fi
        
        tell "# General #"
        read_dflt "Timezone" TIMEZONE
        read_dflt "Enable /tmp on a tmpfs? true/false (good only for low-ram systems)" TMP_ON_TMPFS
        read_dflt "Test install (No packages)" TEST_INSTALL
        
        tell "Extended configuration completed."
    fi

    SETTINGS_COMPLETE=true
    tell "Configuration completed."
}

### UTIL ###
read_init()
{
    # TODO this function always invokes readline! Problem?
    local prompt="$1"
    local dest="$2"
    unset "$dest"
    
    until [ -n "${!dest}" ]; do
        tell "${prompt}: "
        read -re -p "$READPROMPT" "$dest"
    done
    declare -gx "$dest"
}

read_dflt()
{
    local prompt="$1"
    local dest="$2"
    local temp
    
    tell "$prompt" "(default ${!dest}): "
    read -r -p "$READPROMPT" temp
    declare -gx "$dest"="${temp:-${!dest}}"
}

read_pass()
{
    local prompt="$1"
    local dest="$2"
    local conf
    while [[ -z "${!dest}" ]] || [[ -z "$conf" ]] || [ "${!dest}" != "$conf" ]; do
        tell "$prompt: "
        read -rs -p "$READPROMPT" "$dest" && printf "\n"
        tell "Verify: "
        read -rs -p "$READPROMPT" conf && printf "\n"
    done
    declare -gx "$dest"
}

get_wired_device()
{
    line="$(ip link | egrep -o "(eth|en|eno)[0-9]+:")"
    echo ${line%?}
}

get_wireless_device()
{
    line="$(ip link | egrep -o "wlan[0-9]+:")"
    echo ${line%?}
}

################### functions/fifo/fs.sh ###################
#!/bin/bash


# Also mounts physical partition
partition()
{
    parted -s "$DRIVE" \
        mklabel msdos \
        mkpart primary ext2 1 1G \
        mkpart primary ext2 1G 100% \
        set 1 boot on \
        set 2 LVM on
}

format_crypt()
{
    echo -en "$DECR_PASS" | cryptsetup --cipher aes-xts-plain64 --key-size 512 --hash sha512 --iter-time 5000 --use-random luksFormat "$ENCR_PART"
    
}

open_crypt()
{
    echo -en "$DECR_PASS" | cryptsetup luksOpen "$ENCR_PART" "$DECR_MAPPER"
}
close_crypt()
{
    vgchange -an "$LVM_NAME_VG"
    cryptsetup luksClose "$DECR_MAPPER"
}

create_lvm()
{
    pvcreate "$DECR_PART"
    vgcreate "$LVM_NAME_VG" "$DECR_PART"
    lvcreate -C y -L1G "$LVM_NAME_VG" -n "$LVM_NAME_SWAP"      # 1GB swap partition
    lvcreate -l '+100%FREE' "$LVM_NAME_VG" -n "$LVM_NAME_ROOT" # rest of the space for root
#    vgchange -ay                                               # Enable volumes #TODO, not needed
}

format_plaintext()
{
    mkfs.ext2 -q -F -L boot "$BOOT_PART"
    mkfs.ext4 -q -F -L root "$DECR_ROOT"
    mkswap "$DECR_SWAP"
}

mount_plaintext()
{
    # Enable volumes
    vgchange -ay "$LVM_NAME_VG"
    # Mount root
    mkdir -p "$CHROOT_DIR"
    mount "$DECR_ROOT" "$CHROOT_DIR"
    # Mount boot
    mkdir -p "$CHROOT_DIR/boot"
    mount "$BOOT_PART" "$CHROOT_DIR/boot"
    # Mount swap
    swapon "$DECR_SWAP"
    
    # Mount packages
    mkdir -p "$CHROOT_DIR/$PKG_DIR" # TODO allow for network install, these would be not needed
    mount -t none -o bind "$PKG_DIR" "$CHROOT_DIR/$PKG_DIR"
    
    mkdir -p "$CHROOT_DIR/proc" "$CHROOT_DIR/dev" "$CHROOT_DIR/sys"
    mount -t proc proc "$CHROOT_DIR/proc" || fatal "Failed to mount proc in $CHROOT_DIR"
    mount -t sysfs sys "$CHROOT_DIR/sys" || fatal "Failed to mount sys in $CHROOT_DIR"
    mount --rbind /dev "$CHROOT_DIR/dev/" || fatal "Failed to mount dev in $CHROOT_DIR"
}

umount_plaintext()
{
    umount -t proc "$CHROOT_DIR/proc"
    umount -t sysfs "$CHROOT_DIR/sys"
    umount -R "$CHROOT_DIR/dev"
    umount "$CHROOT_DIR/$PKG_DIR"
    swapoff "$DECR_SWAP"
    umount "$BOOT_PART"
    umount "$DECR_ROOT"
    vgchange -an "$LVM_NAME_VG"
}

################### functions/fifo/main.sh ###################
#!/bin/bash

install_fifo()
{
    step partition
    step format_crypt
    step open_crypt
    step create_lvm
    step format_plaintext
    step mount_plaintext
    which installpkg || step install_installer
    step install_base
    step do_chroot
    step umount_plaintext
    step close_crypt
}

install_installer()
{
    which du >/dev/null && [ ! -f /bin/du ] && ln -s "$(which du)" /bin/du # Suppress warnings
    local tmproot="/tmp/installer_root"
    mkdir -p "$tmproot"
    xz -q -d < "$(pkg_to_fname pkgtools)" | tar xf - -C /
}

install_base()
{
    local tagfiles="$(find "$PKG_DIR" -type f | grep 'tagfile$')"
    local BASE
    # All required packages (TODO might not be needed, adds undesirables like emacs and kde)
    BASE=" $(egrep ':ADD$' $tagfiles | cut -f2 -d:)"
    # Use generic kernel
    BASE=" $(echo "$BASE" | sed '/kernel-huge/c\kernel-generic')"
    # Full install sets
    BASE+=" $(egrep ':(ADD|REC|OPT)$' $PKG_DIR/{a,ap,d,l,n,x,y}/tagfile | cut -f2 -d:)"
    # Recommended install sets
    BASE+=" $(egrep ':REC$' $PKG_DIR/{f,xap}/tagfile | cut -f2 -d:)"
    # Remove duplicates
    BASE="$(echo $BASE | xargs -n1 | sort -u | xargs)" 
    
    local BASE_FNAMES="$(pkg_to_fname $BASE)"
    [ -n "$BASE_FNAMES" ] || fatal "Failed to generate base installation package list"
    installpkg --root "$CHROOT_DIR" $BASE_FNAMES >/dev/null
    
    mkdir  -p "/tmp"
    wget –q --no-check-certificate "https://github.com/sbopkg/sbopkg/releases/download/0.38.0/sbopkg-0.38.0-noarch-1_wsr.tgz" -O "/tmp/sbopkg.tgz" >/dev/null # todo redirect probably unneccesary
    installpkg --root "$CHROOT_DIR" "/tmp/sbopkg.tgz" >/dev/null
    
}

do_chroot()
{
    cp "/slacker.log" "$CHROOT_DIR/slacker.fifo.log"
    cp "$0" "$CHROOT_DIR/$(basename "$0")"
    chroot "$CHROOT_DIR" "./$(basename "$0")" chroot
    rm "$CHROOT_DIR/$(basename "$0")"
}

pkg_to_fname()
{
    for curr in $@; do
        find "$PKG_DIR" -type f | egrep '/.*\.(txz|tgz)$' | fgrep "/$curr-"
        [ $? -eq 1 ] && error "Failed to locate tarball for package $curr"
    done
}


################### functions/lilo/main.sh ###################
#!/bin/bash

install_lilo()
{
    step install_official_extras
    step install_slackbuild_extras
    step create_user
    step set_hostname
    step set_timezone
    #step set_locale
    #step set_keymap
    step set_hosts
    step set_fstab
    step set_initfs
    step set_init
    step set_bootloader
    step set_sudoers
    step set_net
    step set_root
    step gen_ssh

    [ "$DOTFILES" == true ] && step clone_dotfiles
    [ "$KEYRING" == true ]  && step clone_keyring #TODO should only be for non-root user; root user keyring is used for pkg managers

    tell "Chroot complete!"
}

#TODO it doesn't make sense why `slackpkg` output is going to stderr
install_official_extras()
{
    echo "$SLACK_MIRROR" > "/etc/slackpkg/mirrors"
    slackpkg update gpg &>/dev/null
    slackpkg update &>/dev/null
    slackpkg -batch=on -default_answer=y install "$EXTRA_PKGS_OFFICIAL" &>/dev/null #TODO redirect to /dev/null doesn't work
}

install_slackbuild_extras()
{
    echo "c" | sbopkg -r >/dev/null
    ln -s /usr/doc/sbopkg*/contrib/sqg /usr/sbin/sqg
    egrep "REPO_BRANCH.*$SLACK_VERS" "/usr/sbin/sqg" >/dev/null || error "sqg appears to use wrong default slackware version. Please change the script's release of sbopkg at once!"
    (export REPO_BRANCH="$SLACK_VERS" ; sqg -a >/dev/null)
    yes q | sbopkg -Bk -e continue -i "$EXTRA_PKGS_SBO" >/dev/null
}

create_user()
{
    id -u "$USER_NAME" &>/dev/null || useradd -m -s /bin/bash -G \
        wheel,users,audio,video,cdrom,plugdev,lp,uucp,scanner,power "$USER_NAME"
    echo "$USER_NAME:$USER_PASS" | chpasswd
}

set_hostname()
{
    echo "$HOSTNAME" > /etc/hostname
}

set_timezone()
{
    #timeconfig $TIMEZONE
    cp /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
}

set_hosts()
{
    cat > /etc/hosts <<EOF
127.0.0.1 localhost.localdomain localhost $HOSTNAME
::1       localhost.localdomain localhost $HOSTNAME
EOF
}

set_fstab()
{
    local boot_uuid=$(get_uuid "$BOOT_PART")
    
    if [ "$TMP_ON_TMPFS" == true ]
    then
        local tmpfs="tmpfs   /tmp         tmpfs   nodev,nosuid,size=2G          0  0"
    fi

    cat > /etc/fstab <<EOF
#
# /etc/fstab: static file system information
#
# <file system> <dir>    <type> <options>    <dump> <pass>

$DECR_SWAP none swap  sw                0 0
$DECR_ROOT /    ext4  defaults,relatime 0 1
$tmpfs
UUID=$boot_uuid /boot ext2 defaults,relatime 0 2
EOF
}
# TODO: cryptdevice=/dev/disk/by-uuid/$(get_uuid "$ENCR_PART"):$LVM_NAME_VG
set_initfs()
{
    mkinitrd -c -f ext4 -k "$(get_kernel_version)" -m ext4 -r "$DECR_ROOT" -C "$ENCR_PART" -L
}

# Changes from default: 
#   * Autologin on tty1
set_init()
{
    cat > /etc/inittab <<EOF
#
# inittab	This file describes how the INIT process should set up
#		the system in a certain run-level.
#
# Version:	@(#)inittab		2.04	17/05/93	MvS
#                                       2.10    02/10/95        PV
#                                       3.00    02/06/1999      PV
#                                       4.00    04/10/2002      PV
#                                      13.37    2011-03-25      PJV
#
# Author:	Miquel van Smoorenburg, <miquels@drinkel.nl.mugnet.org>
# Modified by:	Patrick J. Volkerding, <volkerdi@slackware.com>
#

# These are the default runlevels in Slackware:
#   0 = halt
#   1 = single user mode
#   2 = unused (but configured the same as runlevel 3)
#   3 = multiuser mode (default Slackware runlevel)
#   4 = X11 with KDM/GDM/XDM (session managers)
#   5 = unused (but configured the same as runlevel 3)
#   6 = reboot

# Default runlevel. (Do not set to 0 or 6)
id:3:initdefault:

# System initialization (runs when system boots).
si:S:sysinit:/etc/rc.d/rc.S

# Script to run when going single user (runlevel 1).
su:1S:wait:/etc/rc.d/rc.K

# Script to run when going multi user.
rc:2345:wait:/etc/rc.d/rc.M

# What to do at the "Three Finger Salute".
ca::ctrlaltdel:/sbin/shutdown -t5 -r now

# Runlevel 0 halts the system.
l0:0:wait:/etc/rc.d/rc.0

# Runlevel 6 reboots the system.
l6:6:wait:/etc/rc.d/rc.6

# What to do when power fails.
pf::powerfail:/sbin/genpowerfail start

# If power is back, cancel the running shutdown.
pg::powerokwait:/sbin/genpowerfail stop

# These are the standard console login getties in multiuser mode:
c1:12345:respawn:/sbin/agetty --autologin $USER_NAME --noclear 38400 tty1 linux
c2:12345:respawn:/sbin/agetty 38400 tty2 linux
c3:12345:respawn:/sbin/agetty 38400 tty3 linux
c4:12345:respawn:/sbin/agetty 38400 tty4 linux
c5:12345:respawn:/sbin/agetty 38400 tty5 linux
c6:12345:respawn:/sbin/agetty 38400 tty6 linux

# Local serial lines:
#s1:12345:respawn:/sbin/agetty -L ttyS0 9600 vt100
#s2:12345:respawn:/sbin/agetty -L ttyS1 9600 vt100

# Dialup lines:
#d1:12345:respawn:/sbin/agetty -mt60 38400,19200,9600,2400,1200 ttyS0 vt100
#d2:12345:respawn:/sbin/agetty -mt60 38400,19200,9600,2400,1200 ttyS1 vt100

# Runlevel 4 also starts /etc/rc.d/rc.4 to run a display manager for X.
# Display managers are preferred in this order:  gdm, kdm, xdm
x1:4:respawn:/etc/rc.d/rc.4

# End of /etc/inittab
EOF
}

set_bootloader()
{
    cat > /etc/lilo.conf <<EOF
boot=$DRIVE
map=/boot/map
install=/boot/boot.b
compact
image=/boot/$(get_kernel_filename)
    initrd=/boot/initrd.gz
    root=$DECR_ROOT
    label=linux
    read-only
EOF
    lilo
}

set_sudoers()
{
    cat > /etc/sudoers <<EOF
root ALL=(ALL) ALL
%wheel ALL=(ALL) ALL
EOF
    chmod 440 /etc/sudoers
}

set_net()
{
    : #TODO
}

set_root()
{
    echo "root:$ROOT_PASS" | chpasswd
}

gen_ssh()
{
    # Note: sshd_config, ssh_config and moduli are expected
    # to be added during dotfiles repo clone.
    mkdir -p /etc/ssh
    rm -rf /etc/ssh/*
    
    # Generate host keys
    ssh-keygen -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key >/dev/null
    ssh-keygen -t rsa -b 4096 -N "" -f /etc/ssh/ssh_host_rsa_key >/dev/null

    # Generate auth keys
    ssh-keygen -t ed25519 -N "" -o -a 100 -f /etc/ssh/ssh_auth_ed25519_key >/dev/null
    ssh-keygen -t rsa -b 4096 -N "" -o -a 100 -f /etc/ssh/ssh_auth_rsa_key >/dev/null

    # Modify permissions
    chown root /etc/ssh/*
    chmod 700 /etc/ssh
    chmod 600 /etc/ssh/ssh_host_ed25519_key
    chmod 600 /etc/ssh/ssh_host_rsa_key
    chmod 600 /etc/ssh/ssh_auth_ed25519_key.pub
    chmod 600 /etc/ssh/ssh_auth_rsa_key.pub
}

clone_dotfiles()
{
    mkdir -p /home/"$USER_NAME"/git
    git clone $DOTFILES_URL /home/"$USER_NAME"/git/dots
    ( cd /home/"$USER_NAME"/git/dots && $DOTFILES_EXEC )
}

### UTILITIES ###

get_kernel_filename()
{
    kernels=$(find /boot -type f -name 'vmlinuz-generic-*')
    [ -z "$kernels" ] && error "get_kernel_filename: Failed to find versioned kernel in boot partition."
    echo "${kernels[0]}" | xargs basename
}

get_kernel_version()
{
    get_kernel_filename | sed "s/^vmlinuz-generic-//"
    #echo "${fname#$"vmlinuz-generic-"}"
}


get_uuid()
{
    blkid -s UUID "$1" | awk '{print $2}' | sed 's/"//g' | sed 's/^.*=//'
}


################### functions/util.sh ###################
#!/bin/bash

check_internet()
{
    mkdir -p "/etc"
    getent hosts google.com >/dev/null || echo "nameserver 8.8.8.8" >/etc/resolv.conf
    ping 8.8.8.8 -c 2 >/dev/null && return
    which dhcpcd && dhcpcd "$WIRED_DEVICE" && return
    which dhclient && dhclient "$WIRED_DEVICE"
    ping 8.8.8.8 -c 2 >/dev/null || fatal "Failed to establish an internet connection"
}


#TODO unused
global()
{
    IFS='=' read var val <<< "$1"
    [ -z "${var+x}" ]           && fatal "undeclared variable declared as global: $1"
    bash -c '[ -z ${var+x} ]' && fatal "nonexported variable declared as global"
    declare -gx "$1"
}

# Accepts a function (opt. parameters) which executes as a step
# in the install process.
step()
{
    local cmd=$1; shift
    tell "${CYAN}Doing $cmd${NC}"
    "$cmd" "$@"
    
}

### PRINTING ###
tell()
{
    echo -e "slacker: $@" #>&3 TODO
}

error()
{
    local msg="$1"
    echo -e "slacker: ${RED}$msg${NC}" #>&4 TODO
}

fatal()
{
    echo "slacker: FATAL :(" #>&4 TODO
    error "$@"
    exit
}


################### MAIN ###################
#!/bin/bash

[ "$SETTINGS_COMPLETE" == true ] || step config
step check_internet

if [ "$1" == "chroot" ]; then
    step install_lilo
elif [ "$1" == "step" ]; then
    [ "$SETTINGS_COMPLETE" == true ] || config
    shift
    step $@
else
    step install_fifo
fi
