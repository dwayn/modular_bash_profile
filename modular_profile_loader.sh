# Root bash profile script that should be sourced from your automatically sourced profile file
#   ~/.bash_profile
#   ~/.profile
#   ~/.bashrc

# Add this line to whichever profile file from above you use
# source /path/to/modular_bash_profile/modular_profile_loader.sh


_modular_bash_reload() {
    local notify
    notify=${1:-false}
    # Iterate through all the files in the enabled folder and source them to load/reload them
    for file in "$(dirname "${BASH_SOURCE[0]}")/enabled/"*; do
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

# Bash function to list all of the available modules based on all the .sh files in the modules and
# all of the .sh files in the local folder, excluding the README.md files and should be a full
# sorted list across both folders. This should only output the filename of the module (without the
# file extension) and not the full path. In addition, if a module is enabled, it should be marked
# with a * at the start of the line (if not enabled, include an extra whitespace in front so they
# align vertically). Also, include (L) for local modules and (G) for global modules, and if a module
# is in both, then it should be marked with (L/G). The list should be sorted alphabetically by module
# name. The overall format is as follows:
#   * (L)   module1
#     (G)   module2
#     (L/G) module3
#   * (L/G) module4
function modular_bash_list() {
    # Get the list of all modules and all enabled modules
    modules=$(ls "$(dirname "${BASH_SOURCE[0]}")/modules/"*.sh 2>/dev/null | sort)
    local_modules="$(ls "$(dirname "${BASH_SOURCE[0]}")/local/"*.sh 2>/dev/null | sort)"
    all_modules=$(echo "$modules $local_modules" | xargs -n 1 basename | sort)
    enabled_modules=$(ls "$(dirname "${BASH_SOURCE[0]}")/enabled/"*.sh 2>/dev/null | xargs -n 1 basename | sort)

    # Iterate through all the modules and check if they are enabled or not and if they are local or
    # global. Then output the module name with the appropriate formatting.
    for module in $all_modules; do
        if echo "$local_modules" | grep -q "$module"; then
            if echo "$modules" | grep -q "$module"; then
                local_mark="(L/G)"
            else
                local_mark="(L)  "
            fi
        else
            local_mark="(G)  "
        fi
        if echo "$enabled_modules" | grep -q "$module"; then
            echo "* $local_mark ${module%.sh}"
        else
            echo "  $local_mark ${module%.sh}"
        fi
    done
}


# Bash function to enable a module by creating a symlink in the enabled folder based on the name of
# the module. This will also source the module after creating the symlink so that it is immediately
# available. This supports providing the name of a module that is either in the modules folder or
# the local folder. If the module name provided does not include the .sh file extension, it will be
# appended automatically.
function modular_bash_enable() {
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

    # Get the list of all modules and all enabled modules
    modules=$(ls "$(dirname "${BASH_SOURCE[0]}")/modules/"*.sh 2>/dev/null | sort)
    local_modules="$(ls "$(dirname "${BASH_SOURCE[0]}")/local/"*.sh 2>/dev/null | sort)"
    all_modules=$(echo "$modules $local_modules" | xargs -n 1 basename | sort)
    enabled_modules=$(ls "$(dirname "${BASH_SOURCE[0]}")/enabled/"*.sh 2>/dev/null | xargs -n 1 basename | sort)

    # Check if the module exists in the modules or local folder. If not, then output an error message and
    #  return 1.
    if ! echo "$all_modules" | grep -q "$module"; then
        echo "Module not found: $1"
        return 1
    fi

    if echo "$enabled_modules" | grep -q "$module"; then
        echo "Module already enabled: $module"
        return 1
    fi

    # If the module exists in the local_modules, symlink that one in the enabled folder. Otherwise,
    #  symlink the module from the modules folder. If a module exists in both the local and modules
    #  folder, the local one will be the one symlinked to allow a user to override a provided module.
    if echo "$local_modules" | grep -q "$module"; then
        if echo "$modules" | grep -q "$module"; then
            echo "Duplicate module found in local and global: $module \nPlease indicate which module \
            to enable using the local/ or global/ prefix. E.g. local/$module or global/$module"
            return 1
        else
        ln -s "../local/$module_name" "$(dirname "${BASH_SOURCE[0]}")/enabled/$module_name"
        fi
    else
        ln -s "../modules/$module_name" "$(dirname "${BASH_SOURCE[0]}")/enabled/$module_name"
    fi
    # Source the module after creating the symlink so that it is immediately available and inform the
    #  user that the module has been enabled.
    source "$(dirname "${BASH_SOURCE[0]}")/enabled/$module_name"
    echo "Module enabled: $module"
}



# Bash function to disable a module by removing the symlink in the enabled folder based on the name of
# the module. Unfortunately, there is no way to unsource the file, so it will still be available until
# the shell is restarted or a new session/tab/shell is started. This supports providing the name of a
# module that is either a provided module or a local one. The module name provided can include the .sh
# file extension, but it is not required.
function modular_bash_disable() {
    local module
    #   set a local variable that holds the name of the module requested, and if it does not end in .sh,
    #  then append it to the end of the module name.
    module=$1
    if [ "${module: -3}" != ".sh" ]; then
        module+=".sh"
    fi


    # Get the list of all modules and all enabled modules
    modules=$(ls "$(dirname "${BASH_SOURCE[0]}")/modules/"*.sh 2>/dev/null | sort)
    local_modules="$(ls "$(dirname "${BASH_SOURCE[0]}")/local/"*.sh 2>/dev/null | sort)"
    all_modules=$(echo "$modules $local_modules" | xargs -n 1 basename | sort)
    enabled_modules=$(ls "$(dirname "${BASH_SOURCE[0]}")/enabled/"*.sh 2>/dev/null | xargs -n 1 basename | sort)

    # Check if the module exists in the modules or local folder. If not, then output an error message and
    #  return 1.
    if ! echo "$all_modules" | grep -q "$module"; then
        echo "Module not found: $1"
        # If the module does have a symlink in the enabled folder, then remove it and inform the user
        #  that the module has been disabled.
        if echo "$enabled_modules" | grep -q "$module"; then
            rm "$(dirname "${BASH_SOURCE[0]}")/enabled/$module"
            echo "Disabled missing module: $module"
        fi
        return 1
    fi

    if ! echo "$enabled_modules" | grep -q "$module"; then
        echo "Module not enabled: $module"
        return 1
    fi

    # Remove the symlink from the enabled folder and inform the user that the module has been disabled.
    rm "$(dirname "${BASH_SOURCE[0]}")/enabled/$module"
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
    modules=$(ls "$(dirname "${BASH_SOURCE[0]}")/modules/"*.sh 2>/dev/null | sort)
    local_modules="$(ls "$(dirname "${BASH_SOURCE[0]}")/local/"*.sh 2>/dev/null | sort)"
    all_modules=$(echo "$modules $local_modules" | xargs -n 1 basename | sort)
    enabled_modules=$(ls "$(dirname "${BASH_SOURCE[0]}")/enabled/"*.sh 2>/dev/null | xargs -n 1 basename | sort)

    # Check if the module exists in the modules or local folder. If not, then output an error message and
    #  return 1.
    if ! echo "$all_modules" | grep -q "$module"; then
        echo "Module not found: $1"
        return 1
    fi


    if echo "$local_modules" | grep -q "$module"; then
        if echo "$modules" | grep -q "$module"; then
            echo "Duplicate module found in local and global: $module \nPlease indicate which module \
            to rename using the local/ or global/ prefix. E.g. local/$module or global/$module"
            return 1
        else
            # Rename local module
            mv "$(dirname "${BASH_SOURCE[0]}")/local/$module_name" "$(dirname "${BASH_SOURCE[0]}")/local/$new_module_name"
        fi
    elif echo "$modules" | grep -q "$module"; then
        # Rename global module
        mv "$(dirname "${BASH_SOURCE[0]}")/modules/$module_name" "$(dirname "${BASH_SOURCE[0]}")/modules/$new_module_name"
    else
        echo "Module not found: $1"
        return 1
    fi


    # If the module is enabled, then remove the symlink from the enabled folder and create a new
    #  symlink with the new module name.
    if echo "$enabled_modules" | grep -q "$module_name"; then
        rm "$(dirname "${BASH_SOURCE[0]}")/enabled/$module_name"
        # Create the new symlink in the enabled folder
        if echo "$local_modules" | grep -q "$new_module"; then
            ln -s "../local/$new_module" "$(dirname "${BASH_SOURCE[0]}")/enabled/$new_module"
        else
            ln -s "../modules/$new_module" "$(dirname "${BASH_SOURCE[0]}")/enabled/$new_module"
        fi
    fi
    echo "Module renamed: $module_name -> $new_module_name"
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
    touch "$(dirname "${BASH_SOURCE[0]}")/local/$module"
    $EDITOR "$(dirname "${BASH_SOURCE[0]}")/local/$module"
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

    # set a local variable that holds the name of the module requested, and if it does not end in .sh,
    # then append it to the end of the module name. Also, rename the global prefix to modules
    module=$(echo $1 | sed 's/^global\//modules\//')
    new_priority=$2
    if [ "${module: -3}" != ".sh" ]; then
        module+=".sh"
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
    new_module_name=$(echo "$module_name" | sed "s/^[0-9]\{1,\}/$new_priority/")
    new_module=$(echo "$module" | sed "s/$module_name/$new_module_name/")

    # Rename the module with its new priority
    modular_bash_rename $module $new_module
}



# Bash completion function to complete the module names for the enable function. This
# will complete the module names based on all the .sh files in the modules or local folder, excluding
# the README.md files. This only outputs the filename of the module (without the file extension)
# and not the full path for modules that are not enabled.
function _complete_modular_bash_enable() {
    local cur
    #   set a local variable that holds the current word being completed
    cur=${COMP_WORDS[COMP_CWORD]}
    # Get the list of all modules and all enabled modules
    modules=$(ls "$(dirname "${BASH_SOURCE[0]}")/modules/"*.sh 2>/dev/null | sort)
    local_modules="$(ls "$(dirname "${BASH_SOURCE[0]}")/local/"*.sh 2>/dev/null | sort)"
    all_modules=$(echo "$modules $local_modules" | xargs -n 1 basename | sort | uniq | sed 's/\.sh$//')
    enabled_modules=$(ls "$(dirname "${BASH_SOURCE[0]}")/enabled/"*.sh 2>/dev/null | xargs -n 1 basename | sort | sed 's/\.sh$//')
    # Filter the enabled modules from the all_modules list for completions
    completions=$(comm -23 <(echo "$all_modules") <(echo "$enabled_modules"))
    # Use compgen to generate possible completions
    COMPREPLY=($(compgen -W "$completions" -- "$cur"))
}

# Register the completion function for the enable function
complete -F _complete_modular_bash_enable modular_bash_enable

# Bash completion function for the disable function. This will complete the module names based on all
# the .sh files in the enabled folder, excluding the README.md files. This only outputs the filename
# of the module (without the file extension) and not the full path for modules that are enabled.
function _complete_modular_bash_disable() {
    local cur
    #   set a local variable that holds the current word being completed
    cur=${COMP_WORDS[COMP_CWORD]}
    # Get the list of all modules and all enabled modules
    enabled_modules=$(ls "$(dirname "${BASH_SOURCE[0]}")/enabled/"*.sh 2>/dev/null | xargs -n 1 basename | sort | sed 's/\.sh$//')
    # Use compgen to generate possible completions
    COMPREPLY=($(compgen -W "$enabled_modules" -- "$cur"))
}

# Register the completion function for the disable function
complete -F _complete_modular_bash_disable modular_bash_disable

# Bash completion function for the rename function. This will complete the module names based on all the
# .sh files in the modules and local folder, excluding the README.md files. This should complete on the
# module name with and without the .sh file extension, as well as with or without the local/ or global/
# prefix. This only outputs the filename of the module (without the file extension) and not the full path.
function _complete_modular_bash_rename() {
    local cur
    #   set a local variable that holds the current word being completed
    cur=${COMP_WORDS[COMP_CWORD]}
    # Get the list of all modules and all enabled modules
    modules=$(ls "$(dirname "${BASH_SOURCE[0]}")/modules/"*.sh 2>/dev/null | sort)
    local_modules="$(ls "$(dirname "${BASH_SOURCE[0]}")/local/"*.sh 2>/dev/null | sort)"
    all_modules=$(echo "$modules $local_modules" | xargs -n 1 basename | sort | uniq | sed 's/\.sh$//')
    # Generate the list of all of the local and global modules with their respective prefixes
    local_module_refs=$(echo "$local_modules" | xargs -n 1 basename | sed 's/^/local\//' | sort)
    global_module_refs=$(echo "$modules" | xargs -n 1 basename | sed 's/^/global\//' | sort)
    all_module_refs=$(echo "$all_modules $global_module_refs $local_module_refs")
    # Use compgen to generate possible completions
    COMPREPLY=($(compgen -W "$all_module_refs" -- "$cur"))
}

# Register the completion function for the rename function
complete -F _complete_modular_bash_rename modular_bash_rename
complete -F _complete_modular_bash_rename modular_bash_priority