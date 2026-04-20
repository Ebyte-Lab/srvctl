#!/usr/bin/env bash
set -euo pipefail

systemd_is_active() {
    local unit_name="$1"
    systemctl is-active --quiet "$unit_name"
}

systemd_reload_daemon() {
    safe_exec systemctl daemon-reload
}

systemd_restart_service() {
    local unit_name="$1"
    safe_exec systemctl restart "$unit_name"
}

systemd_enable_service() {
    local unit_name="$1"
    safe_exec systemctl enable "$unit_name"
}
