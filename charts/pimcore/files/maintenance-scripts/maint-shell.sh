#!/usr/bin/env bash
# Convenient wrapper to open a maintainer login shell with merged env,
# or run a command non-interactively as the maintainer user.
#   Interactive:     maint-shell
#   Non-interactive: maint-shell git status
set -euo pipefail
: "${MAINTAINER_USER_NAME:={{ .Values.maintenance.shell.maintainer.userName }}}"
: "${MAINTAINER_CWD:=/var/www/pimcore}"

exec /usr/local/bin/maint-login-merge "$MAINTAINER_USER_NAME" "$MAINTAINER_CWD" "$@"
