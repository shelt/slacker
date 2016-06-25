#!/bin/bash
#set -x TODO
#exec 3>&1 4>&2                # Save original FDs
#trap 'exec 2>&4 1>&3' 0 1 2 3 # Restore FDs for some signals
#exec 1>"/slacker.log" 2>&1    # Redirect normal output to log

# Script-wide non-configurables (needed before `config` is called)
declare -gx NC="\033[0m"
declare -gx RED="\033[0;31m"
declare -gx GREY="\033[90m"
declare -gx CYAN="\033[36m"

declare -gx READPROMPT="> "
declare -gx LOGFILE="/slacker.log"
declare -gx DEBUGMODE=true


#TODO fix non-debug mode
#[ "$DEBUGMODE" == true ] || exec 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
#[ "$DEBUGMODE" == true ] && set -x

#[ "$DEBUGMODE" == true ] && exec > >(tee -a ${LOGFILE} )
#[ "$DEBUGMODE" == true ] && exec 2> >(tee -a ${LOGFILE} >&2)


[ "$DEBUGMODE" == true ] || exec 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" >&2; done)
[ "$DEBUGMODE" == true ] || exec 3>&1 1>"$LOGFILE"

[ "$DEBUGMODE" == true ] && set -x

[ "$DEBUGMODE" == true ] && exec > >(tee -a ${LOGFILE} )
[ "$DEBUGMODE" == true ] && exec 2> >(tee -a ${LOGFILE} >&2)