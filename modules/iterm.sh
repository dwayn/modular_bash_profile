test -e "${HOME}/.iterm2_shell_integration.bash" && source "${HOME}/.iterm2_shell_integration.bash"

# Iterm things
function tabdefault()
{
    tabtitle
    tabcolor default
}

function tabtitle()
{
    TABTITLE="${1:- }"

    echo -en '\ek'${TABTITLE}'\e\\'
}

# function tabrgb()
# {
#     # Blue and yellow purple tabs...
#     echo -en "\e]6;1;bg;*;default\a"
#     echo -en "\e]6;1;bg;red;brightness;${1}\a"
#     echo -en "\e]6;1;bg;green;brightness;${2}\a"
#     echo -en "\e]6;1;bg;blue;brightness;${3}\a"
# }

function tabrgb()
{
    # Blue and yellow purple tabs...
    echo -en "\033]6;1;bg;*;default\a"
    echo -en "\033]6;1;bg;red;brightness;${1}\a"
    echo -en "\033]6;1;bg;green;brightness;${2}\a"
    echo -en "\033]6;1;bg;blue;brightness;${3}\a"
}


function tabcolor()
{
    MYFUNCNAME="$FUNCNAME"
    function tabcolor_usage() {
        echo "Usage: ${MYFUNCNAME} [random|purple|blue|lightblue|darkblue|orange|green|lightgreen|darkgreen|red|gold|brown|lightbrown|shitbrown]" >&2
        kill -INT $$
        return 1
    }

    function set_tab_default()
    {
        echo -en "\033]6;1;bg;*;default\a"
    }

    COLOR="$1"

    # Aliases
    [ -z "$COLOR" ] && COLOR="random"
    [ "$COLOR" = "brightblue" ] && COLOR="lightblue"
    [ "$COLOR" = "brightgreen" ] && COLOR="lightgreen"
    [ "$COLOR" = "shitbrown" ] && COLOR="brown"

    case "$COLOR" in
        "purple") tabrgb 155 48 255 ;;
        "blue") tabrgb 81 134 255 ;;
        "lightblue") tabrgb 30 144 255 ;;
        "darkblue") tabrgb 0 0 205 ;;
        "orange") tabrgb 255 153 51 ;;
        "green") tabrgb 0 204 0 ;;
        "lightgreen") tabrgb 124 252 0 ;;
        "darkgreen") tabrgb 34 139 34 ;;
        "pink") tabrgb 255 51 183 ;;
        "red") tabrgb 255 51 51 ;;
        "gold") tabrgb 255 215 0 ;;
        "brown") tabrgb 134 34 11 ;;
        "lightbrown") tabrgb 205 133 63 ;;
        "default") set_tab_default ;;
        "random")
            tabrgb \
                "$(od -A n -N 1 -t u2 /dev/urandom)" \
                "$(od -A n -N 1 -t u2 /dev/urandom)" \
                "$(od -A n -N 1 -t u2 /dev/urandom)"
        ;;
        *) tabcolor_usage ;;
    esac
}
