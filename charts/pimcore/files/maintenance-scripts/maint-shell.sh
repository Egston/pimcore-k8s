#!/usr/bin/env bash
# Convenient wrapper to open a new maintainer login shell with merged env
# You can run: kubectl exec -it deployment/pimcore-maintenance-shell -- maint-shell
set -euo pipefail
: "${MAINTAINER_USER_NAME:={{ .Values.maintenance.shell.maintainer.userName }}}"
: "${MAINTAINER_CWD:=/var/www/pimcore}"

exec /usr/local/bin/maint-login-merge "$MAINTAINER_USER_NAME" "$MAINTAINER_CWD"
