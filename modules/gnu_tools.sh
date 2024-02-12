# Add gnu tools to the path
PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"
# putting coreutils things in the path before the
# bsd ones can apparently cause issues
# PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"

alias tac="gtac"

export CFLAGS="-I$(xcrun --show-sdk-path)/usr/include"
