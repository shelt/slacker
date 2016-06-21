#!/bin/bash
# The only non-function code in the whole project.

#TODO move all to here of [ "$SETTINGS_COMPLETE" == true ] || config
if [ "$1" == "chroot" ]; then
    step check_internet #TODO do we need internet for fifo too?
    step install_lilo
elif [ "$1" == "fn" ]; then
    [ "$SETTINGS_COMPLETE" == true ] || config
    shift
    step $@
else
    step install_fifo
fi
