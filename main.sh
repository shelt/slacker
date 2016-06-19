#!/bin/bash
# The only non-function code in the whole project.
set -x
exec 3>&1 4>&2                # Save original FDs
trap 'exec 2>&4 1>&3' 0 1 2 3 # Restore FDs for some signals
exec 1>"/gentool.log" 2>&1    # Redirect normal output to log

if [ "$1" == "chroot" ]; then
    step check_internet #TODO do we need internet for fifo too?
    step install_lilo
elif [ "$1" == "umount" ]; then
    umount_fs
else
    step install_fifo
fi
