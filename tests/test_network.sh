#!/usr/bin/env bash
set -euo pipefail

TEST_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TEST_ROOT_DIR/lib/common.sh"
source "$TEST_ROOT_DIR/core/logger.sh"
source "$TEST_ROOT_DIR/core/state_engine.sh"
source "$TEST_ROOT_DIR/core/backup_manager.sh"
source "$TEST_ROOT_DIR/core/executor.sh"
source "$TEST_ROOT_DIR/adapters/ubuntu/netplan.sh"
source "$TEST_ROOT_DIR/modules/network/static_ip.sh"

assert_eq() {
    local expected="$1"
    local actual="$2"
    local name="$3"

    if [[ "$expected" == "$actual" ]]; then
        printf 'PASS: %s\n' "$name"
    else
        printf 'FAIL: %s\nexpected: %s\nactual:   %s\n' "$name" "$expected" "$actual"
        return 1
    fi
}

assert_fail() {
    local name="$1"
    shift

    if "$@"; then
        printf 'FAIL: %s\n' "$name"
        return 1
    fi

    printf 'PASS: %s\n' "$name"
}

setup_test_env() {
    TEST_TMP_DIR="$(mktemp -d)"
    TEST_BIN_DIR="$TEST_TMP_DIR/bin"
    TEST_LOG_FILE="$TEST_TMP_DIR/srvctl.log"
    TEST_STATE_FILE="$TEST_TMP_DIR/state.json"
    TEST_BACKUP_DIR="$TEST_TMP_DIR/backups"
    TEST_NETPLAN_FILE="$TEST_TMP_DIR/99-srvctl.yaml"
    mkdir -p "$TEST_BIN_DIR" "$TEST_BACKUP_DIR"

    export PATH="$TEST_BIN_DIR:$PATH"
    export SRVCTL_LOG_FILE="$TEST_LOG_FILE"
    export SRVCTL_STATE_FILE="$TEST_STATE_FILE"
    export SRVCTL_BACKUP_DIR="$TEST_BACKUP_DIR"
    export SRVCTL_NETPLAN_FILE="$TEST_NETPLAN_FILE"
    export STATIC_IP_IFACE="eth0"
    export STATIC_IP_ADDRESS="192.168.1.50"
    export STATIC_IP_CIDR="24"
    export SRVCTL_IP_CMD="ip"

    cat > "$TEST_BIN_DIR/ip" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "$1" in
    link)
        if [[ "$2" == "show" && "$3" == "dev" ]]; then
            case "$4" in
                eth0)
                    printf '2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 state UP qlen 1000\n'
                    exit 0
                    ;;
                fakeiface999)
                    exit 1
                    ;;
            esac
        fi
        ;;
    -o)
        if [[ "$2" == "link" && "$3" == "show" && "$4" == "dev" && "$5" == "eth0" ]]; then
            printf '2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 state UP qlen 1000\n'
            exit 0
        fi
        ;;
    -4)
        if [[ "$2" == "addr" && "$3" == "show" && "$4" == "dev" && "$5" == "eth0" ]]; then
            printf '2: eth0    inet 192.168.1.50/24 brd 192.168.1.255 scope global eth0\n'
            exit 0
        fi
        ;;
esac

exit 1
EOF
    chmod +x "$TEST_BIN_DIR/ip"

    cat > "$TEST_BIN_DIR/jq" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$1" == "-e" ]]; then
    exit 0
fi

if [[ "$1" == "--arg" ]]; then
    input_file="${@: -1}"
    if [[ -f "$input_file" ]]; then
        cat "$input_file"
    else
        printf '%s\n' '{}'
    fi
    exit 0
fi

cat "${@: -1}"
EOF
    chmod +x "$TEST_BIN_DIR/jq"

    cat > "$TEST_BIN_DIR/netplan" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'netplan %s\n' "$*"
EOF
    chmod +x "$TEST_BIN_DIR/netplan"

    cat > "$TEST_BIN_DIR/ping" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
    chmod +x "$TEST_BIN_DIR/ping"
}

test_valid_ipv4_accepts() {
    if valid_ipv4 '192.168.1.50'; then
        printf 'PASS: valid_ipv4 accepts 192.168.1.50\n'
    else
        printf 'FAIL: valid_ipv4 accepts 192.168.1.50\n'
        return 1
    fi
}

test_valid_ipv4_rejects() {
    if valid_ipv4 '999.x.y.z'; then
        printf 'FAIL: valid_ipv4 rejects 999.x.y.z\n'
        return 1
    fi
    printf 'PASS: valid_ipv4 rejects 999.x.y.z\n'
}

test_static_ip_check_bad_iface() {
    export STATIC_IP_IFACE="fakeiface999"
    assert_fail "static_ip_check fails on fakeiface999" static_ip_check
}

test_static_ip_plan_dry_run() {
    export STATIC_IP_IFACE="eth0"
    export STATIC_IP_ADDRESS="192.168.1.50"
    export DRY_RUN="true"
    printf '%s\n' "network:" "  version: 2" > "$TEST_NETPLAN_FILE"
    local before
    local after
    local output

    before="$(cat "$TEST_NETPLAN_FILE")"
    output="$(static_ip_plan 2>&1 || true)"
    after="$(cat "$TEST_NETPLAN_FILE")"

    assert_eq "$before" "$after" "static_ip_plan makes no changes" || return 1
    [[ "$output" == *"---"* || "$output" == *"No netplan changes required"* ]]
}

main() {
    local failures=0
    setup_test_env

    if ! test_valid_ipv4_accepts; then failures=$((failures + 1)); fi
    if ! test_valid_ipv4_rejects; then failures=$((failures + 1)); fi
    if ! test_static_ip_check_bad_iface; then failures=$((failures + 1)); fi
    if ! test_static_ip_plan_dry_run; then failures=$((failures + 1)); fi

    if [[ "$failures" -ne 0 ]]; then
        exit 1
    fi
}

main "$@"
