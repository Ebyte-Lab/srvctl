# srvctl (Linux Server Control)

**srvctl** is a modular, idempotent Linux server configuration framework designed for safety and predictability. Unlike standard bash scripts, it follows a strict **System Design Life Cycle** to prevent system lockouts and configuration drift.

## 🧠 Architecture Overview
The system is built on a layered architecture to separate user intent from OS implementation:
- **CLI Router:** Orchestrates commands and manages the execution flow.
- **Module Layer:** Domain-specific logic (Networking, Security, DNS).
- **Adapter Layer:** Abstracted OS logic (Netplan for Ubuntu, Network-scripts for RHEL).
- **State Store:** Persistent tracking of system changes in `/var/lib/srvctl/state.json`.

## 🛠 Module Lifecycle (The Contract)
Every module in `srvctl` must implement the following phases:
1. **Init:** Environment and permission checks.
2. **Check:** Pre-condition validation (Input/System readiness).
3. **Plan:** Dry-run mode showing intended file diffs.
4. **Apply:** Atomic execution with mandatory backups.
5. **Verify:** Post-condition health checks.
6. **Rollback:** Automatic restoration on verification failure.

## 🚀 Getting Started

### Prerequisites
- Ubuntu 22.04+ (Initial MVP target)
- Root/Sudo privileges

### Installation
```bash
git clone https://github.com/yourusername/srvctl.git
cd srvctl
chmod +x bin/srvctl
sudo ln -s $(pwd)/bin/srvctl /usr/local/bin/srvctl
```

### Usage Examples
**Configure a Static IP:**
```bash
# Pre-flight check
srvctl network static-ip check --ip 192.168.1.50 --iface eth0

# See what will change (Dry-run)
srvctl network static-ip plan --ip 192.168.1.50

# Apply changes with auto-verify and rollback
srvctl network static-ip apply --ip 192.168.1.50
```
This is a senior-level project setup. It reflects the **Layered Architecture** and **Module Lifecycle** we designed.

### 1. The Repository Structure
Create your GitHub repository with this directory layout. This structure ensures that domain logic (Modules) is separated from system logic (Adapters).

```text
srvctl/
├── bin/
│   └── srvctl              # Main entry point (the executable)
├── core/
│   ├── logger.sh           # Logging engine (Info, Warn, Error)
│   ├── state_engine.sh     # JSON state management
│   ├── backup_manager.sh   # Config backup/restore logic
│   └── executor.sh         # Safe command execution wrapper
├── modules/                # Domain Logic
│   ├── network/
│   │   ├── static_ip.sh    # Static IP implementation
│   │   └── dhcp.sh
│   ├── system/
│   │   └── hostname.sh
│   └── security/
│       └── ssh_config.sh
├── adapters/               # OS Abstraction Layer
│   ├── ubuntu/
│   │   ├── netplan.sh      # Ubuntu-specific network logic
│   │   └── systemd.sh
│   └── rhel/
│       └── network.sh
├── lib/
│   └── common.sh           # Shared helper functions
├── tests/                  # Unit and Integration tests
│   └── test_network.sh
└── README.md               # Documentation
```

---

### 2. The Main Entry Point (`bin/srvctl`)
This script routes commands like `srvctl network static-ip apply`.

```bash
#!/usr/bin/env bash

# srvctl: Senior-level Linux Configuration Tool
# Syntax: srvctl <domain> <module> <action> [options]

set -e

# Load Core Services
source "$(dirname "$0")/../core/logger.sh"
source "$(dirname "$0")/../core/executor.sh"

DOMAIN=$1
MODULE=$2
ACTION=$3

if [[ -z "$DOMAIN" || -z "$MODULE" || -z "$ACTION" ]]; then
    log_error "Usage: srvctl <domain> <module> <action>"
    exit 1
fi

# Route to the specific module
MODULE_PATH="$(dirname "$0")/../modules/$DOMAIN/$MODULE.sh"

if [[ -f "$MODULE_PATH" ]]; then
    source "$MODULE_PATH"
    # Execute the lifecycle action (e.g., static_ip_apply)
    "${MODULE}_${ACTION}"
else
    log_error "Module $DOMAIN/$MODULE not found."
    exit 1
fi
```

---


## 🛡 Safety Features
- **Idempotency:** Running the same command twice results in no system changes.
- **Auto-Rollback:** If `verify()` fails (e.g., SSH connection lost), the system automatically restores the last known good configuration.
- **Atomic Writes:** No configuration file is edited in-place; we use a temporary-copy-and-move strategy to prevent corruption.

## 📅 Roadmap
- [ ] Week 1: CLI Skeleton and Router
- [ ] Week 2: State Engine and Logging
- [ ] Week 3: Ubuntu Networking Adapters
- [ ] Week 4: Security and Hostname Modules
- [ ] Week 5: Rollback Engine Testing


---

### 4. How to Initialize the Project
Run these commands in your terminal to start:

```bash
mkdir -p srvctl/{bin,core,modules/{network,system,security},adapters/{ubuntu,rhel},lib,tests}
touch srvctl/bin/srvctl
touch srvctl/core/{logger,state_engine,backup_manager,executor}.sh
touch srvctl/README.md
chmod +x srvctl/bin/srvctl
```

**Why this works for your portfolio:**
1.  **Professionalism:** It shows you understand how to organize code at scale.
2.  **Safety:** The `bin/srvctl` script proves you can build a command router.
3.  **Clarity:** The `README` speaks the language of Senior Engineers (Idempotency, Atomicity, Abstraction).


