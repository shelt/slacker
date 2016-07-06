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
    xz -d < "$(pkg_to_fname pkgtools)" | tar xvf -C /
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
    wget --no-check-certificate "https://github.com/sbopkg/sbopkg/releases/download/0.38.0/sbopkg-0.38.0-noarch-1_wsr.tgz" -O "/tmp/sbopkg.tgz" >/dev/null
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
