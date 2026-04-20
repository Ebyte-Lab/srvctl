#!/usr/bin/env bash
set -euo pipefail

DHCP_IFACE="${DHCP_IFACE:-${SRVCTL_IFACE:-}}"
SRVCTL_NETPLAN_FILE="${SRVCTL_NETPLAN_FILE:-/etc/netplan/99-srvctl.yaml}"

DHCP_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$DHCP_MODULE_DIR/lib/common.sh"
source "$DHCP_MODULE_DIR/core/logger.sh"
source "$DHCP_MODULE_DIR/core/state_engine.sh"
source "$DHCP_MODULE_DIR/core/backup_manager.sh"
source "$DHCP_MODULE_DIR/core/executor.sh"

dhcp_render() {
    cat <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ${DHCP_IFACE}:
      dhcp4: true
EOF
}

dhcp_init() {
    is_root || { log_error "dhcp requires root"; return 1; }
    require_cmd jq
    require_cmd ip
    iface_exists "$DHCP_IFACE" || { log_error "Interface not found: $DHCP_IFACE"; return 1; }
}

dhcp_check() {
    iface_exists "$DHCP_IFACE" || { log_error "Interface not found: $DHCP_IFACE"; return 1; }
    ip -o link show dev "$DHCP_IFACE" | grep -q "UP" || { log_error "Interface is not up: $DHCP_IFACE"; return 1; }
}

dhcp_plan() {
    local tmp_file
    tmp_file="$(mktemp)"
    dhcp_render > "$tmp_file"
    if [[ -f "$SRVCTL_NETPLAN_FILE" ]]; then
        diff -u "$SRVCTL_NETPLAN_FILE" "$tmp_file" || true
    else
        diff -u /dev/null "$tmp_file" || true
    fi
    rm -f "$tmp_file"
}

dhcp_apply() {
    local tmp_file
    local rendered

    rendered="$(dhcp_render)"
    tmp_file="$(mktemp)"
    printf '%s\n' "$rendered" > "$tmp_file"

    if [[ -f "$SRVCTL_NETPLAN_FILE" ]] && cmp -s "$SRVCTL_NETPLAN_FILE" "$tmp_file"; then
        log_info "dhcp already applied for $DHCP_IFACE"
        rm -f "$tmp_file"
        state_set "dhcp_iface" "$DHCP_IFACE"
        return 0
    fi

    [[ -f "$SRVCTL_NETPLAN_FILE" ]] && backup_create "$SRVCTL_NETPLAN_FILE"
    mv "$tmp_file" "$SRVCTL_NETPLAN_FILE"
    safe_exec netplan apply
    state_set "dhcp_iface" "$DHCP_IFACE"
}

dhcp_verify() {
    ip -o link show dev "$DHCP_IFACE" | grep -q "UP"
}

dhcp_rollback() {
    backup_restore "$SRVCTL_NETPLAN_FILE"
    safe_exec netplan apply
    state_delete "dhcp_iface"
}
