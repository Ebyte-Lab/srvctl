#!/usr/bin/env bash
set -euo pipefail

srvctl_script_dir() {
    local source_path
    source_path="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
    cd "$(dirname "$source_path")" && pwd
}

srvctl_project_root() {
    local script_dir
    script_dir="$(srvctl_script_dir)"
    cd "$script_dir/.." && pwd
}

is_root() {
    [[ ${EUID:-0} -eq 0 ]]
}

iface_exists() {
    local iface="$1"
    local ip_cmd="${SRVCTL_IP_CMD:-ip}"
    "$ip_cmd" link show dev "$iface" >/dev/null 2>&1
}

valid_ipv4() {
    local ip_address="$1"
    local octet

    [[ "$ip_address" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1

    IFS='.' read -r -a octets <<< "$ip_address"
    for octet in "${octets[@]}"; do
        [[ "$octet" =~ ^[0-9]+$ ]] || return 1
        (( octet >= 0 && octet <= 255 )) || return 1
    done
}

require_cmd() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        if declare -F log_error >/dev/null 2>&1; then
            log_error "Required command not found: $command_name"
        else
            printf '%s\n' "ERROR: Required command not found: $command_name"
        fi
        exit 1
    fi
}
