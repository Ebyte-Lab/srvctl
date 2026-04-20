#!/usr/bin/env bash
set -euo pipefail

HOSTNAME_TARGET="${HOSTNAME_TARGET:-${SRVCTL_HOSTNAME:-}}"

HOSTNAME_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$HOSTNAME_MODULE_DIR/lib/common.sh"
source "$HOSTNAME_MODULE_DIR/core/logger.sh"
source "$HOSTNAME_MODULE_DIR/core/state_engine.sh"
source "$HOSTNAME_MODULE_DIR/core/executor.sh"

hostname_init() {
    is_root || { log_error "hostname requires root"; return 1; }
    require_cmd hostnamectl
}

hostname_check() {
    [[ -n "$HOSTNAME_TARGET" ]] || { log_error "hostname target missing"; return 1; }
}

hostname_plan() {
    local current_hostname
    current_hostname="$(hostnamectl status --static 2>/dev/null || hostname)"
    printf '%s\n' "Current hostname: ${current_hostname}"
    printf '%s\n' "Target hostname:  ${HOSTNAME_TARGET}"
}

hostname_apply() {
    local current_hostname
    current_hostname="$(hostnamectl status --static 2>/dev/null || hostname)"

    if [[ "$current_hostname" == "$HOSTNAME_TARGET" ]]; then
        log_info "hostname already applied: $HOSTNAME_TARGET"
        state_set "hostname_target" "$HOSTNAME_TARGET"
        return 0
    fi

    state_set "hostname_previous" "$current_hostname"
    safe_exec hostnamectl set-hostname "$HOSTNAME_TARGET"
    state_set "hostname_target" "$HOSTNAME_TARGET"
}

hostname_verify() {
    local current_hostname
    current_hostname="$(hostnamectl status --static 2>/dev/null || hostname)"
    [[ "$current_hostname" == "$HOSTNAME_TARGET" ]]
}

hostname_rollback() {
    local previous_hostname
    previous_hostname="$(state_get "hostname_previous" "")"
    [[ -n "$previous_hostname" ]] || { log_error "No hostname rollback state"; return 1; }
    safe_exec hostnamectl set-hostname "$previous_hostname"
    state_delete "hostname_target"
}
