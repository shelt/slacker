#!/bin/bash

config()
{
    declare_vars
    prompt_settings
    
    # config partitions
    BOOT_PART="$DRIVE"1
    ENCR_PART="$DRIVE"2
    if [ "$ENCRYPT" == true ]
    then
        DECR_PART="/dev/mapper/$DECR_MAPPER"
    else
        DECR_PART="$ENCR_PART"
    fi
}

# Also sets defaults
declare_vars()
{
    ### NON-CONFIGURABLE ###
    declare -gx SLACK_VERS="14.2" # Be sure to update sbopkg release url when changing this
    declare -gx SLACK_MIRROR="ftp://mirrors1.kernel.org/slackware/slackware64-$SLACK_VERS/"
    declare -gx CHROOT_DIR="/mnt/root" # Where root will be mounted in live environment
    declare -gx EXTRA_PKGS_OFFICIAL="sudo Thunar mozilla-firefox ntp kbd"
    declare -gx EXTRA_PKGS_SBO="i3 i3status feh autocutsel lxappearance rxvt-unicode"

    declare -gx LVM_NAME_VG=vg00
    declare -gx LVM_NAME_ROOT=root
    declare -gx LVM_NAME_SWAP=swap
    declare -gx DECR_ROOT="/dev/$LVM_NAME_VG/$LVM_NAME_ROOT"
    declare -gx DECR_SWAP="/dev/$LVM_NAME_VG/$LVM_NAME_SWAP"

    ### BASED ON CONFIGURABLES ###
    declare -gx BOOT_PART
    declare -gx ENCR_PART
    declare -gx DECR_MAPPER=decrpv
    declare -gx DECR_PART # Encrypted ? /dev/mapper/$DECR_MAPPER : $ENCR_PART

    
    ### CONFIGURABLES ###
    
    declare -gx DRIVE='/dev/sda'            # Default drive to install to.
    declare -gx HOSTNAME='slack'            # Default hostname of the installed machine.
    declare -gx ENCRYPT=true                # Encrypt everything (except /boot).
    declare -gx USER_NAME='user'            # Default user to create (by default, added to wheel group, and others).
    declare -gx TIMEZONE='America/Winnipeg' # Default system timezone.
    declare -gx EXTENDED_CONFIG=false       # Prompt user for extended settings.
    declare -gx PKG_DIR
    declare -gx WIRELESS_DEVICE=$(get_wireless_device)
    declare -gx WIRED_DEVICE=$(get_wired_device)
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
    declare -gx DOTFILES_EXEC="sudo python2 clone.py -u $USER_NAME"
    # Keyring
    declare -gx KEYRING=true
    declare -gx KEYRING_DIR
    
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
    read_init "Slackware package directory" PKG_DIR
    
    read_dflt "Extended configuration? true/false" EXTENDED_CONFIG
    if [ "$EXTENDED_CONFIG" == true ]; then
        tell "## Extended Configuration ##"
        if [ "$ENCRYPT_DRIVE" == true ]; then
            tell "# Decryption #"
            
            read_dflt "Decryption hint? true/false" DECRYPT_HINT
            if [ "$DECRYPT_HINT" == true ]; then
                read_dflt "Decryption hint contact email" DECRYPT_HINT_CONTACT
                read_dflt "Failed attempts before hint" ATTEMPTS_TILL_HINT #TODO only a madman would ever modify this
            fi
        fi
        
        tell "# Dotfiles #"
        read_dflt "Clone dotfiles repository?" DOTFILES
        if [ "$DOTFILES" == true ]; then
            read_dflt "Repository Git URL" DOTFILES_URL
            read_dflt "Command to execute in repo" DOTFILES_EXEC
        fi

        tell "# Keyring #"
        read_dflt "Clone keyring (gnupg) directory?" KEYRING
        if [ "$KEYRING" == true ]; then
            read_init "Keyring directory" KEYRING_DIR
        fi
        
        tell "# General #"
        read_dflt "Timezone" TIMEZONE
        read_dflt "Enable /tmp on a tmpfs? true/false (good only for low-ram systems)" TMP_ON_TMPFS
        read_dflt "Test install (No packages)" TEST_INSTALL
        
        tell "Extended configuration completed."
    fi

    SETTINGS_COMPLETE=true
    tell "Configuration completed."
}

### UTIL ###
read_init()
{
    # TODO this function always invokes readline! Problem?
    local prompt="$1"
    local dest="$2"
    unset "$dest"
    
    until [ -n "${!dest}" ]; do
        tell "${prompt}: "
        read -re -p "$READPROMPT" "$dest"
    done
    declare -gx "$dest"
}

read_dflt()
{
    local prompt="$1"
    local dest="$2"
    local temp
    
    tell "$prompt" "(default ${!dest}): "
    read -r -p "$READPROMPT" temp
    declare -gx "$dest"="${temp:-${!dest}}"
}

read_pass()
{
    local prompt="$1"
    local dest="$2"
    local conf
    while [[ -z "${!dest}" ]] || [[ -z "$conf" ]] || [ "${!dest}" != "$conf" ]; do
        tell "$prompt: "
        read -rs -p "$READPROMPT" "$dest" && printf "\n"
        tell "Verify: "
        read -rs -p "$READPROMPT" conf && printf "\n"
    done
    declare -gx "$dest"
}

get_wired_device()
{
    line="$(ip link | egrep -o "(eth|en|eno)[0-9]+:")"
    echo ${line%?}
}

get_wireless_device()
{
    line="$(ip link | egrep -o "wlan\d+:")"
    echo ${line%?}
}