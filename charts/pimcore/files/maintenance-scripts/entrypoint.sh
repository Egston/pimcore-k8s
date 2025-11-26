#!/usr/bin/env bash
set -euo pipefail

# Ensure we have the tools we need:
# - util-linux: su with --whitelist-environment
# - bash/coreutils: for arrays, comm, sort, etc.
# - sudo/acl
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
	bash coreutils procps util-linux sudo acl yq mariadb-client \
	{{ .Values.maintenance.shell.installPackages }}
# rm -rf /var/lib/apt/lists/*

maintainer_group_name={{ .Values.maintenance.shell.maintainer.groupName }}
maintainer_group_id={{ .Values.maintenance.shell.maintainer.groupId }}
maintainer_user_name={{ .Values.maintenance.shell.maintainer.userName }}
maintainer_user_id={{ .Values.maintenance.shell.maintainer.userId }}

if ! getent group "$maintainer_group_name" >/dev/null; then
	addgroup --gid "$maintainer_group_id" "$maintainer_group_name"
	echo "%$maintainer_group_name ALL=(ALL) NOPASSWD:ALL" >>/etc/sudoers
fi

if ! id -u "$maintainer_user_name" >/dev/null 2>&1; then
	adduser --disabled-password --gecos "" --uid "$maintainer_user_id" --gid "$maintainer_group_id" "$maintainer_user_name"
fi

home="$(eval echo ~"$maintainer_user_name")"

# Minimal login customizations for the maintainer
if ! grep -q 'PIMCORE_LOGIN_BOOTSTRAP' "$home/.profile" 2>/dev/null; then
	printf '%s\n' \
		'# PIMCORE_LOGIN_BOOTSTRAP' \
		'export PHP_MAX_EXECUTION_TIME=0' \
		'export PHP_MEMORY_LIMIT=-1' \
		'target_dir=${MAINTAINER_CWD:-/var/www/pimcore}' \
		'if [ -d "$target_dir" ]; then' \
		'  cd "$target_dir" || true' \
		'fi' >>"$home/.profile"
	chown "$maintainer_user_name:$maintainer_group_name" "$home/.profile"
fi

# Install helper scripts into PATH (copied from configmap mount)
install -m 0755 /opt/maintenance-scripts/maint-login-merge.sh /usr/local/bin/maint-login-merge
install -m 0755 /opt/maintenance-scripts/maint-shell.sh /usr/local/bin/maint-shell
install -m 0755 /opt/maintenance-scripts/maint-cache-reset.sh /usr/local/bin/maint-cache-reset
install -m 0755 /opt/maintenance-scripts/maint-graphql-cache-reset.sh /usr/local/bin/maint-graphql-cache-reset
install -m 0755 /opt/maintenance-scripts/maint-db-import.sh /usr/local/bin/maint-db-import
install -m 0755 /opt/maintenance-scripts/maint-list-db-backups.sh /usr/local/bin/maint-list-db-backups
install -m 0755 /opt/maintenance-scripts/maint-help /usr/local/bin/maint-help

{{ with .Values.maintenance.shell.entrypointAdditionalCommands }}

{{ . }}
{{ end }}

touch /tmp/entrypoint_done

# Start an interactive login shell for the maintainer with merged env
# kubectl attach -it deployment/pimcore-maintenance-shell
exec /usr/local/bin/maint-login-merge "$maintainer_user_name" /var/www/pimcore
