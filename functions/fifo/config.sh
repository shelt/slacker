#!/bin/bash

config()
{
    step declare_vars
    step set_time #TODO
    step identify_hardware
    step prompt_settings
    step config_partitions
}

# Also sets defaults
declare_vars()
{
    ### NON-CONFIGURABLE ###
    declare -gx SLACK_MIRROR="ftp://mirror.csclub.uwaterloo.ca/slackware/slackware64-14.1/slackware64/"
    declare -gx CHROOT_DIR="/mnt/root" # Where root will be mounted in live environment
    declare -gx PKG_DIR="/pkg"   # `CHROOT_` prefix means chroot-relative path #TODO should be configurable, default would be within root
    declare -gx DESIRED_PKGS="
kbd
dhcpcd
ntp
openssh
file
which
wget
"

    declare -gx LVM_NAME_VG=vg00
    declare -gx LVM_NAME_ROOT=root
    declare -gx LVM_NAME_SWAP=swap
    declare -gx DECR_ROOT="/dev/$LVM_NAME_VG/$LVM_NAME_ROOT"
    declare -gx DECR_SWAP="/dev/$LVM_NAME_VG/$LVM_NAME_SWAP"

    declare -gx NC='\033[0m'
    declare -gx RED='\033[0;31m'

    ### BASED ON CONFIGURABLES ###
    declare -gx BOOT_PART
    declare -gx ENCR_PART
    declare -gx DECR_MAPPER=decrpv
    declare -gx DECR_PART # Path to the lvm pv. Encrypted? [/dev/mapper/DECR_MAPPER]. Not encrypted? [ENCR_PART].

    
    ### CONFIGURABLES ###
    
    declare -gx DRIVE='/dev/sda'            # Default drive to install to.
    declare -gx HOSTNAME='arch'             # Default hostname of the installed machine.
    declare -gx ENCRYPT=true                # Encrypt everything (except /boot).
    declare -gx USER_NAME='user'            # Default user to create (by default, added to wheel group, and others).
    declare -gx TIMEZONE='America/Winnipeg' # Default system timezone.
    declare -gx EXTENDED_CONFIG=false       # Prompt user for extended settings.
    declare -gx WIRELESS_DEVICE
    declare -gx WIRED_DEVICE
    declare -gx VIDEO_DRIVER="i915" # For Intel #TODO autodetection
    declare -gx DECR_PASS
    declare -gx USER_PASS
    declare -gx ROOT_PASS
    # Extended
    declare -gx ATTEMPTS_TILL_HINT=2
    declare -gx TMP_ON_TMPFS=true
    declare -gx KEYMAP='us'
    declare -gx AUR_PKG_MANAGER="packer"
    declare -gx TEST_INSTALL=false
    # Encryption
    declare -gx DECRYPT_HINT=true
    declare -gx DECRYPT_HINT_CONTACT='sam@shelt.ca'
    # Dotfiles
    declare -gx DOTFILES=true
    declare -gx DOTFILES_URL='https://www.bitbucket.com/shelt/dots'
    declare -gx DOTFILES_EXEC='sudo python2 clone.py -u sam'
    
    declare -gx SETTINGS_COMPLETE=false
}

prompt_settings()
{
    tell "## Configuration ##"
    read_dflt "Drive to install to" DRIVE
    read_dflt "Hostname" HOSTNAME
    read_dflt "Encrypt drive? true/false" ENCRYPT
    [ "$ENCRYPT" == true ] && read_pass "Encryption password" DECR_PASS
    read_dflt "User name" USER_NAME
    read_pass "User password" USER_PASS
    read_pass "Root password" ROOT_PASS
    [ -z "$WIRED_DEVICE" ] && read_init "Wired device (autodetect failed)" WIRED_DEVICE          #TODO make not mandatory
    [ -z "$WIRELESS_DEVICE" ] && read_init "Wireless device (autodetect failed)" WIRELESS_DEVICE #TODO make not mandatory
    
    read_dflt "Extended configuration? true/false" EXTENDED_CONFIG
    if [ "$EXTENDED_CONFIG" == true ]; then
        tell "## Extended Configuration ##"
        if [ "$ENCRYPT_DRIVE" == true ]; then
            tell "# Decryption #"
            
            read_dflt "Decryption hint? true/false" DECRYPT_HINT
            if [ "$DECRYPT_HINT" == true ]; then
                read_dflt "Decryption hint contact email" DECRYPT_HINT_CONTACT
                read_dflt "Failed attempts before hint" ATTEMPTS_TILL_HINT # TODO only a madman would ever modify this
            fi
        fi

        #TODO keyfiles
        
        tell "# Dotfiles #"
        read_dflt "Clone dotfiles repository?" DOTFILES
        if [ "$DOTFILES" == true ]; then
            read_dflt "Repository Git URL" DOTFILES_URL
            read_dflt "Command to execute in repo" DOTFILES_EXEC
        fi
        
        tell "# General #"
        read_dflt "Timezone" TIMEZONE
        read_dflt "Enable /tmp on a tmpfs? true/false (good only for low-ram systems" TMP_ON_TMPFS
        read_dflt "Keymap (dvorak, us, etc.)" KEYMAP
        read_dflt "Test install (No packages)" TEST_INSTALL
        
        tell "Extended configuration completed."
    fi

    SETTINGS_COMPLETE=true
    tell "Configuration completed."
}

config_partitions()
{
    global BOOT_PART="$DRIVE"1
    global ENCR_PART="$DRIVE"2
    global DECR_MAPPER
    global DECR_PART
    if [ "$ENCRYPT" == true ]
    then
        DECR_PART="/dev/mapper/$DECR_MAPPER"
    else
        DECR_PART="$ENCR_PART"
    fi
}


### UTIL ###
read_init()
{
    local prompt="$1"
    local dest="$2"
    global "$dest"=''
    
    until [ -n "${!dest}" ]; do
        tell "$prompt" "(default ${!dest}): "
        read -r "$dest"
    done
}

read_dflt()
{
    local prompt="$1"
    local dest="$2"
    local temp
    
    tell "$prompt" "(default ${!dest}): "
    read -r temp
    global "$dest"="${temp:-${!dest}}"
}

read_pass()
{
    local prompt="$1"
    local dest="$2"
    local conf
    global "$dest"
    while [[ -z "${!dest}" ]] || [[ -z "$conf" ]] || [ "${!dest}" != "$conf" ]; do
        read -rsp "$prompt: " dest
        read -rsp "Verify: " "$conf"
    done
}

identify_hardware()
{
    #TODO should have seperate functions that return the data to the vars
    global WIRED_DEVICE="$(ip link | grep "eno\|enp" | awk '{print $2}'| sed 's/://' | sed '1!d')"
    global WIRELESS_DEVICE="$(ip link | grep wlp | awk '{print $2}'| sed 's/://' | sed '1!d')"
}
