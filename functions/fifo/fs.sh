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
    cryptsetup luksClose "$DECR_MAPPER"
}

create_lvm()
{
    pvcreate "$DECR_PART"
    vgcreate "$LVM_NAME_VG" "$DECR_PART"
    
    # Create a 1GB swap partition
    lvcreate -C y -L1G "$LVM_NAME_VG" -n "$LVM_NAME_SWAP"
    
    # Use the rest of the space for root
    lvcreate -l '+100%FREE' "$LVM_NAME_VG" -n "$LVM_NAME_ROOT"

    # Enable the new volumes
    vgchange -ay
}

format_plaintext()
{
    mkfs.ext2 -F -L boot "$BOOT_PART"
    mkfs.ext4 -F -L root "$DECR_ROOT"
    mkswap "$DECR_SWAP"
}

# NOTE: requires the LVM be decrypted, enabled
mount_plaintext()
{
    
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
    
    mkdir -p "$CHROOT_DIR/proc" "$CHROOT_DIR/dev"
    mount -t proc none "$CHROOT_DIR/proc"
    [[ $? -ne 0 ]] && fatal "Failed to mount proc in $CHROOT_DIR"
    mount --rbind /dev "$CHROOT_DIR/dev/"
    [[ $? -ne 0 ]] && fatal "Failed to mount dev in $CHROOT_DIR"
}

umount_plaintext()
{
    umount "$CHROOT_DIR/proc"
    umount "$CHROOT_DIR/dev"
    umount "$CHROOT_DIR/$PKG_DIR"
    swapoff "$DECR_SWAP"
    umount "$DECR_ROOT"
    umount "$BOOT_PART"
}