# Brew installed curl paths
export LDFLAGS="$LDFLAGS -L/opt/homebrew/opt/curl/lib"
export CPPFLAGS="$CPPFLAGS -I/opt/homebrew/opt/curl/include"
export PKG_CONFIG_PATH="/opt/homebrew/opt/curl/lib/pkgconfig"

export PATH="/opt/homebrew/opt/curl/bin:$PATH"
