#!/usr/bin/env bash
# Reset datahub GraphQL cache
set -euo pipefail

target_user="${CACHE_RESET_USER:-www-data}"
console_bin="${PIMCORE_CONSOLE_BIN:-bin/console}"
php_bin="${PHP_BIN:-php}"

cd "/var/www/pimcore" || {
	echo "Failed to change directory to /var/www/pimcore" >&2
	exit 1
}

sudo -E -u "$target_user" "$php_bin" "$console_bin" cache:pool:invalidate-tags datahub
