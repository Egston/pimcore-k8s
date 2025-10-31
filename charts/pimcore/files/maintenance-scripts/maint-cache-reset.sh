#!/usr/bin/env bash
# Reset Pimcore cache: retries cache:clear until it succeeds, then warms cache
set -euo pipefail

target_user="${CACHE_RESET_USER:-www-data}"
memory_limit="${CACHE_RESET_MEMORY_LIMIT:-2G}"
console_bin="${PIMCORE_CONSOLE_BIN:-bin/console}"
php_bin="${PHP_BIN:-php}"
retry_delay="${CACHE_RESET_RETRY_DELAY:-1}"

cd "/var/www/pimcore" || {
	echo "Failed to change directory to /var/www/pimcore" >&2
	exit 1
}

clear_cmd=(sudo -E -u "$target_user" "$php_bin" -d "memory_limit=${memory_limit}" "$console_bin" cache:clear --no-warmup)
warmup_cmd=(sudo -E -u "$target_user" "$php_bin" -d "memory_limit=${memory_limit}" "$console_bin" cache:warmup)

while true; do
	if "${clear_cmd[@]}"; then
		break
	fi
	echo "cache:clear failed; retrying in ${retry_delay}s..." >&2
	sleep "$retry_delay"
done

"${warmup_cmd[@]}"
