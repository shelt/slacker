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