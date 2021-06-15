#!/usr/bin/env bash

############################################################################
# Proton Community Build download and management script
############################################################################
#
#
#
#
# made with <3
# Author: https://github.com/Termuellinator
#
# Based on https://github.com/the-sane/lug-helper
# and
# https://github.com/richardtatum/sc-runner-updater

############################################################################

###################### Variables to be changed by user #####################
# steam proton directory
# may also be "$HOME/.steam/root/compatibilitytools.d" or "$HOME/.steam/compatibilitytools.d" depending on distro
proton_dir="$HOME/.steam/steam/compatibilitytools.d/"
#
# URLs for downloading Proton builds
# Elements in this array must be added in quoted pairs of: "description" "url"
# The first string in the pair is expected to contain the proton description
# The second is expected to contain the github api releases url
# ie. "GloriousEggroll" "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases"
proton_sources=(
    "GloriousEggroll" "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases"
    "TKG" "https://api.github.com/repos/Frogging-Family/wine-tkg-git/releases"
)
# Set a maximum number of proton versions to display from each url
max_versions=20

############################################################################

# Check if script is run as root
if [ "$(id -u)" = 0 ]; then
echo "This script is not supposed to be run as root!"
exit 1
fi

# Check for dependencies
if [ ! -x "$(command -v curl)" ]; then
# Print to stderr and also try warning the user through notify-send
    printf "proton-community-updater.sh: The required package 'curl' was not found on this system.\n" 1>&2
    notify-send "proton-community-updater" "The required package 'curl' was not found on this system.\n" --icon=dialog-warning
    exit 1
fi
if [ ! -x "$(command -v mktemp)" ] || [ ! -x "$(command -v basename)" ]; then
    # Print to stderr and also try warning the user through notify-send
    printf "proton-community-updater.sh: One or more required packages were not found on this system.\nPlease check that the following packages are installed:\n- mktemp (part of gnu coreutils)\n- basename (part of gnu coreutils)\n" 1>&2
    notify-send "proton-community-updater" "One or more required packages were not found on this system.\nPlease check that the following packages are installed:\n- mktemp (part of gnu coreutils)\n- basename (part of gnu coreutils)\n" --icon=dialog-warning
    exit 1
fi

# Temporary directory
tmp_dir="$(mktemp -d --suffix=".proton-community-updater")"
trap 'rm -r "$tmp_dir"' EXIT

############################################################################

# Pixels to add for each Zenity menu option
# used to dynamically determine the height of menus
menu_option_height="25"

# Use logo installed by a packaged version of this script if available
# Otherwise, default to the logo in the same directory
if [ -f "/usr/share/pixmaps/proton-community-updater-icon.png" ]; then
    pcu_logo="/usr/share/pixmaps/proton-community-updater-icon.png"
elif [ -f "proton-community-updater-icon.png" ]; then
    pcu_logo="proton-community-updater-icon.png"
else
    pcu_logo="info"
fi

############################################################################
############################################################################


# Echo a formatted debug message to the terminal and optionally exit
# Accepts either "continue" or "exit" as the first argument
# followed by the string to be echoed
debug_print() {
    # This function expects two string arguments
    if [ "$#" -lt 2 ]; then
        printf "\nScript error:  The debug_print function expects two arguments. Aborting.\n"
        read -n 1 -s -p "Press any key..."
        exit 0
    fi

    # Echo the provided string and, optionally, exit the script
    case "$1" in
        "continue")
            printf "\n$2\n"
            ;;
        "exit")
            # Write an error to stderr and exit
            printf "proton-community-updater.sh: $2\n" 1>&2
            read -n 1 -s -p "Press any key..."
            exit 1
            ;;
        *)
            printf "proton-community-updater.sh: Unknown argument provided to debug_print function. Aborting.\n" 1>&2
            read -n 1 -s -p "Press any key..."
            exit 0
            ;;
    esac
}

