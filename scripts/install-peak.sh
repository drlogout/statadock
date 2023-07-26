#!/usr/bin/env bash

set -e

# Check if parameter is set
if [ -z "$1" ]; then
    echo "Usage: $0 <project-name>"
    exit 1
fi

/usr/local/bin/install-statamic "$1" studio1902/statamic-peak   