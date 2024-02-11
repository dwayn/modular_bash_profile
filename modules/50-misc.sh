alias sep='echo -e "\n\n\e[1;34m#################################\e[m\n\e[1;34m############## SEP ##############\e[m\n\e[1;34m#################################\e[m\n\n"'

alias home-wsl='ssh 192.168.1.35'

function prompt_yn()
{
    local prompt="${1:-"Continue?"}"
    local default="${2:-"Y"}"
    local choices
    local input

    if [[ "$default" = [Nn] ]]; then
        choices="[y/N]"
    elif [[ "$default" = [Yy] ]]; then
        choices="[Y/n]"
    else
        choices="[y/n]"
    fi

    while :; do
        read -r -p "${prompt} ${choices}: " input
        input="${input:-$default}"

        case "$input" in
            [Yy]) return 0 ;;
            [Nn]) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

