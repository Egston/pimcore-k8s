#!/bin/bash

# Extract the cloud provider and lifecycle event from the script name
INVOKED_NAME=$(basename "$0")
IFS='-' read -r CLOUD_PROVIDER LIFECYCLE_EVENT <<< "$INVOKED_NAME"
# if the link ended with .sh, remove it from LIFECYCLE_EVENT
LIFECYCLE_EVENT=${LIFECYCLE_EVENT%.sh}

BASE_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")

# Apply Kubernetes configurations for the cloud provider. The charts need
# these before they install, and a delete must not put cluster-scoped objects
# back.
KUBE_CONFIG_DIR="${BASE_DIR}/../cloud-configs/${CLOUD_PROVIDER}"
case "$LIFECYCLE_EVENT" in
    pre-install | pre-upgrade)
        if [ ! -d "$KUBE_CONFIG_DIR" ]; then
            echo "No configuration directory at $KUBE_CONFIG_DIR" >&2
            exit 1
        fi
        echo "Applying Kubernetes configurations from $KUBE_CONFIG_DIR"
        # The manifests sit a level further down, one directory per kind.
        if ! kubectl apply -R -f "$KUBE_CONFIG_DIR"; then
            echo "Failed to apply Kubernetes configurations from $KUBE_CONFIG_DIR" >&2
            exit 1
        fi
        ;;
esac

# Function to run hooks from the custom-hooks directory
run_user_hooks() {
    USER_HOOK_DIR="$1"
    if [ -d "$USER_HOOK_DIR" ]; then
        (
            # Change to the directory to ensure relative paths in the hooks work
            cd "$USER_HOOK_DIR" || exit 1
            echo "Running user hooks in $USER_HOOK_DIR"
            run-parts --report "$USER_HOOK_DIR"
        )
    else
        echo "No user hooks to run in $USER_HOOK_DIR"
    fi
}

# Determine directory with custom hooks (either $HELMSMAN_CUSTOM_HOOKS_DIR env.
# variable or <REPO_ROOT>/custom-hooks)
REPO_ROOT=$(realpath "${BASE_DIR}/../..")
CUSTOM_HOOKS_DIR="${HELMSMAN_CUSTOM_HOOKS_DIR:-${REPO_ROOT}/custom-hooks}"

# Run common and cloud provider-specific custom hooks
COMMON_HOOK_DIR="${CUSTOM_HOOKS_DIR}/_common/${LIFECYCLE_EVENT}"
CLOUD_SPECIFIC_HOOK_DIR="${CUSTOM_HOOKS_DIR}/${CLOUD_PROVIDER}-${LIFECYCLE_EVENT}"
run_user_hooks "$COMMON_HOOK_DIR"
run_user_hooks "$CLOUD_SPECIFIC_HOOK_DIR"
