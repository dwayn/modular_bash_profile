function ssh_check_agent() {
    if [[ ! -S ~/.ssh/ssh_auth_sock ]]; then
        eval "$(ssh-agent)"
        ln -sf "$SSH_AUTH_SOCK" ~/.ssh/ssh_auth_sock
	ssh-add -A;
    fi

    export SSH_AUTH_SOCK=~/.ssh/ssh_auth_sock
}

function ssh_add_keychain() {
    if [[ -z "$1" ]]; then
        echo "Usage: ssh_add_keychain [path-to-private-key]";
        return 1;
    fi

    ssh-add --apple-use-keychain "$1";
}

# ssh-add --apple-use-keychain ~/.ssh/[your-private-key]