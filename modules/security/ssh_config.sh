#!/usr/bin/env bash
set -euo pipefail

SSH_CONFIG_FILE="${SRVCTL_SSHD_DROPIN_FILE:-/etc/ssh/sshd_config.d/99-srvctl.conf}"
SSH_SERVICE_NAME="${SRVCTL_SSH_SERVICE_NAME:-ssh}"
SSH_PERMIT_ROOT_LOGIN="${SSH_PERMIT_ROOT_LOGIN:-no}"
SSH_PASSWORD_AUTHENTICATION="${SSH_PASSWORD_AUTHENTICATION:-no}"

SSH_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$SSH_MODULE_DIR/lib/common.sh"
source "$SSH_MODULE_DIR/core/logger.sh"
source "$SSH_MODULE_DIR/core/state_engine.sh"
source "$SSH_MODULE_DIR/core/backup_manager.sh"
source "$SSH_MODULE_DIR/core/executor.sh"
source "$SSH_MODULE_DIR/adapters/ubuntu/systemd.sh"

ssh_config_render() {
    cat <<EOF
PermitRootLogin ${SSH_PERMIT_ROOT_LOGIN}
PasswordAuthentication ${SSH_PASSWORD_AUTHENTICATION}
EOF
}

ssh_config_init() {
    is_root || { log_error "ssh_config requires root"; return 1; }
    require_cmd sshd
    require_cmd jq
}

ssh_config_check() {
    [[ "$SSH_PERMIT_ROOT_LOGIN" =~ ^(yes|no|prohibit-password|without-password)$ ]] || return 1
    [[ "$SSH_PASSWORD_AUTHENTICATION" =~ ^(yes|no)$ ]] || return 1
}

ssh_config_plan() {
    local tmp_file
    tmp_file="$(mktemp)"
    ssh_config_render > "$tmp_file"
    if [[ -f "$SSH_CONFIG_FILE" ]]; then
        diff -u "$SSH_CONFIG_FILE" "$tmp_file" || true
    else
        diff -u /dev/null "$tmp_file" || true
    fi
    rm -f "$tmp_file"
}

ssh_config_apply() {
    local rendered
    local tmp_file

    rendered="$(ssh_config_render)"
    tmp_file="$(mktemp)"
    printf '%s\n' "$rendered" > "$tmp_file"

    if [[ -f "$SSH_CONFIG_FILE" ]] && cmp -s "$SSH_CONFIG_FILE" "$tmp_file"; then
        log_info "ssh config already applied"
        rm -f "$tmp_file"
        state_set "ssh_permit_root_login" "$SSH_PERMIT_ROOT_LOGIN"
        state_set "ssh_password_authentication" "$SSH_PASSWORD_AUTHENTICATION"
        return 0
    fi

    [[ -f "$SSH_CONFIG_FILE" ]] && backup_create "$SSH_CONFIG_FILE"
    mkdir -p "$(dirname "$SSH_CONFIG_FILE")"
    mv "$tmp_file" "$SSH_CONFIG_FILE"
    safe_exec sshd -t
    systemd_reload_daemon
    systemd_restart_service "$SSH_SERVICE_NAME"
    state_set "ssh_permit_root_login" "$SSH_PERMIT_ROOT_LOGIN"
    state_set "ssh_password_authentication" "$SSH_PASSWORD_AUTHENTICATION"
}

ssh_config_verify() {
    local current_root_login
    local current_password_auth

    current_root_login="$(sshd -T 2>/dev/null | awk '/permitrootlogin/ {print $2; exit}')"
    current_password_auth="$(sshd -T 2>/dev/null | awk '/passwordauthentication/ {print $2; exit}')"

    [[ "$current_root_login" == "$SSH_PERMIT_ROOT_LOGIN" ]] || return 1
    [[ "$current_password_auth" == "$SSH_PASSWORD_AUTHENTICATION" ]] || return 1
}

ssh_config_rollback() {
    backup_restore "$SSH_CONFIG_FILE"
    safe_exec sshd -t
    systemd_restart_service "$SSH_SERVICE_NAME"
    state_delete "ssh_permit_root_login"
    state_delete "ssh_password_authentication"
}
