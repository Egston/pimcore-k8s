#!/usr/bin/env bash
# Import a SQL dump into the Pimcore database, supporting common compression formats.
set -euo pipefail

show_usage() {
	printf '%s\n' \
		"Usage: maint-db-import [--dump-file <path>|-f <path>] [--help]" \
		"" \
		"Import a Pimcore database dump from a file or STDIN. Supported compressions:" \
		"plain text, gzip (.gz), bzip2 (.bz2), xz (.xz), and zstd (.zst/.zstd)." \
		"Clears and warms the Pimcore cache after import." \
		"" \
		"Examples:" \
		"  maint-db-import --dump-file /tmp/dump.sql.gz" \
		"  zcat /tmp/dump.sql.gz | maint-db-import" \
		"  kubectl exec -i deployment/pimcore-maintenance-shell -- maint-db-import --dump-file /tmp/dump.sql"
}

dump_file=""
while [[ $# -gt 0 ]]; do
	case "$1" in
	--dump-file | -f)
		if [[ $# -lt 2 ]]; then
			echo "Error: $1 requires a path argument." >&2
			show_usage
			exit 2
		fi
		dump_file="$2"
		shift 2
		;;
	-h | --help)
		show_usage
		exit 0
		;;
	--)
		shift
		break
		;;
	*)
		if [[ -z "$dump_file" ]]; then
			dump_file="$1"
			shift
		else
			echo "Error: unexpected argument '$1'." >&2
			show_usage
			exit 2
		fi
		;;
	esac
done

if [[ -z "$dump_file" ]]; then
	if [[ -t 0 ]]; then
		echo "Error: no dump provided via --dump-file and STDIN is not piped." >&2
		show_usage
		exit 2
	fi
	dump_file="-"
fi

cleanup_path=""
if [[ "$dump_file" == "-" ]]; then
	tmp_file="$(mktemp -t pimcore-db-import.XXXXXX)"
	cleanup_path="$tmp_file"
	trap '[[ -n "$cleanup_path" ]] && rm -f "$cleanup_path"' EXIT
	cat >"$tmp_file"
	source_path="$tmp_file"
else
	source_path="$dump_file"
	if [[ ! -f "$source_path" ]]; then
		echo "Error: dump file '$source_path' not found." >&2
		exit 2
	fi
fi

detect_compression() {
	local path="$1"
	if command -v file >/dev/null 2>&1; then
		local mime
		mime="$(file -b --mime-type "$path" 2>/dev/null || true)"
		case "$mime" in
		application/gzip)
			echo "gzip"
			return
			;;
		application/x-bzip2)
			echo "bzip2"
			return
			;;
		application/x-xz)
			echo "xz"
			return
			;;
		application/zstd)
			echo "zstd"
			return
			;;
		esac
	fi
	case "$path" in
	*.gz | *.sql.gz | *.tgz) echo "gzip" ;;
	*.bz2 | *.sql.bz2 | *.tbz2) echo "bzip2" ;;
	*.xz | *.sql.xz) echo "xz" ;;
	*.zst | *.sql.zst | *.zstd) echo "zstd" ;;
	*) echo "plain" ;;
	esac
}

compression="$(detect_compression "$source_path")"
reader_cmd=(cat "$source_path")

require_cmd() {
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "Error: required command '$1' is not available in PATH." >&2
		exit 4
	fi
}

case "$compression" in
plain)
	reader_cmd=(cat "$source_path")
	;;
gzip)
	require_cmd gzip
	reader_cmd=(gzip -cd -- "$source_path")
	;;
bzip2)
	require_cmd bzip2
	reader_cmd=(bzip2 -cd -- "$source_path")
	;;
xz)
	require_cmd xz
	reader_cmd=(xz -cd -- "$source_path")
	;;
zstd)
	require_cmd zstd
	reader_cmd=(zstd -cd -- "$source_path")
	;;
*)
	echo "Error: unsupported compression type '$compression'." >&2
	exit 3
	;;
esac

require_cmd yq
require_cmd mysql

config_path="${DATABASE_CONFIG_PATH:-/var/www/pimcore/config/local/database.yaml}"
if [[ ! -f "$config_path" ]]; then
	echo "Error: database config '$config_path' not found." >&2
	exit 2
fi

yaml_query_base='.doctrine.dbal.connections.default'
mysql_host="$(yq -r "${yaml_query_base}.host // empty" "$config_path")"
mysql_port="$(yq -r "${yaml_query_base}.port // empty" "$config_path")"
mysql_user="$(yq -r "${yaml_query_base}.user // empty" "$config_path")"
mysql_password="$(yq -r "${yaml_query_base}.password // empty" "$config_path")"
mysql_dbname="$(yq -r "${yaml_query_base}.dbname // empty" "$config_path")"

if [[ -z "$mysql_host" || -z "$mysql_user" || -z "$mysql_password" || -z "$mysql_dbname" ]]; then
	echo "Error: one or more required database settings (host/user/password/dbname) are missing in $config_path." >&2
	exit 1
fi

if [[ -z "$mysql_port" || "$mysql_port" == "null" ]]; then
	mysql_port="3306"
fi

mysql_cmd=(
	mysql
	--protocol=tcp
	--host="$mysql_host"
	--port="$mysql_port"
	--user="$mysql_user"
	"$mysql_dbname"
)

echo "Importing dump into database '$mysql_dbname' at ${mysql_host}:${mysql_port}..." >&2
if ! "${reader_cmd[@]}" | MYSQL_PWD="$mysql_password" "${mysql_cmd[@]}"; then
	echo "Error: database import failed." >&2
	exit 1
fi
echo "Database import completed successfully." >&2
echo "Resetting Pimcore cache..." >&2
/usr/local/bin/maint-cache-reset
echo "Pimcore cache reset completed." >&2
