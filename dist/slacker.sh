#!/bin/bash

set -x
exec 3>&1 4>&2                # Save original FDs
trap 'exec 2>&4 1>&3' 0 1 2 3 # Restore FDs for some signals
exec 1>"/gentool.log" 2>&1    # Redirect normal output to log$DEL functions/fifo/config.sh ###################
#!/bin/bash

config()
{
    step declare_vars
    step set_time #TODO
    step identify_hardware
    step prompt_settings
    step config_partitions
}

# Also sets defaults
declare_vars()
{
    ### NON-CONFIGURABLE ###
    declare -gx SLACK_MIRROR="ftp://mirror.csclub.uwaterloo.ca/slackware/slackware64-14.1/slackware64/"
    declare -gx CHROOT_DIR="/mnt/root" # Where root will be mounted in live environment
    declare -gx PKG_DIR="/pkg"   # `CHROOT_` prefix means chroot-relative path #TODO should be configurable, default would be within root
    declare -gx DESIRED_PKGS="
kbd
dhcpcd
ntp
openssh
file
which
wget
"

    declare -gx LVM_NAME_VG=vg00
    declare -gx LVM_NAME_ROOT=root
    declare -gx LVM_NAME_SWAP=swap
    declare -gx DECR_ROOT="/dev/$LVM_NAME_VG/$LVM_NAME_ROOT"
    declare -gx DECR_SWAP="/dev/$LVM_NAME_VG/$LVM_NAME_SWAP"

    declare -gx NC='\033[0m'
    declare -gx RED='\033[0;31m'

    ### BASED ON CONFIGURABLES ###
    declare -gx BOOT_PART
    declare -gx ENCR_PART
    declare -gx DECR_MAPPER=decrpv
    declare -gx DECR_PART # Path to the lvm pv. Encrypted? [/dev/mapper/DECR_MAPPER]. Not encrypted? [ENCR_PART].

    
    ### CONFIGURABLES ###
    
    declare -gx DRIVE='/dev/sda'            # Default drive to install to.
    declare -gx HOSTNAME='arch'             # Default hostname of the installed machine.
    declare -gx ENCRYPT=true                # Encrypt everything (except /boot).
    declare -gx USER_NAME='user'            # Default user to create (by default, added to wheel group, and others).
    declare -gx TIMEZONE='America/Winnipeg' # Default system timezone.
    declare -gx EXTENDED_CONFIG=false       # Prompt user for extended settings.
    declare -gx WIRELESS_DEVICE
    declare -gx WIRED_DEVICE
    declare -gx VIDEO_DRIVER="i915" # For Intel #TODO autodetection
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
    declare -gx DOTFILES_EXEC='sudo python2 clone.py -u sam'
    
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
    
    read_dflt "Extended configuration? true/false" EXTENDED_CONFIG
    if [ "$EXTENDED_CONFIG" == true ]; then
        tell "## Extended Configuration ##"
        if [ "$ENCRYPT_DRIVE" == true ]; then
            tell "# Decryption #"
            
            read_dflt "Decryption hint? true/false" DECRYPT_HINT
            if [ "$DECRYPT_HINT" == true ]; then
                read_dflt "Decryption hint contact email" DECRYPT_HINT_CONTACT
                read_dflt "Failed attempts before hint" ATTEMPTS_TILL_HINT # TODO only a madman would ever modify this
            fi
        fi

        #TODO keyfiles
        
        tell "# Dotfiles #"
        read_dflt "Clone dotfiles repository?" DOTFILES
        if [ "$DOTFILES" == true ]; then
            read_dflt "Repository Git URL" DOTFILES_URL
            read_dflt "Command to execute in repo" DOTFILES_EXEC
        fi
        
        tell "# General #"
        read_dflt "Timezone" TIMEZONE
        read_dflt "Enable /tmp on a tmpfs? true/false (good only for low-ram systems" TMP_ON_TMPFS
        read_dflt "Keymap (dvorak, us, etc.)" KEYMAP
        read_dflt "Test install (No packages)" TEST_INSTALL
        
        tell "Extended configuration completed."
    fi

    SETTINGS_COMPLETE=true
    tell "Configuration completed."
}

