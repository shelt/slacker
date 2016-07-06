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
    vgchange -an "$LVM_NAME_VG"
    cryptsetup luksClose "$DECR_MAPPER"
}

create_lvm()
{
    pvcreate "$DECR_PART"
    vgcreate "$LVM_NAME_VG" "$DECR_PART"
    lvcreate -C y -L1G "$LVM_NAME_VG" -n "$LVM_NAME_SWAP"      # 1GB swap partition
    lvcreate -l '+100%FREE' "$LVM_NAME_VG" -n "$LVM_NAME_ROOT" # rest of the space for root
#    vgchange -ay                                               # Enable volumes #TODO, not needed
}

format_plaintext()
{
    mkfs.ext2 -q -F -L boot "$BOOT_PART"
    mkfs.ext4 -q -F -L root "$DECR_ROOT"
    mkswap "$DECR_SWAP"
}

mount_plaintext()
{
    # Enable volumes
    vgchange -ay "$LVM_NAME_VG"
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
    
    mkdir -p "$CHROOT_DIR/proc" "$CHROOT_DIR/dev" "$CHROOT_DIR/sys"
    mount -t proc proc "$CHROOT_DIR/proc" || fatal "Failed to mount proc in $CHROOT_DIR"
    mount -t sysfs sys "$CHROOT_DIR/sys" || fatal "Failed to mount sys in $CHROOT_DIR"
    mount --rbind /dev "$CHROOT_DIR/dev/" || fatal "Failed to mount dev in $CHROOT_DIR"
}

umount_plaintext()
{
    umount -t proc "$CHROOT_DIR/proc"
    umount -t sysfs "$CHROOT_DIR/sys"
    umount -R "$CHROOT_DIR/dev"
    umount "$CHROOT_DIR/$PKG_DIR"
    swapoff "$DECR_SWAP"
    umount "$BOOT_PART"
    umount "$DECR_ROOT"
    vgchange -an "$LVM_NAME_VG"
}