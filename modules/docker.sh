alias clean-docker="docker ps -a | grep -v 'CONTAINER ID' | awk '{print $1}' | xargs -L1 docker rm"

