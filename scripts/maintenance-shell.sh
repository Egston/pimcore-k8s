#!/usr/bin/env bash
set -euo pipefail

# Collect kubectl exec flags from CLI (before first non-flag or "--")
kubectl_flags=()
while [ $# -gt 0 ] && [[ "$1" == -* ]] && [ "$1" != "--" ]; do
	kubectl_flags+=("$1")
	shift
done

raw_exec=false
subcommand=""
container_command=""

# Decide mode / subcommand
if [ $# -eq 0 ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
	# Script-level help -> use maint-help inside the pod
	cat <<-EOF
		maintenance-shell.sh is a wrapper script to execute maintenance commands
		or arbitrary commands inside the pimcore-maintenance-shell pod.

		Usage:
		  maintenance-shell.sh [<kubectl-flags>] <subcommand> [<args>...]
		  maintenance-shell.sh [<kubectl-flags>] -- <command> [<args>...]
		  maintenance-shell.sh [<kubectl-flags>] down

		Modes:

		  1) Maintenance subcommands (auto-prefixed with "maint-"):

		     maintenance-shell.sh [<kubectl-flags>] <subcommand> [<args>...]

		     This will run "maint-<subcommand>" inside the pod. Known subcommands include:
		         shell                 → maint-shell
		         cache-reset           → maint-cache-reset
		         graphql-cache-reset   → maint-graphql-cache-reset
		         db-import             → maint-db-import
		         help                  → maint-help

		     Examples:
		         maintenance-shell.sh shell
		         maintenance-shell.sh cache-reset
		         maintenance-shell.sh graphql-cache-reset
		         maintenance-shell.sh db-import --dump-file /tmp/dump.sql.gz
		         maintenance-shell.sh db-import < /tmp/dump.sql.gz

		  2) Raw commands (no "maint-" prefix, no default flags):

		     maintenance-shell.sh [<kubectl-flags>] -- <command> [<args>...]

		     Everything after "--" is passed as-is to "kubectl exec --".

		     Examples:
		         maintenance-shell.sh -it -- bash
		         maintenance-shell.sh -- tail -f /var/www/pimcore/var/log/prod-error.log

		  3) Scale down the maintenance shell deployment:

		     maintenance-shell.sh [<kubectl-flags>] down

		     This scales the "pimcore-maintenance-shell" deployment down to 0 replicas
		     and exits without executing any command inside the pod.

		Where <kubectl-flags> are optional flags for 'kubectl exec' (e.g. -it, -n pimcore).
		If not specified, default sensible flags will be used for known maintenance subcommands
		(e.g. -it for "shell"), but NOT for raw commands after "--" and NOT for "down".

		To see detailed maint-help inside the pod:
		  maintenance-shell.sh help
	EOF
	exit 0

elif [ "${1:-}" = "down" ]; then
	# Special maintenance command: scale down and exit
	kubectl scale deployment/pimcore-maintenance-shell --replicas=0
	exit 0

else
	if [ "${1:-}" = "--" ]; then
		# Raw mode: arbitrary command, no maint- prefix, no default flags
		raw_exec=true
		shift
		if [ $# -eq 0 ]; then
			echo 'Error: no command specified after "--".' >&2
			exit 1
		fi
		# In raw mode we don't set container_command; we'll use "$@" directly.
	else
		# Maintenance subcommand: prefix with "maint-"
		subcommand="$1"
		container_command="maint-$subcommand"
		shift
	fi
fi

# For all modes that execute inside the pod, ensure the deployment is up
kubectl scale deployment/pimcore-maintenance-shell --replicas=1
kubectl rollout status deployment/pimcore-maintenance-shell

# Default flags if not specified on CLI, only for maintenance subcommands
if ! $raw_exec && [ "${#kubectl_flags[@]}" -eq 0 ]; then
	case "$subcommand" in
	shell | cache-reset | graphql-cache-reset)
		kubectl_flags+=(-it)
		;;
	db-import)
		kubectl_flags+=(-i)
		;;
	help)
		kubectl_flags+=(-it)
		;;
	*)
		# leave kubectl_flags empty for unknown/other maint- commands
		;;
	esac
fi

if $raw_exec; then
	# Raw command: pass "$@" as-is to kubectl exec
	kubectl exec "${kubectl_flags[@]}" deployment/pimcore-maintenance-shell -- "$@"
else
	# Maintenance subcommand: run "maint-<subcommand>" inside the pod
	kubectl exec "${kubectl_flags[@]}" deployment/pimcore-maintenance-shell -- "$container_command" "$@"
fi
