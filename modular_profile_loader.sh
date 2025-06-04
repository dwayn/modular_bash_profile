# Root bash profile script that should be sourced from your automatically sourced profile file
#   ~/.bash_profile
#   ~/.profile
#   ~/.bashrc

# Add this line to whichever profile file from above you use (pro tip, provide an absolute path using $HOME or 
# other path variables that expand to an absolute path to ensure best compatibility with various terminals)
# source [$HOME]/path/to/modular_bash_profile/modular_profile_loader.sh


# TODO List:
# After working with it for a bit, the way that local modules and shared modules are handled
#   has turned out to be quite a pain.
# - It would be better to rework the directory structure to have a modules directory and then within
#   that, have local, shared, and enabled directories. Then rework all the references in the function code to use
#   the new directory structure directly and stop needing to remap the name of the global module groups to the
#   directory structure and back. This would also make for a more consistent way to handle the default
#   priorities and enabled/disabled status for the modules.
# - Also, after thinking about it for a while, I do not like the naming of global/local for modules,
#   consider changing them to shared/local
# - Maybe add a .defaults file to each of the directories for the modules in that group instead of a
#   global defaults file. This would allow the default priorities to be checked in for shared modules
#   to act as an ordering guide. There could then be a defaults file in the local modules directory
#   that would allow for the default enabled/disabled status to be set for the local modules. Then when
#   the user saves their defaults, that could be saved in the enabled directory with their actual configured
#   priorities
# - Add a function to enable modules based on the their defaults for whether they are enabled or disabled.
#   This would allow for new modules to be added in git with a default configuration of enabled and then
#   when the repo is pulled down, it would make for really easy/quick update of the the enabled modules
#   to the latest version of the repo state.
# - Figure out a way to make the management code more modular, reuse code more, and easier to navigate.
#   It is a bit of a mess because I threw it together quickly and then added a bunch of features to it
#   without designing for modularity


# Map of enabled module name to the location of the module file (local or global)
declare -A _modular_bash_enabled_module_locations
# Map of enabled module name to the priority of the module
declare -A _modular_bash_enabled_module_priorities
# Map of enabled module name to the name of the module file that the symlink points to
declare -A _modular_bash_enabled_module_names
# Map of local module name to the name of the symlink in the enabled folder for local modules that are
# enabled.
declare -A _modular_bash_enabled_local_modules
# Map of global module name to the name of the symlink in the enabled folder for global modules that are
# enabled.
declare -A _modular_bash_enabled_global_modules
# Map of the local modules default priorities based on the .defaults file
declare -A _modular_bash_local_default_priorities
# Map of the global modules default priorities based on the .defaults file
declare -A _modular_bash_global_default_priorities
# Map of the local modules default enabled/disabled status based on the .defaults file
declare -A _modular_bash_local_default_enabled
# Map of the global modules default enabled/disabled status based on the .defaults file
declare -A _modular_bash_global_default_enabled


