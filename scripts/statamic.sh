#!/usr/bin/env bash

set -e

statamic=/root/.config/composer/vendor/statamic/cli/bin/statamic

echo "$statamic $*@"

$statamic "$@"