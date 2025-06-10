# Git Things
gitrb() {
    local default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "master")
    git pull --rebase origin "$default_branch"
}

gitrbp() {
    local default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "master")
    git pull --rebase origin "$default_branch" && git push
}

alias gitfp='git fetch && git reset --hard FETCH_HEAD'