# Display a message to the user.
# Expects the first argument to indicate the message type, followed by
# a string of arguments that will be passed to zenity or echoed to the user.
#
# To call this function, use the following format: message [type] "[string]"
# See the message types below for instructions on formatting the string.
message() {
    # Sanity check
    if [ "$#" -lt 2 ]; then
        debug_print exit "Script error: The message function expects two arguments. Aborting."
    fi
    
    # Use zenity messages if available
    if [ "$use_zenity" -eq 1 ]; then
        case "$1" in
            "info")
                # info message
                # call format: message info "text to display"
                margs=("--info" "--window-icon=$pcu_logo" "--no-wrap" "--text=")
                ;;
            "warning")
                # warning message
                # call format: message warning "text to display"
                margs=("--warning" "--window-icon=$pcu_logo" "--text=")
                ;;
            "question")
                # question
                # call format: if message question "question to ask?"; then...
                margs=("--question" "--window-icon=$pcu_logo" "--text=")
                ;;
            *)
                debug_print exit "Script Error: Invalid message type passed to the message function. Aborting."
                ;;
        esac

        # Display the message
        shift 1   # drop the first argument and shift the remaining up one
        zenity "${margs[@]}""$@" --width="400" --title="Proton Community Updater" 2>/dev/null
    else
        # Fall back to text-based messages when zenity is not available
        case "$1" in
            "info")
                # info message
                # call format: message info "text to display"
                clear
                printf "\n$2\n\n"
                read -n 1 -s -p "Press any key..."
                ;;
            "warning")
                # warning message
                # call format: message warning "text to display"
                clear
                printf "\n$2\n\n"
                read -n 1 -s -p "Press any key..."
                return 0
                ;;
            "question")
                # question
                # call format: if message question "question to ask?"; then...
                clear
                printf "$2\n"
                while read -p "[y/n]: " yn; do
                    case "$yn" in
                        [Yy]*)
                            return 0
                            ;;
                        [Nn]*)
                            return 1
                            ;;
                        *)
                            printf "Please type 'y' or 'n'\n"
                            ;;
                    esac
                done
                ;;
            *)
                debug_print exit "Script Error: Invalid message type passed to the message function. Aborting."
                ;;
        esac
    fi
}

# Display a menu to the user.
# Uses Zenity for a gui menu with a fallback to plain old text.
#
# How to call this function:
#
# Requires two arrays to be set: "menu_options" and "menu_actions"
# two string variables: "menu_text_zenity" and "menu_text_terminal"
# and one integer variable: "menu_height".
#
# - The array "menu_options" should contain the strings of each option.
# - The array "menu_actions" should contain function names to be called.
# - The strings "menu_text_zenity" and "menu_text_terminal" should contain
#   the menu description formatted for zenity and the terminal, respectively.
#   This text will be displayed above the menu options.
#   Zenity supports Pango Markup for text formatting.
# - The integer "menu_height" specifies the height of the zenity menu.
# 
# The final element in each array is expected to be a quit option.
#
# IMPORTANT: The indices of the elements in "menu_actions"
# *MUST* correspond to the indeces in "menu_options".
# In other words, it is expected that menu_actions[1] is the correct action
# to be executed when menu_options[1] is selected, and so on for each element.
#
# See MAIN at the bottom of this script for an example of generating a menu.
menu() {
    # Sanity checks
    if [ "${#menu_options[@]}" -eq 0 ]; then
        debug_print exit "Script error: The array 'menu_options' was not set\nbefore calling the menu function. Aborting."
    elif [ "${#menu_actions[@]}" -eq 0 ]; then
        debug_print exit "Script error: The array 'menu_actions' was not set\nbefore calling the menu function. Aborting."
    elif [ -z "$menu_text_zenity" ]; then
        debug_print exit "Script error: The string 'menu_text_zenity' was not set\nbefore calling the menu function. Aborting."
    elif [ -z "$menu_text_terminal" ]; then
        debug_print exit "Script error: The string 'menu_text_terminal' was not set\nbefore calling the menu function. Aborting."
    elif [ -z "$menu_height" ]; then
        debug_print exit "Script error: The string 'menu_height' was not set\nbefore calling the menu function. Aborting."
    fi
    
    # Use Zenity if it is available
    if [ "$use_zenity" -eq 1 ]; then
        # Format the options array for Zenity by adding
        # TRUE or FALSE to indicate default selections
        # ie: "TRUE" "List item 1" "FALSE" "List item 2" "FALSE" "List item 3"
        for (( i=0; i<"${#menu_options[@]}"-1; i++ )); do
            if [ "$i" -eq 0 ]; then
                # Select the first radio button by default
                zen_options=("TRUE")
                zen_options+=("${menu_options[i]}")
            else
                zen_options+=("FALSE")
                zen_options+=("${menu_options[i]}")
            fi
        done

        # Display the zenity radio button menu
        choice="$(zenity --list --radiolist --width="480" --height="$menu_height" --text="$menu_text_zenity" --title="Proton Community Updater" --hide-header --window-icon=$pcu_logo --column="" --column="Option" "${zen_options[@]}" 2>/dev/null)"

        # Loop through the options array to match the chosen option
        matched="false"
        for (( i=0; i<"${#menu_options[@]}"; i++ )); do
            if [ "$choice" = "${menu_options[i]}" ]; then
                # Execute the corresponding action
                ${menu_actions[i]}
                matched="true"
                break
            fi
        done

        # If no match was found, the user clicked cancel
        if [ "$matched" = "false" ]; then
            # Execute the last option in the actions array
            "${menu_actions[${#menu_actions[@]}-1]}"
        fi
    else
        # Use a text menu if Zenity is not available
        clear
        printf "\n$menu_text_terminal\n\n"

        PS3="Enter selection number: "
        select choice in "${menu_options[@]}"
        do
            # Loop through the options array to match the chosen option
            matched="false"
            for (( i=0; i<"${#menu_options[@]}"; i++ )); do
                if [ "$choice" = "${menu_options[i]}" ]; then
                    # Execute the corresponding action
                    printf "\n\n"
                    ${menu_actions[i]}
                    matched="true"
                    break
                fi
            done

            # Check if we're done looping the menu
            if [ "$matched" = "true" ]; then
                # Match was found and actioned, so exit the menu
                break
            else
                # If no match was found, the user entered an invalid option
                printf "\nInvalid selection.\n"
                continue
            fi
        done
    fi
}

