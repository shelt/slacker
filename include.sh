#!/bin/bash

set -x
exec 3>&1 4>&2                # Save original FDs
trap 'exec 2>&4 1>&3' 0 1 2 3 # Restore FDs for some signals
exec 1>"/gentool.log" 2>&1    # Redirect normal output to log