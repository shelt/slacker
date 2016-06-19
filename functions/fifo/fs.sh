#!/bin/bash


# Also mounts physical partition
partition()
{
    global DRIVE
    parted -s "$DRIVE" \
        mklabel msdos \
        mkpart primary ext2 1 1G \
        mkpart primary ext2 1G 100% \
        set 1 boot on \
        set 2 LVM on
}

create_lvm()
{
    global LVM_NAME_SWAP
    global LVM_NAME_ROOT
    global LVM_NAME_VG
    global DECR_PART
    pvcreate "$DECR_PART"
    vgcreate "$LVM_NAME_VG" "$DECR_PART"
    
    # Create a 1GB swap partition
    lvcreate -C y -L1G "$LVM_NAME_VG" -n "$LVM_NAME_SWAP"
    
    # Use the rest of the space for root
    lvcreate -l '+100%FREE' "$LVM_NAME_VG" -n "$LVM_NAME_ROOT"

    # Enable the new volumes
    vgchange -ay
}

format_fs()
{
    global DECR_ROOT
    global DECR_SWAP
    global BOOT_PART
    mkfs.ext2 -L boot "$BOOT_PART"
    mkfs.ext4 -L root "$DECR_ROOT"
    mkswap "$DECR_SWAP"
}

decrypt_fs()
{
    : #TODO
}

mount_fs()
{
    global DECR_ROOT
    global DECR_SWAP
    global CHROOT_DIR
    global BOOT_PART
    mkdir -p "$CHROOT_DIR/boot"
    # Mount root
    mount "$DECR_ROOT" "$CHROOT_DIR"
    # Mount boot
    mount "$BOOT_PART" "$CHROOT_DIR/boot"
    # Mount swap
    swapon "$DECR_SWAP"

    mount -t proc none "$CHROOT_DIR/proc"
    [[ $? -ne 0 ]] && fatal "Failed to mount proc in $CHROOT_DIR"
    mount --rbind /dev "$CHROOT_DIR/dev/"
    [[ $? -ne 0 ]] && fatal "Failed to mount dev in $CHROOT_DIR"
}