config_partitions()
{
    global BOOT_PART="$DRIVE"1
    global ENCR_PART="$DRIVE"2
    global DECR_MAPPER
    global DECR_PART
    if [ "$ENCRYPT" == true ]
    then
        DECR_PART="/dev/mapper/$DECR_MAPPER"
    else
        DECR_PART="$ENCR_PART"
    fi
}


### UTIL ###
read_init()
{
    local prompt="$1"
    local dest="$2"
    global "$dest"=''
    
    until [ -n "${!dest}" ]; do
        tell "$prompt" "(default ${!dest}): "
        read -r "$dest"
    done
}

read_dflt()
{
    local prompt="$1"
    local dest="$2"
    local temp
    
    tell "$prompt" "(default ${!dest}): "
    read -r temp
    global "$dest"="${temp:-${!dest}}"
}

read_pass()
{
    local prompt="$1"
    local dest="$2"
    local conf
    global "$dest"
    while [[ -z "${!dest}" ]] || [[ -z "$conf" ]] || [ "${!dest}" != "$conf" ]; do
        read -rsp "$prompt: " dest
        read -rsp "Verify: " "$conf"
    done
}

identify_hardware()
{
    #TODO should have seperate functions that return the data to the vars
    global WIRED_DEVICE="$(ip link | grep "eno\|enp" | awk '{print $2}'| sed 's/://' | sed '1!d')"
    global WIRELESS_DEVICE="$(ip link | grep wlp | awk '{print $2}'| sed 's/://' | sed '1!d')"
}
$DEL functions/fifo/fs.sh ###################
#!/bin/bash


# Also mounts physical partition
partition()
{
    global DRIVE
    parted -s "$DRIVE" \
        mklabel msdos \
        mkpart primary ext2 1 1G \
        mkpart primary ext2 1G 100% \
        set 1 boot on \
        set 2 LVM on
}

create_lvm()
{
    global LVM_NAME_SWAP
    global LVM_NAME_ROOT
    global LVM_NAME_VG
    global DECR_PART
    pvcreate "$DECR_PART"
    vgcreate "$LVM_NAME_VG" "$DECR_PART"
    
    # Create a 1GB swap partition
    lvcreate -C y -L1G "$LVM_NAME_VG" -n "$LVM_NAME_SWAP"
    
    # Use the rest of the space for root
    lvcreate -l '+100%FREE' "$LVM_NAME_VG" -n "$LVM_NAME_ROOT"

    # Enable the new volumes
    vgchange -ay
}

format_fs()
{
    global DECR_ROOT
    global DECR_SWAP
    global BOOT_PART
    mkfs.ext2 -L boot "$BOOT_PART"
    mkfs.ext4 -L root "$DECR_ROOT"
    mkswap "$DECR_SWAP"
}

decrypt_fs()
{
    : #TODO
}

mount_fs()
{
    global DECR_ROOT
    global DECR_SWAP
    global CHROOT_DIR
    global BOOT_PART
    mkdir -p "$CHROOT_DIR/boot"
    # Mount root
    mount "$DECR_ROOT" "$CHROOT_DIR"
    # Mount boot
    mount "$BOOT_PART" "$CHROOT_DIR/boot"
    # Mount swap
    swapon "$DECR_SWAP"

    mount -t proc none "$CHROOT_DIR/proc"
    [[ $? -ne 0 ]] && fatal "Failed to mount proc in $CHROOT_DIR"
    mount --rbind /dev "$CHROOT_DIR/dev/"
    [[ $? -ne 0 ]] && fatal "Failed to mount dev in $CHROOT_DIR"
}
$DEL functions/fifo/main.sh ###################
#!/bin/bash

