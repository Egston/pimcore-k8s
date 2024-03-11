#!/bin/bash

# Extract the cloud provider and lifecycle event from the script name
INVOKED_NAME=$(basename "$0")
IFS='-' read -r CLOUD_PROVIDER LIFECYCLE_EVENT <<< "$INVOKED_NAME"
# if the link ended with .sh, remove it from LIFECYCLE_EVENT
LIFECYCLE_EVENT=${LIFECYCLE_EVENT%.sh}

BASE_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")

# Apply Kubernetes configurations for the cloud provider
KUBE_CONFIG_DIR="${BASE_DIR}/cloud-configs/${CLOUD_PROVIDER}"
if [ -d "$KUBE_CONFIG_DIR" ]; then
    echo "Applying Kubernetes configurations from $KUBE_CONFIG_DIR"
    kubectl apply -f "$KUBE_CONFIG_DIR"
else
    echo "No Kubernetes configurations to apply for $CLOUD_PROVIDER"
fi

# Function to run hooks from the custom-hooks directory
run_user_hooks() {
    USER_HOOK_DIR="$1"
    if [ -d "$USER_HOOK_DIR" ]; then
        (
            # Change to the directory to ensure relative paths in the hooks work
            cd "$USER_HOOK_DIR"
            echo "Running user hooks in $USER_HOOK_DIR"
            run-parts --report "$USER_HOOK_DIR"
        )
    else
        echo "No user hooks to run in $USER_HOOK_DIR"
    fi
}

# Paths for common and cloud provider-specific custom hooks
PROJECT_ROOT=$(realpath "${BASE_DIR}/../..")
COMMON_HOOK_DIR="${PROJECT_ROOT}/custom-hooks/_common/${LIFECYCLE_EVENT}"
CLOUD_SPECIFIC_HOOK_DIR="${PROJECT_ROOT}/custom-hooks/${CLOUD_PROVIDER}-${LIFECYCLE_EVENT}"

# Execute hooks
run_user_hooks "$COMMON_HOOK_DIR"
run_user_hooks "$CLOUD_SPECIFIC_HOOK_DIR"
