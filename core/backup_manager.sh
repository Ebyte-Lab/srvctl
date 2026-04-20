#!/usr/bin/env bash
set -euo pipefail

SRVCTL_BACKUP_DIR="${SRVCTL_BACKUP_DIR:-/var/lib/srvctl/backups}"

srvctl_backup_key() {
    local file_path="$1"
    local safe_name
    safe_name="${file_path#/}"
    safe_name="${safe_name//\//__}"
    printf '%s\n' "$safe_name"
}

srvctl_backup_latest() {
    local file_path="$1"
    local backup_key

    [[ -d "$SRVCTL_BACKUP_DIR" ]] || return 1
    backup_key="$(srvctl_backup_key "$file_path")"
    find "$SRVCTL_BACKUP_DIR" -maxdepth 1 -type f -name "${backup_key}.*.bak" -printf '%T@ %p\n' 2>/dev/null \
        | sort -n \
        | tail -n 1 \
        | cut -d' ' -f2-
}

backup_create() {
    local file_path="$1"
    local backup_key
    local timestamp
    local backup_file
    local latest_backup

    [[ -e "$file_path" ]] || return 0

    mkdir -p "$SRVCTL_BACKUP_DIR"
    backup_key="$(srvctl_backup_key "$file_path")"
    latest_backup="$(srvctl_backup_latest "$file_path" || true)"

    if [[ -n "$latest_backup" ]] && cmp -s "$file_path" "$latest_backup"; then
        log_info "Backup already up to date for $file_path"
        return 0
    fi

    timestamp="$(date '+%Y%m%d%H%M%S')"
    backup_file="$SRVCTL_BACKUP_DIR/${backup_key}.${timestamp}.bak"
    cp -a "$file_path" "$backup_file"
    log_info "Backup created: $backup_file"
}

backup_restore() {
    local file_path="$1"
    local latest_backup

    latest_backup="$(srvctl_backup_latest "$file_path" || true)"
    if [[ -z "$latest_backup" ]]; then
        log_error "No backup available for $file_path"
        return 1
    fi

    mkdir -p "$(dirname "$file_path")"
    cp -a "$latest_backup" "$file_path"
    log_info "Backup restored: $file_path from $latest_backup"
}