# if there is a modular-bash.sh file in the local module directory, then source it.
# This is necessary to ensure that the pathing is setup correctly for the rest of the load of this file.
if [ -f "$(dirname "${BASH_SOURCE[0]}")/local/modular-bash.sh" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/local/modular-bash.sh"
fi
# if MODULAR_BASH_ROOT is not set, then set it to the default value of $(dirname "${BASH_SOURCE[0]}") and
# inform the user they should run the modular_bash_init function to set it or set it themselves before
# sourcing this file.
if [ -z "$MODULAR_BASH_ROOT" ]; then
    MODULAR_BASH_ROOT=$(dirname "${BASH_SOURCE[0]}")
    echo "MODULAR_BASH_ROOT not set, run modular_bash_init to set it or set it yourself to ensure proper functionality"
fi

# Helper function to parse the .defaults file and set the default priorities and enabled/disabled status
# for the modules based on the file.
function _modular_bash_parse_defaults() {
    local defaults_file
    local line
    local enabled
    local location
    local priority
    local module
    defaults_file=$MODULAR_BASH_ROOT/local/.defaults
    if [ -f "$defaults_file" ]; then
        while read -r line; do
            # Skip any lines that start with a comment or are empty
            if [[ $line =~ ^\s*# ]] || [[ -z "$line" ]]; then
                continue
            fi
            # Parse the line to get the enabled/disabled status, location, priority, and module name
            enabled=$(echo $line | awk '{print $1}')
            location=$(echo $line | awk '{print $2}')
            priority=$(echo $line | awk '{print $3}')
            module=$(echo $line | awk '{print $4}')
            # add .sh to the end of the module name if it is not already there
            if [ "${module: -3}" != ".sh" ]; then
                module+=".sh"
            fi
            # Set the default priority and enabled/disabled status for the module based on the location
            # of the module
            if [ "$location" == "local" ]; then
                _modular_bash_local_default_priorities[$module]=$priority
                _modular_bash_local_default_enabled[$module]=$enabled
            elif [ "$location" == "global" ]; then
                _modular_bash_global_default_priorities[$module]=$priority
                _modular_bash_global_default_enabled[$module]=$enabled
            fi
        done < "$defaults_file"
    fi
}

# Bash function that will save the currently enabled modules to a .defaults file in the local folder.
# This will keep all the comment lines from the current .defaults file and then regenerate the rest of
# the file based on which modules are currently enabled and their priorities and enabled/disabled. Any
# modules that are not currently enabled but have a default priority configured in the .defaults file
# will retain their default priority in the new .defaults file. The enabled/disabled status will be
# based on the current enabled modules and priority will be set to current priority if it is enabled or
# the current default priority if it is not enabled.
function modular_bash_save_defaults() {
    local defaults_file
    local enabled_modules
    local module
    local location
    local priority
    local enabled
    local default_priority
    local default_enabled
    local default_location
    local default_module
    local comments
    local temp_defaults_file

    # Fresh parse the current defaults and enabled modules to ensure state on disk is up to date
    _modular_bash_parse_defaults
    _modular_bash_reload_maps

    defaults_file=$MODULAR_BASH_ROOT/local/.defaults
    comments=$(grep -E "^\s*#" "$defaults_file" 2>/dev/null)
    enabled_modules=$(ls "$MODULAR_BASH_ROOT/enabled/"*.sh 2>/dev/null | xargs -n 1 basename | sort)
    defaults_file=$MODULAR_BASH_ROOT/local/.defaults
    # Generate into a temp file to ensure we don't lose the original if something goes wrong
    temp_defaults_file=$MODULAR_BASH_ROOT/local/.defaults.tmp
    rm -f "$temp_defaults_file"
    touch "$temp_defaults_file"
    echo "$comments" > "$temp_defaults_file"
    for enabled_module in $enabled_modules; do
        module=${_modular_bash_enabled_module_names[$enabled_module]}
        location=${_modular_bash_enabled_module_locations[$enabled_module]}
        priority=${_modular_bash_enabled_module_priorities[$enabled_module]}
        priority=$(printf "%02d" $priority)
        enabled="+" # default to enabled

        echo "  $enabled $location $priority ${module%.sh}" >> "$temp_defaults_file"
    done
    # # iterate the _modular_bash_global_default_priorities and print the keys and values
    # for key in "${!_modular_bash_global_default_priorities[@]}"; do
    #     echo "$key ${_modular_bash_global_default_priorities[$key]}"
    # done


    # Find all the global modules that are not currently enabled and output them to the temp file with
    # their default priority if they currently have a default priority set in the .defaults file. Otherwise,
    # they will not be output to the temp file.
    for global_module in $(ls "$MODULAR_BASH_ROOT/modules/"*.sh 2>/dev/null | xargs -n 1 basename | sort); do
        # if the global module name is in _modular_bash_global_modules, then it is currently enabled and we can skip it here
        if [ -n "${_modular_bash_enabled_global_modules[$global_module]}" ]; then
            continue
        fi
        # if there is not a priority in _modular_bash_global_default_priorities, then it is not in the defaults file,
        # so we don't need to output it
        if [ -z "${_modular_bash_global_default_priorities[$global_module]}" ]; then
            continue
        fi
        priority=${_modular_bash_global_default_priorities[$global_module]}
        priority=$(printf "%02d" $priority)
        enabled="-" # default to disabled
        location="global"

        echo "  $enabled $location $priority ${global_module%.sh}" >> "$temp_defaults_file"
    done
    # Find all the local modules that are not currently enabled and output them to the temp file with
    # their default priority if they currently have a default priority set in the .defaults file. Otherwise,
    # they will not be output to the temp file.
    for local_module in $(ls "$MODULAR_BASH_ROOT/local/"*.sh 2>/dev/null | xargs -n 1 basename | sort); do
        # if the local module name is in _modular_bash_local_modules, then it is currently enabled and we can skip it here
        if [ -n "${_modular_bash_enabled_local_modules[$local_module]}" ]; then
            continue
        fi
        # if there is not a priority in _modular_bash_local_default_priorities, then it is not in the defaults file,
        # so we don't need to output it
        if [ -z "${_modular_bash_local_default_priorities[$local_module]}" ]; then
            continue
        fi
        priority=${_modular_bash_local_default_priorities[$local_module]}
        priority=$(printf "%02d" $priority)
        enabled="-" # default to disabled
        location="local"

        echo "  $enabled $location $priority ${local_module%.sh}" >> "$temp_defaults_file"
    done
    # Move the temp file to the original .defaults file
    mv "$temp_defaults_file" "$defaults_file"
    echo "Defaults saved to $defaults_file"
    _modular_bash_parse_defaults
}



# Helper function to set the values for the enabled modules maps based on the name of the symlink in
# the enabled folder. This is used to populate the enabled modules maps when the modular_bash_reload
# function is called.
function _modular_bash_set_enabled_module() {
    local enabled_module
    local module
    local module_name
    local priority
    local location
    enabled_module=$1
    enabled_module=$(basename $enabled_module)
    if [ "${enabled_module: -3}" != ".sh" ]; then
        enabled_module+=".sh"
    fi

    # Get the name of the module file that the symlink points to
    module=$(ls -l "$MODULAR_BASH_ROOT/enabled/$enabled_module" | awk '{print $NF}')
    module_name=$(basename $module)
    priority=$(echo $enabled_module | sed 's/^\([0-9]\{1,\}\)-.*/\1/')
    location=$(echo $module | grep -o "local" || echo "global")

    # Set the values for the enabled modules maps
    _modular_bash_enabled_module_locations[$enabled_module]=$location
    _modular_bash_enabled_module_priorities[$enabled_module]=$priority
    _modular_bash_enabled_module_names[$enabled_module]=$module_name
    if [ "$location" == "local" ]; then
        _modular_bash_enabled_local_modules[$module_name]=$enabled_module
    else
        _modular_bash_enabled_global_modules[$module_name]=$enabled_module
    fi
}

# Helper function to clear the enabled modules maps without unsetting the maps themselves.
function _modular_bash_clear_enabled_modules() {
    for key in "${!_modular_bash_enabled_module_locations[@]}"; do
        unset _modular_bash_enabled_module_locations[$key]
    done
    for key in "${!_modular_bash_enabled_module_priorities[@]}"; do
        unset _modular_bash_enabled_module_priorities[$key]
    done
    for key in "${!_modular_bash_enabled_module_names[@]}"; do
        unset _modular_bash_enabled_module_names[$key]
    done
    for key in "${!_modular_bash_enabled_local_modules[@]}"; do
        unset _modular_bash_enabled_local_modules[$key]
    done
    for key in "${!_modular_bash_enabled_global_modules[@]}"; do
        unset _modular_bash_enabled_global_modules[$key]
    done
}


_modular_bash_reload_maps() {
    _modular_bash_clear_enabled_modules
    for file in "$MODULAR_BASH_ROOT/enabled/"*; do
        if [ "${file##*/}" != "README.md" ]; then
            _modular_bash_set_enabled_module "$file"
        fi
    done
}

_modular_bash_reload() {
    local notify
    local location
    notify=${1:-false}

    # Iterate through all the files in the enabled folder and source them to load/reload them
    for file in "$MODULAR_BASH_ROOT/enabled/"*; do
        if [ "${file##*/}" != "README.md" ]; then
            if [ "${notify}" == "true" ]; then echo "Reloading $file"; fi
            source "$file"
        fi
    done
}

# Automatically source all the files in the enabled folder to load all the modules that are enabled
_modular_bash_reload

# Nicely named bash function to do the reload
function modular_bash_reload() {
    _modular_bash_reload true
}


# Bash function to list all of the available modules based on all the .sh files in modules and local
# folders. Lists out all of the enabled modules with their priority, location, and the name of the
# module file that the symlink points to. Then lists out all of the local and global modules that are
# not enabled.
function modular_bash_list() {
    local global_modules
    local local_modules
    local enabled_modules
    local location
    local priority
    local module_name

    # Reload the enabled modules maps
    _modular_bash_reload_maps

    enabled_modules=$(ls "$MODULAR_BASH_ROOT/enabled/"*.sh 2>/dev/null | xargs -n 1 basename | sort)
    for enabled_module in $enabled_modules; do
        location=${_modular_bash_enabled_module_locations[$enabled_module]}
        location_column=$(echo $location | sed 's/local/(local) /g' | sed 's/global/(global)/g')
        priority=${_modular_bash_enabled_module_priorities[$enabled_module]}
        module_name=${_modular_bash_enabled_module_names[$enabled_module]}
        echo -e "+ $location_column $priority-$module_name"
    done
    for global_module in $(ls "$MODULAR_BASH_ROOT/modules/"*.sh 2>/dev/null | xargs -n 1 basename | sort); do
        # if global_module is not in _modular_bash_enabled_global_modules, then it is not enabled so
        # output it as not enabled
        if [ -z "${_modular_bash_enabled_global_modules[$global_module]}" ]; then
            echo -e "- (global) $global_module"
        fi
    done
    for local_module in $(ls "$MODULAR_BASH_ROOT/local/"*.sh 2>/dev/null | xargs -n 1 basename | sort); do
        # if local_module is not in _modular_bash_enabled_local_modules, then it is not enabled so
        # output it as not enabled
        if [ -z "${_modular_bash_enabled_local_modules[$local_module]}" ]; then
            echo -e "- (local)  $local_module"
        fi
    done
}


# Bash Function to enable a module by creating a symlink in the enabled folder based on the name of the
# module and the priority. Optionally you can provide a priority for the module. If no priority is
# provided then the module will be enabled will be enabled with its default priority. If there is no
# default priority set for the module, one must be provided.
function modular_bash_enable() {
    # Protect against not providing a module name
    if [ -z "$1" ]; then
        echo "No module name provided"
        return 1
    fi
    # reload the enabled module maps and defaults
    _modular_bash_reload_maps
    _modular_bash_parse_defaults

    local global_modules
    local local_modules
    local module
    local module_name
    local priority
    module=$1
    module=$(echo $1 | sed 's/^global\//modules\//')
    if [ "${module: -3}" != ".sh" ]; then
        module+=".sh"
    fi
    module_name=$(basename $module)
    local_modules="$(ls "$MODULAR_BASH_ROOT/local/"*.sh 2>/dev/null | sort)"
    global_modules="$(ls "$MODULAR_BASH_ROOT/modules/"*.sh 2>/dev/null | sort)"

    # Determine if the module is in the local or global folder
    if echo "$local_modules" | grep -q "/$module"; then
        if echo "$global_modules" | grep -q "/$module"; then
            echo "Duplicate module found in local and global: $module \nPlease indicate which module \
            to enable using the local/ or global/ prefix. E.g. local/$module or global/$module"
            return 1
        fi
        location="local"
    elif echo "$global_modules" | grep -q "$module"; then
        location="global"
    else
        echo "Module not found: $1"
        return 1
    fi

    # If $2 is not a number, then it is not a priority and we should use the default priority
    # if there is one in the defaults map, but if not, error out and inform the user that a priority
    # must be provided.
    # If $2 is a number, then it is a priority and we should use it.
    if ! [[ $2 =~ ^[0-9]+$ ]]; then
        if [ $location = "local" ]; then
            if [ -z "${_modular_bash_local_default_priorities[$module_name]}" ]; then
                echo "No default priority set for $module_name, so a priority must be provided to enable."
                return 1
            fi
            priority=${_modular_bash_local_default_priorities[$module_name]}
            # If the module is already enabled, then inform the user and return 1
            if [ -n "${_modular_bash_enabled_local_modules[$module_name]}" ]; then
                echo "Module already enabled: $module_name"
                return 1
            fi
        else
            if [ -z "${_modular_bash_global_default_priorities[$module_name]}" ]; then
                echo "No default priority set for $module_name, so a priority must be provided to enable."
                return 1
            fi
            priority=${_modular_bash_global_default_priorities[$module_name]}
            # If the module is already enabled, then inform the user and return 1
            if [ -n "${_modular_bash_enabled_global_modules[$module_name]}" ]; then
                echo "Module already enabled: $module_name"
                return 1
            fi
        fi
    else
        priority=$2
    fi
    # ensure priority is 2 digits
    priority=$(printf "%02d" $priority)

    # If a module with the same priority and base module name is symlinked, then inform the user that
    # the module a module with the same name and priority is already enabled and return 1.
    if [ -n "$(ls "$MODULAR_BASH_ROOT/enabled/"$priority-$module_name 2>/dev/null)" ]; then
        echo "Module with the same name and priority already enabled: $module_name"
        return 1
    fi

    # Create the symlink in the enabled folder and inform the user that the module has been enabled.
    module_dir=$(echo $location | sed 's/^global/modules/')
    ln -s "../$module_dir/$module_name" "$MODULAR_BASH_ROOT/enabled/$priority-$module_name"
    _modular_bash_reload
    echo "Module enabled: $module_name"
}


# Bash function to disable a module by removing the symlink in the enabled folder based on the name of
# the module. Unfortunately, there is no way to unsource the file, so it will still be available until
# the shell is restarted or a new session/tab/shell is started. This supports providing the name of a
# module that is either a global module or a local one. The module name provided can include the .sh
# file extension, but it is not required.
function modular_bash_disable() {
    # Protect against not providing a module name
    if [ -z "$1" ]; then
        echo "No module name provided"
        return 1
    fi

    local module
    local module_name
    local location
    local modules
    local local_modules
    local all_modules
    local enabled_modules

    # reload the enabled module maps and defaults
    _modular_bash_reload_maps
    _modular_bash_parse_defaults

    #   set a local variable that holds the name of the module requested, and if it does not end in .sh,
    #  then append it to the end of the module name.
    module=$1
    if [ "${module: -3}" != ".sh" ]; then
        module+=".sh"
    fi
    module_name=$(basename $module)

    # Get the list of all modules and all enabled modules
    modules=$(ls "$MODULAR_BASH_ROOT/modules/"*.sh 2>/dev/null | sort)
    local_modules="$(ls "$MODULAR_BASH_ROOT/local/"*.sh 2>/dev/null | sort)"
    all_modules=$(echo "$modules $local_modules" | xargs -n 1 basename | sort)
    enabled_modules=$(ls "$MODULAR_BASH_ROOT/enabled/"*.sh 2>/dev/null | xargs -n 1 basename | sort)

    # determine if the module is in the local or global folder
    if echo "$local_modules" | grep -q "/$module"; then
        if echo "$global_modules" | grep -q "/$module"; then
            echo "Duplicate module found in local and global: $module \nPlease indicate which module \
            to enable using the local/ or global/ prefix. E.g. local/$module or global/$module"
            return 1
        fi
        location="local"
    elif echo "$global_modules" | grep -q "$module"; then
        location="global"
    else
        echo "Module not found: $1"
        return 1
    fi

    # determine the enabled module name based on the provided module name and location of the module
    # by looking up in the _modular_bash_enabled_${location}_modules map
    if [ $location = "local" ]; then
        enabled_module_name=${_modular_bash_enabled_local_modules[$module]}
    else
        enabled_module_name=${_modular_bash_enabled_global_modules[$module]}
    fi

    # If the module is not enabled, then inform the user and return 1
    if [ -z "$enabled_module_name" ]; then
        echo "Module not enabled: $module"
        return 1
    fi

    # Remove the symlink from the enabled folder and inform the user that the module has been disabled.
    rm "$MODULAR_BASH_ROOT/enabled/$enabled_module_name"
    # reload the enabled module maps
    _modular_bash_reload_maps

    echo "Module disabled: $module"
}

# Bash function to rename a module in either global or local modules. This will rename the file in the
# appropriate folder and update the symlink in the enabled folder if it is enabled.
# Example usage:
#   # Rename a module that is in both local and global modules using a reference to local or global
#   modular_bash_rename local/module1 local/module1-new
#   modular_bash_rename global/module2 global/module2-new
#   # Rename a module that is unique across local and global modules by just providing the module name
#   modular_bash_rename module2 module2-new
function modular_bash_rename() {
    # Protect against not providing a module name
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "No module name provided"
        return 1
    fi
    local module
    local new_module
    local module_name
    local new_module_name

    # reload the enabled module maps and defaults
    _modular_bash_reload_maps
    _modular_bash_parse_defaults

    # set a local variable that holds the name of the module requested, and if it does not end in .sh,
    # then append it to the end of the module name. Also, rename the global prefix to modules
    module=$(echo $1 | sed 's/^global\//modules\//')
    new_module=$(echo $2 | sed 's/^global\//modules\//')
    if [ "${module: -3}" != ".sh" ]; then
        module+=".sh"
    fi
    if [ "${new_module: -3}" != ".sh" ]; then
        new_module+=".sh"
    fi
    module_name=$(basename $module)
    new_module_name=$(basename $new_module)

    # Get the list of all modules and all enabled modules
    modules=$(ls "$MODULAR_BASH_ROOT/modules/"*.sh 2>/dev/null | sort)
    local_modules="$(ls "$MODULAR_BASH_ROOT/local/"*.sh 2>/dev/null | sort)"
    all_modules=$(echo "$modules $local_modules" | xargs -n 1 basename | sort)
    enabled_modules=$(ls "$MODULAR_BASH_ROOT/enabled/"*.sh 2>/dev/null | xargs -n 1 basename | sort)

    # Check if the module exists in the modules or local folder. If not, then output an error message and
    #  return 1.
    if ! echo "$all_modules" | grep -q "$module"; then
        echo "Module not found: $1"
        return 1
    fi

}


# Bash function to create a new module in the local folder. This will create a new file in the local
# folder with the provided name and then open the file in the default editor for the user to edit.
function modular_bash_new() {
    # Protect against not providing a module name
    if [ -z "$1" ]; then
        echo "No module name provided"
        return 1
    fi
    local module
    #   set a local variable that holds the name of the module requested, and if it does not end in .sh,
    #  then append it to the end of the module name.
    module=$1
    if [ "${module: -3}" != ".sh" ]; then
        module+=".sh"
    fi

    # Create the new module file in the local folder and open it in the default editor
    touch "$MODULAR_BASH_ROOT/local/$module"
    $EDITOR "$MODULAR_BASH_ROOT/local/$module"
    # reload the enabled module maps
    _modular_bash_reload_maps
}

# Bash function to change the priority of a module. This will change the name of the module to change
# the order in which the module is loaded when the shell is started. This will rename the file in the
# local or modules folder and the enabled symlink as appropriate.
function modular_bash_priority() {
    # Protect against not providing a module name
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "No module name provided"
        return 1
    fi
    local module
    local new_module
    local new_priority
    local module_name
    local new_module_name
    local location
    # reload the enabled module maps and defaults
    _modular_bash_reload_maps
    _modular_bash_parse_defaults

    # set a local variable that holds the name of the module requested, and if it does not end in .sh,
    # then append it to the end of the module name. Also, rename the global prefix to modules
    module=$(echo $1 | sed 's/^global\//modules\//')
    new_priority=$2
    if [ "${module: -3}" != ".sh" ]; then
        module+=".sh"
    fi

    # determine if the module is in the local or global folder
    if echo "$local_modules" | grep -q "/$module"; then
        if echo "$modules" | grep -q "/$module"; then
            echo "Duplicate module found in local and global: $module \nPlease indicate which module \
            to enable using the local/ or global/ prefix. E.g. local/$module or global/$module"
            return 1
        fi
        location="local"
    elif echo "$modules" | grep -q "$module"; then
        location="global"
    else
        echo "Module not found: $1"
        return 1
    fi

    # Get the name of the enabled module based on the provided module name and location of the module
    # by looking up in the _modular_bash_enabled_${location}_modules map
    if [ $location = "local" ]; then
        enabled_module_name=${_modular_bash_enabled_local_modules[$module]}
    else
        enabled_module_name=${_modular_bash_enabled_global_modules[$module]}
    fi
    # If the module is not enabled, then inform the user and return 1
    if [ -z "$enabled_module_name" ]; then
        echo "Module not enabled: $module, instead of changing priority, enable the module with the new priority"
        return 1
    fi

    # ensure that new_priority is a number and is between 0 and 99
    if ! [[ $new_priority =~ ^[0-9]+$ ]] ; then
        echo "Priority must be a number"
        return 1
    fi
    if [ $new_priority -lt 0 ] || [ $new_priority -gt 99 ] ; then
        echo "Priority must be between 0 and 99"
        return 1
    fi
    # left pad new_priority with 0s to ensure it is 2 digits
    new_priority=$(printf "%02d" $new_priority)

    module_name=$(basename $module)

    $current_priority=${_modular_bash_enabled_module_priorities[$enabled_module_name]}
    # Remove the old symlink from the enabled folder and create a new symlink with the new priority
    rm "$MODULAR_BASH_ROOT/enabled/$enabled_module_name"
    $location_dir=$(echo $location | sed 's/^global\//modules\//')
    ln -s "../$location_dir/$module_name" "$MODULAR_BASH_ROOT/enabled/$new_priority-$module_name"
    # Update the priority in the enabled modules maps
    _modular_bash_set_enabled_module "$MODULAR_BASH_ROOT/enabled/$new_priority-$module_name"
}

# Bash function that just outputs the contents of a module file.
function modular_bash_cat() {
    # Protect against not providing a module name
    if [ -z "$1" ]; then
        echo "No module name provided"
        return 1
    fi
    local module
    local module_name
    #   set a local variable that holds the name of the module requested, and if it does not end in .sh,
    #  then append it to the end of the module name.
    module=$1
    module=$(echo $1 | sed 's/^global\//modules\//')
    if [ "${module: -3}" != ".sh" ]; then
        module+=".sh"
    fi
    module_name=$(basename $module)

    # Output the contents of the module file
    if echo "$local_modules" | grep -q "/$module"; then
        if echo "$modules" | grep -q "/$module"; then
            echo "Duplicate module found in local and global: $module \nPlease indicate which module \
            to view using the local/ or global/ prefix. E.g. local/$module or global/$module"
            return 1
        fi
        cat "$MODULAR_BASH_ROOT/local/$module_name"
        echo
    elif echo "$modules" | grep -q "$module"; then
        cat "$MODULAR_BASH_ROOT/modules/$module_name"
        echo
    else
        echo "Module not found: $1"
        return 1
    fi

}

# Bash function that opens a module file in the default editor.
function modular_bash_edit() {
    # Protect against not providing a module name
    if [ -z "$1" ]; then
        echo "No module name provided"
        return 1
    fi
    local module
    local module_name
    #   set a local variable that holds the name of the module requested, and if it does not end in .sh,
    #  then append it to the end of the module name.
    module=$1
    module=$(echo $1 | sed 's/^global\//modules\//')
    if [ "${module: -3}" != ".sh" ]; then
        module+=".sh"
    fi
    module_name=$(basename $module)

    # Edit the contents of the module file
    if echo "$local_modules" | grep -q "/$module"; then
        if echo "$modules" | grep -q "/$module"; then
            echo "Duplicate module found in local and global: $module \nPlease indicate which module \
            to edit using the local/ or global/ prefix. E.g. local/$module or global/$module"
            return 1
        fi
        $EDITOR "$MODULAR_BASH_ROOT/local/$module_name"
    elif echo "$modules" | grep -q "$module"; then
        $EDITOR "$MODULAR_BASH_ROOT/modules/$module_name"
    else
        echo "Module not found: $1"
        return 1
    fi
}

# Bash function to initialize the modular bash environment. This will create a modular-bash.sh file
# in local modules and enable it with 0 priority. This file will have a default priority of 0 and
# will be sourced by the modular_profile_loader.sh file to initialize the modular bash environment.
# The contents of this file is just a MODULAR_BASH_ROOT variable that points to the root of the modular
# bash installation.
function modular_bash_init() {
    touch "$(dirname "${BASH_SOURCE[0]}")/local/modular-bash.sh"
    curdir=$(pwd)
    MODULAR_BASH_ROOT=$(echo "$curdir/$(dirname "${BASH_SOURCE[0]}")/")
    echo "export MODULAR_BASH_ROOT=$MODULAR_BASH_ROOT" > "$(dirname "${BASH_SOURCE[0]}")/local/modular-bash.sh"
    modular_bash_enable local/modular-bash.sh 0
    echo "Modular bash environment initialized"
}

# Bash completion function to complete the module names for the enable function. This
# will complete the module names based on all the .sh files in the modules or local folder, excluding
# the README.md files. This only outputs the filename of the module (without the file extension)
# and not the full path for modules that are not enabled.
function _complete_modular_bash_enable() {
    local cur
    local completions
    local completions_short
    # reload the enabled module maps and defaults
    _modular_bash_reload_maps
    _modular_bash_parse_defaults

    #   set a local variable that holds the current word being completed
    cur=${COMP_WORDS[COMP_CWORD]}
    # Get the list of all modules and all enabled modules
    modules=$(ls "$MODULAR_BASH_ROOT/modules/"*.sh 2>/dev/null | xargs -n1 basename | sort)
    local_modules="$(ls "$MODULAR_BASH_ROOT/local/"*.sh 2>/dev/null | xargs -n1 basename | sort)"
    for module in $modules; do
        if [ -n "${_modular_bash_enabled_global_modules[$module]}" ]; then
            continue
        fi
        completions_short+=$(basename $module | sed 's/\.sh//g')$'\n'
        completions+="global/"$(basename $module | sed 's/\.sh//g')$'\n'
    done
    for module in $local_modules; do
        if [ -n "${_modular_bash_enabled_local_modules[$module]}" ]; then
            continue
        fi
        completions_short+=$(basename $module | sed 's/\.sh//g')$'\n'
        completions+="local/"$(basename $module | sed 's/\.sh//g')$'\n'
    done
    completions=$(echo "$completions" | sort)
    completions_short=$(echo "$completions_short" | sort)
    completions=$(echo "$completions_short $completions")
    COMPREPLY=($(compgen -W "$completions" -- "$cur"))
}

# Register the completion function for the enable function
complete -F _complete_modular_bash_enable modular_bash_enable

# Bash completion function for the disable function. This will complete the module names based on all
# the .sh files in the enabled folder, excluding the README.md files. This only outputs the filename
# of the module (without the file extension) and not the full path for modules that are enabled.
function _complete_modular_bash_disable() {
    local cur
    local completion_modules
    local completion_modules_short

    # set a local variable that holds the current word being completed
    cur=${COMP_WORDS[COMP_CWORD]}
    # Get the list of all modules and all enabled modules
    enabled_modules=$(ls "$MODULAR_BASH_ROOT/enabled/"*.sh 2>/dev/null | xargs -n 1 basename | sort)
    # iterate through enabled_modules and lookup the location of the module in the _modular_bash_enabled_module_locations map
    # and the module name in the _modular_bash_enabled_module_names map to get the full module name with the location prefix
    # and add it to completion_modules list
    completion_modules=""
    completion_modules_short=""
    for enabled_module in $enabled_modules; do
        location=${_modular_bash_enabled_module_locations[$enabled_module]}
        module_name=${_modular_bash_enabled_module_names[$enabled_module]}
        completion_modules+="$location/$module_name "
        completion_modules_short+="$module_name "
    done
    completion_modules=$(echo $completion_modules | sort)
    completion_modules_short=$(echo $completion_modules_short | sort)

    completions=$(echo "$completion_modules $completion_modules_short" | sed 's/\.sh//g')

    # Use compgen to generate possible completions
    COMPREPLY=($(compgen -W "$completions" -- "$cur"))
}

# Register the completion function for the disable function
complete -F _complete_modular_bash_disable modular_bash_disable

# Bash completion function for the rename function. This will complete the module names based on all the
# .sh files in the modules and local folder, excluding the README.md files. This should complete on the
# module name with and without the .sh file extension, as well as with or without the local/ or global/
# prefix. This only outputs the filename of the module (without the file extension) and not the full path.
function _complete_modular_bash_all_modules() {
    local cur
    #   set a local variable that holds the current word being completed
    cur=${COMP_WORDS[COMP_CWORD]}
    # Get the list of all modules and all enabled modules
    modules=$(ls "$MODULAR_BASH_ROOT/modules/"*.sh 2>/dev/null | sort)
    local_modules="$(ls "$MODULAR_BASH_ROOT/local/"*.sh 2>/dev/null | sort)"
    all_modules=$(echo "$modules $local_modules" | xargs -n 1 basename | sort | uniq | sed 's/\.sh$//')
    # Generate the list of all of the local and global modules with their respective prefixes
    local_module_refs=$(echo "$local_modules" | xargs -n 1 basename | sed 's/^/local\//' | sort)
    global_module_refs=$(echo "$modules" | xargs -n 1 basename | sed 's/^/global\//' | sort)
    all_module_refs=$(echo "$all_modules $global_module_refs $local_module_refs")
    # Use compgen to generate possible completions
    COMPREPLY=($(compgen -W "$all_module_refs" -- "$cur"))
}

# Register the completion function for the functions that work on any module
complete -F _complete_modular_bash_all_modules modular_bash_rename
complete -F _complete_modular_bash_all_modules modular_bash_priority
complete -F _complete_modular_bash_all_modules modular_bash_cat
complete -F _complete_modular_bash_all_modules modular_bash_edit
