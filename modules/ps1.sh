# Git PS1
function setup_git_ps1() {
    if ! [[ -d "${HOME}/.git-prompt" ]]; then
        mkdir "${HOME}/.git-prompt" && curl \
            "https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh" \
            -o "${HOME}/.git-prompt/git-prompt.sh"
    fi

    # PS1 colors
    _C_GITPS1='01;38;5;172m'
    _C_PWD="38;5;220;1m"
    _C_HOST="38;5;99m"
    #_C_GITPS1='0;32m'

    if ! [[ -f "${HOME}/.git-prompt/git-prompt.sh" ]]; then
        echo "Failed to find/download git-prompt.sh."
        GIT_PS1=''
    else
        source "${HOME}/.git-prompt/git-prompt.sh"
        export GIT_PS1_SHOWDIRTYSTATE=1 GIT_PS1_SHOWSTASHSTATE=1 GIT_PS1_SHOWUPSTREAM="git" GIT_PS1_SHOWCOLORHINTS=1
        # Note the single quotes here; important!
        GIT_PS1='\[\e['${_C_GITPS1}'\]$(__git_ps1 "[%s]")\[\e[m\]'
    fi

    #if [ -f "/usr/local/opt/bash-git-prompt/share/gitprompt.sh" ]; then
    #  __GIT_PROMPT_DIR="/usr/local/opt/bash-git-prompt/share"
    #  GIT_PROMPT_THEME=Solarized
    #  source "/usr/local/opt/bash-git-prompt/share/gitprompt.sh"
    #fi
}
setup_git_ps1

# export PS1='\[\e['${_C_HOST}'\]${USER//dwayn/(╯°□°)╯︵ uʎɐʍp}:\[\e['${_C_PWD}'\]\w'"$GIT_PS1"'\[\e[m\]\[\e[0;35m\]\[\e[m\]\[\e[1;32m\]'$'\xe2\xa6\x95'"\[\e[m\] "
# export PS1='\[\e['${_C_HOST}'\]${USER//dwayn/(ノಠ益ಠ)ノ彡 uʎɐʍp}:\[\e['${_C_PWD}'\]\w'"$GIT_PS1"'\[\e[m\]\[\e[0;35m\]\[\e[m\]\[\e[1;32m\]'$'\xe2\xa6\x95'"\[\e[m\] "

# check if PS1_STUB and PS1_STUB_REPLACEMENT are set and if so, replace the stub with the replacement
if [[ -n "${PS1_STUB}" ]] && [[ -n "${PS1_STUB_REPLACEMENT}" ]]; then
    export PS1='\[\e['${_C_HOST}'\]${USER//${PS1_STUB}/${PS1_STUB_REPLACEMENT}}:\[\e['${_C_PWD}'\]\w'"$GIT_PS1"'\[\e[m\]\[\e[0;35m\]\[\e[m\]\[\e[1;32m\]'$'\xe2\xa6\x95'"\[\e[m\] "
else
    export PS1='\[\e['${_C_HOST}'\]${USER}:\[\e['${_C_PWD}'\]\w'"$GIT_PS1"'\[\e[m\]\[\e[0;35m\]\[\e[m\]\[\e[1;32m\]'$'\xe2\xa6\x95'"\[\e[m\] "
fi
