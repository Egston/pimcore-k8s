#!/usr/bin/env bash
# List Pimcore MySQL backups from /backup, newest first. Supports --latest to print only the newest entry.
set -euo pipefail

backup_dir="${BACKUP_DIR:-/backup}"
latest_only=false

show_usage() {
	printf '%s\n' \
		"Usage: maint-list-db-backups [--latest] [--help]" \
		"" \
		"List MySQL backups stored in \$BACKUP_DIR (default: /backup), newest first." \
		"--latest prints only the newest backup path."
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--latest | -l)
		latest_only=true
		shift
		;;
	-h | --help)
		show_usage
		exit 0
		;;
	*)
		echo "Error: unexpected argument '$1'." >&2
		show_usage
		exit 2
		;;
	esac
done

if [[ ! -d "$backup_dir" ]]; then
	echo "Error: backup directory '$backup_dir' not found." >&2
	exit 1
fi

mapfile -t backup_lines < <(
	find "$backup_dir" -maxdepth 1 -type f \( -name '*.sql' -o -name '*.sql.*' \) -printf '%T@\t%p\n' \
		| sort -nr
)

if [[ ${#backup_lines[@]} -eq 0 ]]; then
	echo "No database backups found in $backup_dir." >&2
	exit 3
fi

if [[ "$latest_only" == "true" ]]; then
	latest_path="${backup_lines[0]#*$'\t'}"
	echo "$latest_path"
	exit 0
fi

for line in "${backup_lines[@]}"; do
	path="${line#*$'\t'}"
	echo "$path"
done
