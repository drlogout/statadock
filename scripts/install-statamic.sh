#!/usr/bin/env bash

set -e

# Check if parameter is set
if [ -z "$1" ]; then
    echo "Usage: $0 <project-name>"
    exit 1
fi

function is_install_dir_empty() {
    if [ "$(ls -A $install_dir)" ]; then
        return 1
    else
        return 0
    fi
}

name=$1
starter_kit=$2
install_dir=/var/www/html

if is_install_dir_empty; then
    cd /tmp || exit 1
    set +e
    /usr/local/bin/statamic new "$name" "$starter_kit"
    set -e
else
    echo "Mounted Directory $install_dir is not empty. Exiting."
    exit 1
fi

printf "\nCopying files to %s, this my take a while...\n" "$install_dir"
rsync -a /tmp/"$name"/ "$install_dir"/
rm -rf /tmp/"$name"
echo "Done."