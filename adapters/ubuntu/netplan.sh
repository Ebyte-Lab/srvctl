#!/usr/bin/env bash
set -euo pipefail

SRVCTL_NETPLAN_FILE="${SRVCTL_NETPLAN_FILE:-/etc/netplan/99-srvctl.yaml}"

srvctl_gateway_for_ip() {
    local ip_address="$1"
    IFS='.' read -r octet1 octet2 octet3 octet4 <<< "$ip_address"
    printf '%s.%s.%s.1\n' "$octet1" "$octet2" "$octet3"
}

netplan_render_static() {
    local iface="$1"
    local ip_address="$2"
    local cidr_prefix="${3:-24}"
    local gateway="${4:-$(srvctl_gateway_for_ip "$ip_address")}" 

    cat <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ${iface}:
      dhcp4: false
      addresses:
        - ${ip_address}/${cidr_prefix}
      gateway4: ${gateway}
EOF
}

netplan_write() {
    local iface="$1"
    local ip_address="$2"
    local cidr_prefix="${3:-24}"
    local gateway="${4:-$(srvctl_gateway_for_ip "$ip_address")}" 
    local target_dir
    local tmp_file
    local rendered

    target_dir="$(dirname "$SRVCTL_NETPLAN_FILE")"
    mkdir -p "$target_dir"
    rendered="$(netplan_render_static "$iface" "$ip_address" "$cidr_prefix" "$gateway")"

    if [[ -f "$SRVCTL_NETPLAN_FILE" ]] && diff -u "$SRVCTL_NETPLAN_FILE" <(printf '%s\n' "$rendered") >/dev/null 2>&1; then
        log_info "Netplan already up to date: $SRVCTL_NETPLAN_FILE"
        return 0
    fi

    tmp_file="$(mktemp "${target_dir}/.99-srvctl.yaml.XXXXXX")"
    printf '%s\n' "$rendered" > "$tmp_file"
    mv "$tmp_file" "$SRVCTL_NETPLAN_FILE"
    log_info "Netplan written: $SRVCTL_NETPLAN_FILE"
}
