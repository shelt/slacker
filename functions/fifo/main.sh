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
