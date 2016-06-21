#!/bin/bash

install_fifo()
{
    step config
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
#    echo -e "$cmds" | lftp "$SLACK_MIRROR"
#    )
#}

install_installer()
{
    which du && [ ! -f /bin/du ] && ln -s "$(which du)" /bin/du # Suppress warnings
    local tmproot="/tmp/installer_root"
    mkdir -p "$tmproot"
    tar xzf "$(pkg_to_fname pkgtools)" -C /
}

install_base()
{
    local tagfiles="$(find "$PKG_DIR" -type f | grep "tagfile$")"
    local BASE="$(grep ':ADD$' $tagfiles | cut -f2 -d:)"
    BASE="$(echo "$BASE" | sed '/kernel-huge/c\kernel-generic')" # Use generic kernel
    BASE+=" slackpkg ncurses which" # Lilo deps
    local BASE_FNAMES="$(pkg_to_fname $BASE)"
    [ -n "$BASE_FNAMES" ] || fatal "Failed to generate base installation package list"
    installpkg --root "$CHROOT_DIR" $BASE_FNAMES >/dev/null
}

do_chroot()
{
    cp "/slacker.log" "$CHROOT_DIR/slacker.fifo.log"
    cp "$0" "$CHROOT_DIR/$(basename "$0")"
    chroot "$CHROOT_DIR" "./$(basename "$0")" chroot
}

pkg_to_fname()
{
    for curr in $@; do
        find "$PKG_DIR" -type f | egrep "/$curr-[0-9.]+-.*\.(txz|tgz)$"
    done
}
