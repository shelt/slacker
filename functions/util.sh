#!/bin/bash

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
    local cmd=$1
    shift
    echo -n "slacker: "
    float=$(printf "%0.s " $(eval echo {0..$STEP_I}))
#    [ -n $STEP_I ] && echo -n "$float"
    echo "$float$cmd" >&3
    (set -e; ((STEP_I+=1)); STEPTRACE+=">$cmd"; "$cmd" "$@") || error "${float}failed!" "stepfail"
}

### PRINTING ###
tell()
{
    echo "slacker: " "$@" >&3
}

error()
{
    local msg="$1"
    local trace="${2:-${STEPTRACE}}"
    echo -e "slacker: ${RED}$msg [${trace}]${NC}" >&4
}

fatal()
{
    echo "slacker: FATAL :(" >&4
    error "$@"
    exit
}
