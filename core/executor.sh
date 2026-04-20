#!/usr/bin/env bash
set -euo pipefail

safe_exec() {
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY-RUN: $*"
        return 0
    fi

    log_info "RUN: $*"
    if "$@"; then
        return 0
    fi

    local exit_code=$?
    log_error "Command failed with exit code ${exit_code}: $*"
    return "$exit_code"
}
