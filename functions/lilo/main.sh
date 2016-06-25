#!/bin/bash

install_lilo()
{
    echo "$SLACK_MIRROR" > "/etc/slackpkg/mirrors"
    slackpkg update gpg >/dev/null #TODO ensure works
    slackpkg update >/dev/null
    slackpkg -batch=on -default_answer=y install "$DESIRED_PKGS" >/dev/null #TODO -batch option is not working?
    create_user
    set_hostname
    set_timezone
    #set_locale
    #set_keymap
    set_hosts
    set_fstab
    set_initfs
    set_init
    set_bootloader
    set_sudoers
    set_net
    set_root
    gen_ssh

    #TODO dotfiles
    #TODO clone user's keys

    #TODO remove script (kept ATM for debug)

    tell "Chroot complete!"
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

set_initfs()
{
    mkinitrd -c -f ext4 -k "$(get_kernel_version)" -m ext4 -r "$DECR_ROOT" -C "$ENCR_PART" -L
}

set_init()
{
    : #TODO
}

# TODO: cryptdevice=/dev/disk/by-uuid/$(get_uuid "$ENCR_PART"):$LVM_NAME_VG
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
    #TODO: Uncomment ecdsa and -o lines on upgrade to openssh 6.5
    mkdir -p /etc/ssh
    rm -rf /etc/ssh/*

    # Generate host keys
#    ssh-keygen -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key                    #+
    ssh-keygen -t ecdsa -N "" -f /etc/ssh/ssh_host_ecdsa_key                         #-
    ssh-keygen -t rsa -b 4096 -N "" -f /etc/ssh/ssh_host_rsa_key

    # Generate auth keys
#    ssh-keygen -t ed25519 -N "" -o -a 100 -f /etc/ssh/ssh_auth_ed25519_key          #+
#    ssh-keygen -t rsa -b 4096 -N "" -o -a 100 -f /etc/ssh/ssh_auth_rsa_key          #+
    ssh-keygen -t ecdsa -N "" -a 100 -f /etc/ssh/ssh_auth_ecdsa_key                  #-
    ssh-keygen -t rsa -b 4096 -N "" -a 100 -f /etc/ssh/ssh_auth_rsa_key              #-

    # Modify permissions
    chown root /etc/ssh/*
    chmod 700 /etc/ssh
#    chmod 600 /etc/ssh/ssh_host_ed25519_key                                         #+
    chmod 600 /etc/ssh/ssh_host_ecdsa_key                                            #-
    chmod 600 /etc/ssh/ssh_host_rsa_key
#    chmod 600 /etc/ssh/ssh_auth_ed25519_key.pub                                     #+
    chmod 600 /etc/ssh/ssh_auth_ecdsa_key.pub                                        #-
    chmod 600 /etc/ssh/ssh_auth_rsa_key.pub
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
