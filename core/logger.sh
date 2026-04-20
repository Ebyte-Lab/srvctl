#!/usr/bin/env bash
set -euo pipefail

SRVCTL_LOG_FILE="${SRVCTL_LOG_FILE:-/var/log/srvctl.log}"
SRVCTL_LOG_GREEN='\033[0;32m'
SRVCTL_LOG_YELLOW='\033[0;33m'
SRVCTL_LOG_RED='\033[0;31m'
SRVCTL_LOG_RESET='\033[0m'

srvctl_log_write() {
    local level="$1"
    local color="$2"
    shift 2
    local message="$*"
    local timestamp
    local line

    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    line="[$timestamp] [$level] $message"

    printf '%b%s%b\n' "$color" "$line" "$SRVCTL_LOG_RESET"
    mkdir -p "$(dirname "$SRVCTL_LOG_FILE")"
    printf '%s\n' "$line" >> "$SRVCTL_LOG_FILE"
}

log_info() {
    srvctl_log_write "INFO" "$SRVCTL_LOG_GREEN" "$@"
}

log_warn() {
    srvctl_log_write "WARN" "$SRVCTL_LOG_YELLOW" "$@"
}

log_error() {
    srvctl_log_write "ERROR" "$SRVCTL_LOG_RED" "$@"
}
