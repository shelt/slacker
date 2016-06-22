#!/bin/bash

check_internet()
{
    mkdir -p "/etc"
    getent hosts google.com >/dev/null || echo "nameserver 8.8.8.8" >/etc/resolv.conf
    ping 8.8.8.8 -c 2 >/dev/null && return
    which dhcpcd && dhcpcd "$WIRED_DEVICE" && return
    which dhclient && dhclient "$WIRED_DEVICE"
    ping 8.8.8.8 -c 2 >/dev/null || fatal "Failed to establish an internet connection"
}


#TODO unused
global()
{
    IFS='=' read var val <<< "$1"
    [ -z "${var+x}" ]           && fatal "undeclared variable declared as global: $1"
    bash -c '[ -z ${var+x} ]' && fatal "nonexported variable declared as global"
    declare -gx "$1"
}

# Accepts a function (opt. parameters) which executes as a step
# in the install process.
step()
{
    local cmd=$1; shift
    local float=$(printf "%0.s " $(eval echo {0..$STEP_I}))
    float=${float#?} # TODO 1 too many spaces
    tell "$float${CYAN}Doing $cmd${NC}"
    STEP_I=$(( STEP+1 ))
    "$cmd" "$@"
    [ $STEP_I -gt 0 ] && STEP_I=$(( STEP_I+1 ))
    
}

### PRINTING ###
tell()
{
    echo -e "slacker: $@" #>&3 TODO
}

error()
{
    local msg="$1"
    echo -e "slacker: ${RED}$msg${NC}" #>&4 TODO
}

fatal()
{
    echo "slacker: FATAL :(" #>&4 TODO
    error "$@"
    exit
}
