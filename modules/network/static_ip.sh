#!/usr/bin/env bash
set -euo pipefail

STATIC_IP_IFACE="${STATIC_IP_IFACE:-${SRVCTL_IFACE:-}}"
STATIC_IP_ADDRESS="${STATIC_IP_ADDRESS:-${SRVCTL_IP:-}}"
STATIC_IP_CIDR="${STATIC_IP_CIDR:-24}"
STATIC_IP_GW="${STATIC_IP_GW:-}"
SRVCTL_NETPLAN_FILE="${SRVCTL_NETPLAN_FILE:-/etc/netplan/99-srvctl.yaml}"

STATIC_IP_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$STATIC_IP_MODULE_DIR/lib/common.sh"
source "$STATIC_IP_MODULE_DIR/core/logger.sh"
source "$STATIC_IP_MODULE_DIR/core/state_engine.sh"
source "$STATIC_IP_MODULE_DIR/core/backup_manager.sh"
source "$STATIC_IP_MODULE_DIR/core/executor.sh"
source "$STATIC_IP_MODULE_DIR/adapters/ubuntu/netplan.sh"

static_ip_gateway() {
    if [[ -n "$STATIC_IP_GW" ]]; then
        printf '%s\n' "$STATIC_IP_GW"
    else
        srvctl_gateway_for_ip "$STATIC_IP_ADDRESS"
    fi
}

static_ip_render() {
    netplan_render_static "$STATIC_IP_IFACE" "$STATIC_IP_ADDRESS" "$STATIC_IP_CIDR" "$(static_ip_gateway)"
}

static_ip_init() {
    is_root || { log_error "static_ip requires root"; return 1; }
    require_cmd jq
    require_cmd ip
    require_cmd diff
    iface_exists "$STATIC_IP_IFACE" || { log_error "Interface not found: $STATIC_IP_IFACE"; return 1; }
    log_info "static_ip init passed for $STATIC_IP_IFACE"
}

static_ip_check() {
    valid_ipv4 "$STATIC_IP_ADDRESS" || { log_error "Invalid IPv4 address: $STATIC_IP_ADDRESS"; return 1; }
    iface_exists "$STATIC_IP_IFACE" || { log_error "Interface not found: $STATIC_IP_IFACE"; return 1; }
    local ip_output
    ip_output="$(ip -o link show dev "$STATIC_IP_IFACE" 2>/dev/null || true)"
    if [[ "$ip_output" != *"state UP"* && "$ip_output" != *"UP"* ]]; then
        log_error "Interface is not up: $STATIC_IP_IFACE"
        return 1
    fi
    log_info "static_ip check passed for $STATIC_IP_IFACE -> $STATIC_IP_ADDRESS"
}

static_ip_plan() {
    local rendered
    local tmp_file

    rendered="$(static_ip_render)"
    tmp_file="$(mktemp)"
    printf '%s\n' "$rendered" > "$tmp_file"

    if [[ -f "$SRVCTL_NETPLAN_FILE" ]]; then
        if diff -u "$SRVCTL_NETPLAN_FILE" "$tmp_file"; then
            log_info "No netplan changes required"
        else
            true
        fi
    else
        diff -u /dev/null "$tmp_file" || true
    fi

    rm -f "$tmp_file"
}

static_ip_apply() {
    local rendered
    local tmp_file
    local current_file_exists

    rendered="$(static_ip_render)"
    tmp_file="$(mktemp)"
    printf '%s\n' "$rendered" > "$tmp_file"

    current_file_exists=false
    if [[ -f "$SRVCTL_NETPLAN_FILE" ]]; then
        current_file_exists=true
        if cmp -s "$SRVCTL_NETPLAN_FILE" "$tmp_file"; then
            log_info "static_ip already applied for $STATIC_IP_IFACE"
            rm -f "$tmp_file"
            state_set "static_ip_iface" "$STATIC_IP_IFACE"
            state_set "static_ip_address" "$STATIC_IP_ADDRESS"
            state_set "static_ip_cidr" "$STATIC_IP_CIDR"
            state_set "static_ip_gateway" "$(static_ip_gateway)"
            return 0
        fi
    fi

    if [[ "$current_file_exists" == true ]]; then
        backup_create "$SRVCTL_NETPLAN_FILE"
    fi

    mkdir -p "$(dirname "$SRVCTL_NETPLAN_FILE")"
    mv "$tmp_file" "$SRVCTL_NETPLAN_FILE"
    log_info "Netplan configuration updated: $SRVCTL_NETPLAN_FILE"
    safe_exec netplan apply

    state_set "static_ip_iface" "$STATIC_IP_IFACE"
    state_set "static_ip_address" "$STATIC_IP_ADDRESS"
    state_set "static_ip_cidr" "$STATIC_IP_CIDR"
    state_set "static_ip_gateway" "$(static_ip_gateway)"
}

static_ip_verify() {
    local gateway
    gateway="$(static_ip_gateway)"
    if ! ping -c 1 -W 1 "$gateway" >/dev/null 2>&1; then
        log_error "Gateway ping failed: $gateway"
        return 1
    fi

    if ! ip -4 addr show dev "$STATIC_IP_IFACE" | grep -q "inet ${STATIC_IP_ADDRESS}/${STATIC_IP_CIDR}"; then
        log_error "Expected IP missing on $STATIC_IP_IFACE: $STATIC_IP_ADDRESS/$STATIC_IP_CIDR"
        return 1
    fi

    log_info "static_ip verify passed for $STATIC_IP_IFACE"
}

static_ip_rollback() {
    if backup_restore "$SRVCTL_NETPLAN_FILE"; then
        safe_exec netplan apply
        state_delete "static_ip_iface"
        state_delete "static_ip_address"
        state_delete "static_ip_cidr"
        state_delete "static_ip_gateway"
        log_warn "static_ip rollback completed"
    fi
}
