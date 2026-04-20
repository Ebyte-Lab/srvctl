#!/usr/bin/env bash
set -euo pipefail

SRVCTL_STATE_FILE="${SRVCTL_STATE_FILE:-/var/lib/srvctl/state.json}"

srvctl_state_ensure() {
    local state_dir
    state_dir="$(dirname "$SRVCTL_STATE_FILE")"
    mkdir -p "$state_dir"
    if [[ ! -f "$SRVCTL_STATE_FILE" ]]; then
        printf '%s\n' '{}' > "$SRVCTL_STATE_FILE"
    fi
}

state_get() {
    local key="$1"
    local default_value="${2-}"

    srvctl_state_ensure

    if jq -e --arg key "$key" 'has($key)' "$SRVCTL_STATE_FILE" >/dev/null 2>&1; then
        jq -r --arg key "$key" '.[$key]' "$SRVCTL_STATE_FILE"
        return 0
    fi

    if [[ $# -ge 2 ]]; then
        printf '%s\n' "$default_value"
        return 0
    fi

    return 1
}

state_set() {
    local key="$1"
    local value="$2"
    local tmp_file

    srvctl_state_ensure
    tmp_file="$(mktemp)"
    jq --arg key "$key" --arg value "$value" '.[$key] = $value' "$SRVCTL_STATE_FILE" > "$tmp_file"
    mv "$tmp_file" "$SRVCTL_STATE_FILE"
}

state_delete() {
    local key="$1"
    local tmp_file

    srvctl_state_ensure
    tmp_file="$(mktemp)"
    jq --arg key "$key" 'del(.[$key])' "$SRVCTL_STATE_FILE" > "$tmp_file"
    mv "$tmp_file" "$SRVCTL_STATE_FILE"
}
