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
    [ "$KEYRING" == true ]  && step clone_keyring

    tell "Chroot complete!"
}

install_official_extras()
{
    echo "$SLACK_MIRROR" > "/etc/slackpkg/mirrors"
    slackpkg update gpg >/dev/null
    slackpkg update >/dev/null
    slackpkg -batch=on -default_answer=y install "$EXTRA_PKGS_OFFICIAL" >/dev/null #TODO -batch option is not working?
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

set_init()
{
    : #TODO
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