install_fifo()
{
    step config
    step partition # Also mounts physical partition
    step create_lvm
    step format_fs
    step mount_fs
    step get_series a ap n
    step install_base
    step do_chroot
    step umount_fs
}

get_series()
{
    global PKG_DIR
    local OPWD=$(pwd)
    local cmds
    mkdir -p "$PKG_DIR"
    cd "$PKG_DIR" || fatal "Newly-created directory doesn't exist. Weird race condition?"
    for series in "$@"; do
        cmds+="mirror --only-missing $series\n"
    done
    cmds+="bye\n"
    echo -e "$cmds" | lftp
    cd "$OPWD" || fatal "Original directory doesn't exist. Weird race condition?"
}

install_base()
{
    global PKG_DIR
    global CHROOT_DIR
    installpkg_fifo pkgtools
    local BASE=$(grep ':ADD$' "$CHROOT_PKGDIR/*/tagfile" | cut -f1 -d:)
    BASE=$(echo "$BASE" | sed '/kernel-huge/c\kernel-generic') # Use generic kernel
    BASE+=slackpkg # Needed for lilo package installations
    local BASE_FNAMES=$(pkg_to_fname "$BASE")
    [ -n "$BASE_FNAMES" ] && installpkg --root "$CHROOT_DIR" "$BASE_FNAMES"
}

installpkg_fifo()
{
    [ -n "$1" ] || fatal "inst requires at least 1 argument"
    global PKG_DIR
    local OPWD=$(pwd)
    local pkg="$1"
    [ -n "$pkg" ]    || fatal "No pkg argument given to instpkg"
    [ -d "$PKG_DIR" ] || fatal "PKG_DIR $PKG_DIR doesn't exist, can't install package $pkg"
    cd "$PKG_DIR"
    
    local pkgfile=pkg_to_fname "$pkg"
    [ -f "$pkgfile" ] || fatal "No archive for package $pkg"
    local archive=$(echo "$pkgfile" \
                        | sed 's/.*\.\([a-z][a-z][a-z]\)$/\1/') # TODO use ${variable//search/replace}
    
    if [ "$archive" = "txz" ]; then
        xz -dc "$pkgfile" | tar xf - -C /
    elif [ "$archive" = "tgz" ]; then
        tar xzf "$pkgfile" -C /
    fi
    
    [ -f "/install/doinst.sh" ] && sh "/install/doinst.sh"
    [ -d "/install" ] && rm -rf "/install/"
    
    cd "$OPWD"
    
    shift
    [ -n "$1" ] && installpkg_fifo "$@"
}


do_chroot()
{
    global CHROOT_DIR
    cp "/gentool.log" "$CHROOT_DIR/gentool.fifo.log"
    cp "$0" "$CHROOT_DIR/$(basename "$0")"
    chroot "$CHROOT_DIR ./$(basename "$0")" chroot #TODO userspec
}

pkg_to_fname()
{
    find "$PGK_DIR" -type f \
        | egrep "^\./[a-z][a-z]*/$1-[0-9].*\.(txz|tgz)$" \
        | sed 's|^\./||'
}
$DEL functions/lilo/main.sh ###################
#!/bin/bash

install_lilo()
{
    global SLACK_MIRROR
    global CHROOT_PKGDIR
    global SETTINGS_COMPLETE
    global DESIRED_PKGS
    
    [ "$SETTINGS_COMPLETE" == true ] || config
    
    echo "$SLACK_MIRROR" > "/etc/slackpkg/mirrors"
    slackpkg update
    step slackpkg install "$DESIRED_PKGS"
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

    #TODO dotfiles
    #TODO clone user's keys

    #TODO remove script (kept ATM for debug)

    tell "Chroot complete!"
}

create_user()
{
    global USER_NAME
    global USER_PASS
    id -u "$USER_NAME" &>/dev/null || useradd -m -s /bin/bash -G \
        adm,systemd-journal,wheel,rfkill,games,network,video,audio,optical,floppy,storage,scanner,power "$USER_NAME"
    echo "$USER_NAME:$USER_PASS" | chpasswd
}

