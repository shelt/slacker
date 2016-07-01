#!/bin/bash

install_fifo()
{
    step partition
    step format_crypt
    step open_crypt
    step create_lvm
    step format_plaintext
    step mount_plaintext
#    step get_series a ap n l
    which installpkg || step install_installer
    step install_base
    step do_chroot
    step umount_plaintext
    step close_crypt
}

# Package retrieval is temp. disabled.
#get_series()
#{
#    (
#    local cmds
#    mkdir -p "$CHROOT_DIR/$PKG_DIR"
#    cd "$CHROOT_DIR/$PKG_DIR"
#    for series in "$@"; do
#        cmds+="mirror --only-missing $series\n"
#    done
#    cmds+="bye\n"
#    echo -e "$cmds" | lftp "$SLACK_MIRROR/slackware64" #TODO allow for the SLACK_MIRROR to not be 64 bit
#    )
#}

install_installer()
{
    which du >/dev/null && [ ! -f /bin/du ] && ln -s "$(which du)" /bin/du # Suppress warnings
    local tmproot="/tmp/installer_root"
    mkdir -p "$tmproot"
    tar xzf "$(pkg_to_fname pkgtools)" -C /
}

install_base()
{
    ( cd "$CHROOT_DIR" && mkdir -p bin boot cdrom dev etc home lib lib64 media mnt opt proc root sbin sys tmp usr var )
    local tagfiles="$(find "$PKG_DIR" -type f | grep "tagfile$")"
    local BASE
    BASE=" $(egrep ':ADD$' $tagfiles | cut -f2 -d:)"              # All required packages
    BASE=" $(echo "$BASE" | sed '/kernel-huge/c\kernel-generic')" # Use generic kernel
    BASE+=" $(egrep ':REC$' $PKG_DIR/l/tagfile | cut -f1 -d:)"     # Recommended libraries
    # Lilo deps
    BASE+=" slackpkg"     # Installing desired packages
    BASE+=" ncurses"      # I forget
    BASE+=" which"        # check_internet (among other things)
    BASE+=" wget"         # retrieving sbopkg
    BASE+=" curl"         # sbopkg
    BASE+=" gnupg"        # sbopkg among others
    BASE+=" mpfr"         # I forget
    BASE+=" openssh"      # I forget
    BASE+=" openssl"      # HTTPS
    BASE+=" glibc"        # I forget
    BASE+=" dhcpcd"       # check_internet
    BASE+=" dialog"       # slackpkg, sbopkg...
    BASE+=" mkinitrd"     # set_initfs
    BASE+=" lvm2"         # LILO
    BASE+=" cryptsetup"   # LILO
    BASE+=" libgpg-error" # I forget
    BASE+=" diffutils"    # I forget
    BASE+=" rsync"        # sbopkg
    #TODO this is not all that is needed
    
    local BASE_FNAMES="$(pkg_to_fname $BASE)"
    [ -n "$BASE_FNAMES" ] || fatal "Failed to generate base installation package list"
    installpkg --root "$CHROOT_DIR" $BASE_FNAMES #TODO >/dev/null
    
    mkdir  -p "/tmp"
    wget --no-check-certificate "https://github.com/sbopkg/sbopkg/releases/download/0.37.1/sbopkg-0.37.1-noarch-1_wsr.tgz" -O "/tmp/sbopkg.tgz" >/dev/null
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
        find "$PKG_DIR" -type f | egrep "/.*\.(txz|tgz)$" | fgrep "/$curr-"
        [ $? -eq 1 ] && error "Failed to locate tarball for package $curr"
    done
}
