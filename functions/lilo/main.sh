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
