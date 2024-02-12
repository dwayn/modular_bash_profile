# pyenv things
#eval "$(pyenv init -)"
#eval "$(pyenv virtualenv-init -)"

#if which pyenv-virtualenv-init > /dev/null; then eval "$(pyenv virtualenv-init -)"; fi

export PYENV_ROOT="$HOME/.pyenv"
if [[ "${FASTLOAD:-0}" -ne 1 ]] && which pyenv &>/dev/null; then
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"
    pyenv shell '3.11.1' '2.7.18'
fi

export PATH=$HOME/.pyenv/shims:$HOME/bin:$PATH