# Called when the user clicks cancel on a looping menu
# Causes a return to the main menu
menu_loop_done() {
    looping_menu="false"
}



#------------------------- begin Proton Builds functions ----------------------------#

# Restart lutris
steam_restart() {
    if [ "$steam_needs_restart" = "true" ] && [ "$(pgrep steam)" ]; then
        if message question "Steam must be restarted to detect changes in installed Proton versions.\nWould you like this Helper to restart it for you?"; then
            debug_print continue "Restarting Steam..."
            pkill -SIGTERM steam && nohup steam </dev/null &>/dev/null &
        fi
    fi
    steam_needs_restart="false"
}

# Delete the selected proton
proton_delete() {
    # This function expects an index number for the array
    # installed_proton to be passed in as an argument
    if [ -z "$1" ]; then
        debug_print exit "Script error:  The proton_delete function expects an argument. Aborting."
    fi
    
    proton_to_delete="$1"
    if message question "Are you sure you want to delete the following Proton Build?\n\n${installed_proton[$proton_to_delete]}"; then
        rm -rf "${installed_proton[$proton_to_delete]}"
        debug_print continue "Deleted ${installed_proton[$proton_to_delete]}"
        steam_needs_restart="true"
    fi
}

# List installed Proton Builds for deletion
proton_select_delete() {
    # Configure the menu
    menu_text_zenity="Select the Proton build you want to remove:"
    menu_text_terminal="Select the Proton build you want to remove:"
    menu_text_height="65"
    goback="Return to the Proton management menu"
    unset installed_proton
    unset menu_options
    unset menu_actions
     
    # Create an array containing all directories in the proton_dir
    for proton_list in "$proton_dir"/*; do
        if [ -d "$proton_list" ]; then
            installed_proton+=("$proton_list")
        fi
    done
    
    # Create menu options for the installed proton builds
    for (( i=0; i<"${#installed_proton[@]}"; i++ )); do
        menu_options+=("$(basename "${installed_proton[i]}")")
        menu_actions+=("proton_delete $i")
    done
    
    # Complete the menu by adding the option to go back to the previous menu
    menu_options+=("$goback")
    menu_actions+=(":") # no-op

    # Calculate the total height the menu should be
    menu_height="$(($menu_option_height * ${#menu_options[@]} + $menu_text_height))"
    if [ "$menu_height" -gt "400" ]; then
        menu_height="400"
    fi
    
    # Call the menu function.  It will use the options as configured above
    menu
}

# Download and install the selected proton build
# Note: The variables proton_versions, contributor_url, and proton_url_type
# are expected to be set before calling this function
proton_install() {
    # This function expects an index number for the array
    # proton_versions to be passed in as an argument
    if [ -z "$1" ]; then
        debug_print exit "Script error:  The proton_install function expects a numerical argument. Aborting."
    fi

    # Get the proton build filename including file extension
    proton_file="${proton_versions[$1]}"

    # Get the selected proton build name minus the file extension
    # To add new file extensions, handle them here and in
    # the proton_select_install function below
    case "$proton_file" in
        *.tar.gz)
            proton_name="$(basename "$proton_file" .tar.gz)"
            ;;
        *.tgz)
            proton_name="$(basename "$proton_file" .tgz)"
            ;;
        *.tar.xz)
            proton_name="$(basename "$proton_file" .tar.xz)"
            ;;
        *)
            debug_print exit "Unknown archive filetype in proton_install function. Aborting."
            ;;
    esac

    # Get the selected proton build url
    # To add new sources, handle them here and in the
    # proton_select_install function below
    if [ "$proton_url_type" = "github" ]; then
        proton_dl_url="$(curl -s "$contributor_url" | grep "browser_download_url.*$proton_file" | cut -d \" -f4)"
    else
        debug_print exit "Script error:  Unknown api/url format in proton_sources array. Aborting."
    fi

    # Sanity check
    if [ -z "$proton_dl_url" ]; then
        message warning "Could not find the requested Proton build.  The source API may be down or rate limited."
        return 1
    fi

    # Download the proton build to the tmp directory
    debug_print continue "Downloading $proton_dl_url into $tmp_dir/$proton_file..."
    if [ "$use_zenity" -eq 1 ]; then
        # Format the curl progress bar for zenity
        mkfifo "$tmp_dir/protonpipe"
        cd "$tmp_dir" && curl -#LO "$proton_dl_url" > "$tmp_dir/protonpipe" 2>&1 & curlpid="$!"
        stdbuf -oL tr '\r' '\n' < "$tmp_dir/protonpipe" | \
        grep --line-buffered -ve "100" | grep --line-buffered -o "[0-9]*\.[0-9]" | \
        (
            trap 'kill "$curlpid"' ERR
            zenity --progress --auto-close --title="Proton Community Updater" --text="Downloading Proton build.  This might take a moment.\n" 2>/dev/null
        )

        if [ "$?" -eq 1 ]; then
            # User clicked cancel
            debug_print continue "Download aborted. Removing $tmp_dir/$proton_file..."
            rm "$tmp_dir/$proton_file"
            rm "$tmp_dir/protonpipe"
            return 1
        fi
        rm "$tmp_dir/protonpipe"
    else
        # Standard curl progress bar
        (cd "$tmp_dir" && curl -LO "$proton_dl_url")
    fi

    # Sanity check
    if [ ! -f "$tmp_dir/$proton_file" ]; then
        debug_print exit "Script error:  The requested proton build file was not downloaded. Aborting"
    fi  
    
    # Check if the archive has /files/ folder at top level and deciding wheather or not to create a subfolder
    if tar tf "$tmp_dir/$proton_file" | grep -m 1 -E "^files" > /dev/null; then
        # Create subfolder by the name of $proton_name and extract archive there
        debug_print continue "Installing Proton into $proton_dir/$proton_name..."
            if [ "$use_zenity" -eq 1 ]; then
                # Use Zenity progress bar
                mkdir -p "$proton_dir/$proton_name" && tar -xf "$tmp_dir/$proton_file" -C "$proton_dir/$proton_name" | \
                zenity --progress --pulsate --no-cancel --auto-close --title="Proton Community Updater" --text="Installing Proton build...\n" 2>/dev/null
            else
                mkdir -p "$proton_dir/$proton_name" && tar -xf "$tmp_dir/$proton_file" -C "$proton_dir/$proton_name"
            fi
            steam_needs_restart="true"
    else
        # Extract archive without a subfolder as archive seems to contain subfolder already
        debug_print continue "Installing Proton into $proton_dir..."
            if [ "$use_zenity" -eq 1 ]; then
                # Use Zenity progress bar
                mkdir -p "$proton_dir" && tar -xf "$tmp_dir/$proton_file" -C "$proton_dir" | \
                zenity --progress --pulsate --no-cancel --auto-close --title="Proton Community Updater" --text="Installing Proton build...\n" 2>/dev/null
            else
                mkdir -p "$proton_dir" && tar -xf "$tmp_dir/$proton_file" -C "$proton_dir"
            fi
            steam_needs_restart="true"
    fi

    # Cleanup tmp download
    debug_print continue "Removing $tmp_dir/$proton_file..."
    rm "$tmp_dir/$proton_file"
}


# List available Proton builds for download
proton_select_install() {
    # This function expects an element number for the array
    # proton_sources to be passed in as an argument
    if [ -z "$1" ]; then
        debug_print exit "Script error:  The proton_select_install function expects a numerical argument. Aborting."
    fi

    # Store the url from the selected contributor
    contributor_url="${proton_sources[$1+1]}"

    # Check the provided contributor url to make sure we know how to handle it
    # To add new sources, add them here and handle in the if statement
    # just below and the proton_install function above
    case "$contributor_url" in
        https://api.github.com*)
            proton_url_type="github"
            ;;
        *)
            debug_print exit "Script error:  Unknown api/url format in proton_sources array. Aborting."
            ;;
    esac
    
    # Check for GlibC-Version if TKG is selected, as he requires 2.33
    if [ "$contributor_url" = "https://api.github.com/repos/Frogging-Family/wine-tkg-git/releases" ]; then
        printf "checking for glibc \n"
        system_glibc=($(ldd --version | awk '/ldd/{print $NF}'))
        printf "system glibc-versuib: $system_glibc \n"
        required_glibc="2.33"
        if [ "$(bc <<< "$required_glibc>$system_glibc")" == "1" ]; then
            message warning "Your glibc version is too low, TKG requires v$required_glibc "
            proton_manage
        fi
    fi

    # Fetch a list of proton versions from the selected contributor
    # To add new sources, handle them here, in the if statement
    # just above, and the proton_install function above
    if [ "$proton_url_type" = "github" ]; then
        proton_versions=($(curl -s "$contributor_url" | awk '/browser_download_url/ {print $2}' | xargs basename -a))
    else
        debug_print exit "Script error:  Unknown api/url format in proton_sources array. Aborting."
    fi

    # Sanity check
    if [ "${#proton_versions[@]}" -eq 0 ]; then
        message warning "No proton versions were found.  The source API may be down or rate limited."
        return 1
    fi

    # Configure the menu
    menu_text_zenity="Select the Proton build you want to install:"
    menu_text_terminal="Select the Proton build you want to install:"
    menu_text_height="65"
    goback="Return to the Proton management menu"
    unset menu_options
    unset menu_actions
    
    # Iterate through the versions, check if they are installed,
    # and add them to the menu options
    # To add new file extensions, handle them here and in
    # the proton_install function above
    for (( i=0; i<"$max_versions" && i<"${#proton_versions[@]}"; i++ )); do
        # Get the proton name minus the file extension
        case "${proton_versions[i]}" in
            *.tar.gz)
                proton_name="$(basename "${proton_versions[i]}" .tar.gz)"
                ;;
            *.tgz)
                proton_name="$(basename "${proton_versions[i]}" .tgz)"
                ;;
            *.tar.xz)
                proton_name="$(basename "${proton_versions[i]}" .tar.xz)"
                ;;
            *)
                proton_name="skip"
                ;;
        esac

        # Add the proton names to the menu
        if [ $proton_name = "skip" ]; then
            continue
        elif [ -d "$proton_dir/$proton_name" ]; then
            menu_options+=("$proton_name    [installed]")
        else
            menu_options+=("$proton_name")
        fi
        menu_actions+=("proton_install $i")
    done

    # Complete the menu by adding the option to go back to the previous menu
    menu_options+=("$goback")
    menu_actions+=(":") # no-op

    # Calculate the total height the menu should be
    menu_height="$(($menu_option_height * ${#menu_options[@]} + $menu_text_height))"
    if [ "$menu_height" -gt "400" ]; then
        menu_height="400"
    fi
    
    # Call the menu function.  It will use the options as configured above
    menu
}

# Manage Proton Builds
proton_manage() {
    # Check if Lutris is installed
    if [ ! -x "$(command -v steam)" ]; then
        message info "Steam does not appear to be installed."
        return 0
    fi
    if [ ! -d "$proton_dir" ]; then
        message info "Proton directory not found.  Unable to continue.\n\n$proton_dir"
        return 0
    fi
    
    # The proton management menu will loop until the user cancels
    looping_menu="true"
    while [ "$looping_menu" = "true" ]; do
        # Configure the menu
        menu_text_zenity="<b><big>Manage Your Proton Builds</big>\n\nThe Proton Builds listed below are custom builds not affiliated with Valve</b>\n\nYou may choose from the following options:"
        menu_text_terminal="Manage Your Proton Builds\n\nThe Proton Builds listed below are custom builds not affiliated with Valve\nYou may choose from the following options:"
        menu_text_height="140"

        # Configure the menu options
        delete="Remove an installed Proton build"
        back="Return to the main menu"
        unset menu_options
        unset menu_actions

        # Loop through the proton_sources array and create a menu item
        # for each one. Even numbered elements will contain the proton build name
        for (( i=0; i<"${#proton_sources[@]}"; i=i+2 )); do
            # Set the options to be displayed in the menu
            menu_options+=("Install a Proton build from ${proton_sources[i]}")
            # Set the corresponding functions to be called for each of the options
            menu_actions+=("proton_select_install $i")
        done
        
        # Complete the menu by adding options to remove an installed proton build
        # or go back to the previous menu
        menu_options+=("$delete" "$back")
        menu_actions+=("proton_select_delete" "menu_loop_done")

        # Calculate the total height the menu should be
        menu_height="$(($menu_option_height * ${#menu_options[@]} + $menu_text_height))"
        
        # Call the menu function.  It will use the options as configured above
        menu
    done
    
    # Check if steam needs to be restarted after making changes
    steam_restart
}

#-------------------------- end Proton builds functions -----------------------------#


quit() {
    exit 0
}


############################################################################
# MAIN
############################################################################

# Check if Zenity is available
use_zenity=0
if [ -x "$(command -v zenity)" ]; then
    use_zenity=1
fi

# Set some defaults
steam_needs_restart="false"

# Credits for this go to https://gist.github.com/lukechilds/a83e1d7127b78fef38c2914c4ececc3c
get_latest_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
    grep '"tag_name":' |                                            # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
}

# Check if a new Verison of the script is available
repo="Termuellinator/Proton-Community-Updater"
current_version="v1.1"
latest_version=$(get_latest_release "$repo")

if [ "$latest_version" != "$current_version" ]; then
    # Print to stdout and also try warning the user through message
    printf "New version available, check https://github.com/Termuellinator/Proton-Community-Updater/releases \n"
    message info "New version available, check <a href='https://github.com/Termuellinator/Proton-Community-Updater/releases'>https://github.com/Termuellinator/Proton-Community-Updater/releases</a> \n"
fi


# Loop the main menu until the user selects quit
while true; do
    # Configure the menu
    menu_text_zenity="<b><big>Welcome, fellow Penguin, to the Proton Community Updater!</big>\n\nThis Helper is designed to help manage custom Proton builds</b>\n\nYou may choose from the following options:"
    menu_text_terminal="Welcome, fellow Penguin, to the Proton Community Updater!\n\nThis Helper is designed to help manage custom Proton builds\nYou may choose from the following options:"
    menu_text_height="140"

    # Configure the menu options
    proton_msg="Download or delete custom Proton builds"
    restart_msg="Restart Steam"
    quit_msg="Quit"
    
    # Set the options to be displayed in the menu
    menu_options=("$proton_msg" "$restart_msg" "$quit_msg")
    # Set the corresponding functions to be called for each of the options
    menu_actions=("proton_manage" "steam-restart" "quit")

    # Calculate the total height the menu should be
    menu_height="$(($menu_option_height * ${#menu_options[@]} + $menu_text_height))"
    
    # Call the menu function.  It will use the options as configured above
    menu
done
