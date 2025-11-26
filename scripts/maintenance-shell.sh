#!/usr/bin/env bash
set -euo pipefail

# Collect kubectl exec flags from CLI (before first non-flag or "--")
kubectl_flags=()
while [ $# -gt 0 ] && [[ "$1" == -* ]] && [ "$1" != "--" ]; do
	kubectl_flags+=("$1")
	shift
done

raw_exec=false
download_latest_backup=false
subcommand=""
container_command=""
scale_down_only=false
shell_deploy="${MAINT_SHELL_DEPLOYMENT:-}"
shell_instance_label="${MAINT_SHELL_INSTANCE:-}"
app_name_label="${MAINT_APP_NAME:-pimcore}"

# Decide mode / subcommand
if [ $# -eq 0 ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
	cat <<-'EOF'
		maintenance-shell.sh is a wrapper script to execute maintenance commands
		or arbitrary commands inside the pimcore-maintenance-shell pod.

		Usage:
		  maintenance-shell.sh [<kubectl-flags>] <subcommand> [<args>...]
		  maintenance-shell.sh [<kubectl-flags>] -- <command> [<args>...]
		  maintenance-shell.sh [<kubectl-flags>] down
		  maintenance-shell.sh [<kubectl-flags>] download-latest-db-backup [<target-dir>]

		Modes:

		  1) Maintenance subcommands (auto-prefixed with "maint-"):
		     Runs inside the pod. Known subcommands include:
		         shell                 → maint-shell
		         cache-reset           → maint-cache-reset
		         graphql-cache-reset   → maint-graphql-cache-reset
		         db-import             → maint-db-import
		         list-db-backups       → maint-list-db-backups
		         help                  → maint-help

		  2) Download newest DB backup locally:
		     maintenance-shell.sh [<kubectl-flags>] download-latest-db-backup [<target-dir>]
		     Defaults to current directory when <target-dir> is omitted.

		  3) Raw commands (no "maint-" prefix):
		     maintenance-shell.sh [<kubectl-flags>] -- <command> [<args>...]
		     Everything after "--" is passed as-is to "kubectl exec --".

		  4) Scale down the maintenance shell deployment:
		     maintenance-shell.sh [<kubectl-flags>] down

		<kubectl-flags> are optional flags for kubectl (e.g. -it, -n pimcore).
		Optional env vars:
		  MAINT_SHELL_DEPLOYMENT  Force the maintenance shell deployment name
		  MAINT_SHELL_INSTANCE    Force the app.kubernetes.io/instance label to target
		  MAINT_APP_NAME          Override app.kubernetes.io/name label (default: pimcore)
	EOF
	exit 0
elif [ "${1:-}" = "down" ]; then
	scale_down_only=true
elif [ "${1:-}" = "--" ]; then
	raw_exec=true
	shift
	if [ $# -eq 0 ]; then
		echo 'Error: no command specified after "--".' >&2
		exit 1
	fi
else
	subcommand="$1"
	shift
	case "$subcommand" in
	download-latest-db-backup)
		download_latest_backup=true
		;;
	*)
		container_command="maint-$subcommand"
		;;
	esac
fi

# Normalize kubectl flags for non-interactive calls (scale/get/cp)
kubectl_noninteractive_flags=()
for f in "${kubectl_flags[@]}"; do
	case "$f" in
	-i | -t | -it) ;; # not valid for get/scale/cp
	*) kubectl_noninteractive_flags+=("$f") ;;
	esac
done

detect_shell_resources() {
	if [ -n "$shell_deploy" ] && [ -n "$shell_instance_label" ]; then
		return
	fi
	# Try to find the maintenance-shell deployment and its instance label
	mapfile -t found_shells < <(
		kubectl "${kubectl_noninteractive_flags[@]}" get deployment \
			-l "app.kubernetes.io/name=${app_name_label}" \
			-o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.metadata.labels.app\.kubernetes\.io/instance}{"\n"}{end}' \
			| grep 'maintenance-shell' || true
	)
	if [ "${#found_shells[@]}" -eq 0 ]; then
		echo "Error: could not locate a maintenance-shell deployment (label app.kubernetes.io/name=${app_name_label})." >&2
		exit 1
	fi
	read -r shell_deploy shell_instance_label <<<"${found_shells[0]}"
	if [ -z "$shell_deploy" ] || [ -z "$shell_instance_label" ]; then
		echo "Error: detected maintenance shell deployment but missing instance label." >&2
		exit 1
	fi
}

detect_shell_resources

# Scale down early and exit if requested
if $scale_down_only; then
	kubectl scale "${kubectl_noninteractive_flags[@]}" deployment/"$shell_deploy" --replicas=0
	exit 0
fi

# Ensure the maintenance shell is running
kubectl scale "${kubectl_noninteractive_flags[@]}" deployment/"$shell_deploy" --replicas=1
kubectl rollout status "${kubectl_noninteractive_flags[@]}" deployment/"$shell_deploy"

# Default flags if none provided (only for maint-* exec)
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
	list-db-backups | download-latest-db-backup)
		# no defaults; leave empty
		;;
	*)
		;;
	esac
fi

if $raw_exec; then
	kubectl exec "${kubectl_flags[@]}" deployment/"$shell_deploy" -- "$@"
elif $download_latest_backup; then
	target_dir="${1:-.}"
	if [ $# -gt 1 ]; then
		echo "Error: download-latest-db-backup accepts at most one argument (target directory)." >&2
		exit 1
	fi
	if ! mkdir -p "$target_dir"; then
		echo "Error: unable to create target directory '$target_dir'." >&2
		exit 1
	fi

	if ! latest_path="$(kubectl exec "${kubectl_flags[@]}" deployment/"$shell_deploy" -- maint-list-db-backups --latest)"; then
		echo "Error: failed to retrieve latest backup path from pod." >&2
		exit 1
	fi
	if [ -z "$latest_path" ]; then
		echo "Error: no backup found in pod." >&2
		exit 1
	fi

	# kubectl cp does not support Deployments; resolve a pod name (prefer running)
	shell_pod="$(
		kubectl "${kubectl_noninteractive_flags[@]}" get pod \
			-l app.kubernetes.io/instance="$shell_instance_label" \
			--field-selector=status.phase=Running \
			-o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | head -n1
	)"
	if [ -z "$shell_pod" ]; then
		shell_pod="$(
			kubectl "${kubectl_noninteractive_flags[@]}" get pod \
				-l app.kubernetes.io/instance="$shell_instance_label" \
				-o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | head -n1
		)"
	fi
	if [ -z "$shell_pod" ]; then
		echo "Error: could not find a maintenance-shell pod to copy from." >&2
		exit 1
	fi

	dest_path="${target_dir%/}/$(basename "$latest_path")"
	kubectl cp "${kubectl_noninteractive_flags[@]}" "$shell_pod:$latest_path" "$dest_path"
	echo "Copied $latest_path from $shell_pod to $dest_path"
else
	kubectl exec "${kubectl_flags[@]}" deployment/"$shell_deploy" -- "$container_command" "$@"
fi
