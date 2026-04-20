#!/usr/bin/env bash
set -euo pipefail

rhel_network_reload() {
    safe_exec systemctl reload NetworkManager
}

rhel_network_restart() {
    safe_exec systemctl restart NetworkManager
}