set_hostname()
{
    echo "$HOSTNAME" > /etc/hostname
}

set_timezone()
{
    timeconfig America/Winnipeg
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
    global DECR_ROOT
    global DECR_SWAP
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

set_initfs()
{
    mkinitrd -c -f ext4 -k "$(get_kernel_version)" -m ext4 -r "$DECR_ROOT" -C "$ENCR_PART" -L
}

set_init()
{
    : #TODO
}

set_bootloader()
{
    global LVM_NAME_VG
    global ENCR_PART
    global DECR_ROOT
    cat > /etc/lilo.conf <<EOF
image = /boot/$(get_kernel_filename)
  initrd = /boot/initrd.gz
  root = $DECR_ROOT
  cryptdevice = cryptdevice=/dev/disk/by-uuid/$(get_uuid "$ENCR_PART"):$LVM_NAME_VG
  label = linux
  read-only
EOF
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
    global ROOT_PASSWORD
    echo "root:$ROOT_PASSWORD" | chpasswd
}

gen_ssh()
{
    # Note: sshd_config, ssh_config and moduli are expected
    # to be added during dotfiles repo clone.
    mkdir -p /etc/ssh
    rm -rf /etc/ssh/*

    # Generate host keys
    ssh-keygen -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519
    ssh-keygen -t rsa -b 4096 -N "" -f /etc/ssh/ssh_host_rsa

    # Generate auth keys
    ssh-keygen -t ed25519 -N "" -o -a 100 -f /etc/ssh/ssh_auth_ed25519
    ssh-keygen -t rsa -b 4096 -N "" -o -a 100 -f /etc/ssh/ssh_auth_rsa

    # Modify permissions
    chown root /etc/ssh/*
    chmod 700 /etc/ssh
    chmod 600 /etc/ssh/ssh_host_ed25519
    chmod 600 /etc/ssh/ssh_host_rsa
    chmod 600 /etc/ssh/ssh_auth_ed25519.pub
    chmod 600 /etc/ssh/ssh_auth_rsa.pub
}

### UTILITIES ###

get_kernel_filename()
{
    kernels=( $(cd /boot && ls vmlinuz-generic*) )
    echo "${kernels[0]}"
}

get_kernel_version()
{
    fname=$(get_kernel_filename)
    echo "${fname#$"vmlinuz-generic-"}"
}


get_uuid()
{
    blkid -s UUID "$1" | awk '{print $2}' | sed 's/"//g' | sed 's/^.*=//'
}
$DEL functions/util.sh ###################
#!/bin/bash

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
    local cmd=$1
    shift
    echo -n "slacker: "
    float=$(printf "%0.s " $(eval echo {0..$STEP_I}))
#    [ -n $STEP_I ] && echo -n "$float"
    echo "$float$cmd" >&3
    (set -e; ((STEP_I+=1)); STEPTRACE+=">$cmd"; "$cmd" "$@") || error "${float}failed!" "stepfail"
}

### PRINTING ###
tell()
{
    echo "slacker: " "$@" >&3
}

error()
{
    local msg="$1"
    local trace="${2:-${STEPTRACE}}"
    echo -e "slacker: ${RED}$msg [${trace}]${NC}" >&4
}

fatal()
{
    echo "slacker: FATAL :(" >&4
    error "$@"
    exit
}
################### MAIN ###################
#!/bin/bash
# The only non-function code in the whole project.
set -x
exec 3>&1 4>&2                # Save original FDs
trap 'exec 2>&4 1>&3' 0 1 2 3 # Restore FDs for some signals
exec 1>"/gentool.log" 2>&1    # Redirect normal output to log

if [ "$1" == "chroot" ]; then
    step check_internet #TODO do we need internet for fifo too?
    step install_lilo
elif [ "$1" == "umount" ]; then
    umount_fs
else
    step install_fifo
fi
