#!/usr/bin/env bash
# Usage: maint-login-merge <user> <cd_target> [cmd [args...]]
#   Interactive:     maint-login-merge maintainer /var/www/pimcore
#   Non-interactive: maint-login-merge maintainer /var/www/pimcore git status
set -euo pipefail

if [[ $# -lt 1 ]]; then
	echo "Usage: $0 <user> <cd_target> [cmd [args...]]" >&2
	exit 2
fi

user="$1"
cd_target="${2:-}"
shift; shift 2>/dev/null || shift $# # consume user + cd_target
# Remaining args ($@) are the command to run (empty = interactive shell)

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

if [[ $# -gt 0 ]]; then
	# Non-interactive: run the given command as the user.
	# Build a properly escaped command string for su -c.
	# The login shell sources .profile (which cd's to MAINTAINER_CWD),
	# but we cd explicitly as well for safety.
	cmd_str=""
	if [[ -n "$cd_target" ]]; then
		cmd_str="cd $(printf '%q' "$cd_target") && "
	fi
	cmd_str+="exec"
	for arg in "$@"; do
		cmd_str+=" $(printf '%q' "$arg")"
	done
	exec su "${su_args[@]}" -c "$cmd_str"
else
	exec su "${su_args[@]}"
fi
