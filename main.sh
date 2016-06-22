#!/bin/bash

[ "$SETTINGS_COMPLETE" == true ] || step config
step check_internet

if [ "$1" == "chroot" ]; then
    step install_lilo
elif [ "$1" == "step" ]; then
    [ "$SETTINGS_COMPLETE" == true ] || config
    shift
    step $@
else
    step install_fifo
fi
