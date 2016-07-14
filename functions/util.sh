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

# Accepts a function (opt. parameters) which executes as a step
# in the install process.
step()
{
    local cmd=$1; shift
    tell "${CYAN}Doing $cmd${NC}"
    "$cmd" "$@"
    
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
