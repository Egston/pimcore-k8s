#!/usr/bin/env bash
# Usage: maint-login-merge <user> [cd_target]
set -euo pipefail

if [[ $# -lt 1 ]]; then
	echo "Usage: $0 <user> [cd_target]" >&2
	exit 2
fi

user="$1"
cd_target="${2:-}"

# Get the *names* of variables in the maintainer's true login env
login_names="$(
	env -i su -l "$user" -s /bin/sh -c 'env | cut -d= -f1 | LC_ALL=C sort -u'
)"

# Names in current (container) env
container_names="$(env | cut -d= -f1 | LC_ALL=C sort -u)"

# Compute container-only env names (login takes precedence on collisions)
# Drop noisy session vars; remove the grep if you want literally everything.
extras_names_raw="$(
	comm -13 \
		<(printf '%s\n' "$login_names") \
		<(printf '%s\n' "$container_names") |
		grep -Ev '^(PWD|OLDPWD|SHLVL|_)$' || true
)"

extras_names_combined="$extras_names_raw"
if [[ -n "${cd_target}" ]]; then
	export MAINTAINER_CWD="$cd_target"
	extras_names_combined="$(printf '%s\n%s\n' "$extras_names_combined" "MAINTAINER_CWD")"
fi

extras_clean="$(printf '%s\n' "$extras_names_combined" | grep -Ev '^\s*$' || true)"

if [[ -n "$extras_clean" ]]; then
	extras_csv="$(printf '%s\n' "$extras_clean" | LC_ALL=C sort -u | paste -sd, -)"
else
	extras_csv=""
fi

su_args=(-l "$user" --shell /bin/bash)
if [[ -n "${extras_csv}" ]]; then
	su_args+=(--whitelist-environment="$extras_csv")
fi
exec su "${su_args[@]}"
