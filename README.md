
# srvctl (Linux Server Control)

**srvctl** is a modular, idempotent Linux server configuration framework designed for safety and predictability. Unlike standard bash scripts, it follows a strict **System Design Life Cycle** to prevent system lockouts and configuration drift.

Built with a layered architecture, it separates user intent from OS implementation, ensuring that your server configurations are applied safely, predictably, and with an automatic safety net.

---

## 🧠 Architecture Overview
The system is built on a layered architecture:
- **CLI Router (`bin/srvctl`):** Orchestrates commands and manages the execution flow.
- **Module Layer (`modules/`):** Domain-specific logic (Networking, System, Security).
- **Adapter Layer (`adapters/`):** Abstracted OS logic (e.g., Netplan/Systemd for Ubuntu, NetworkManager for RHEL).
- **State Store:** Persistent tracking of system changes (defaults to `/var/lib/srvctl/state.json`).
- **Core Engine (`core/`):** Handles shared logic like logging, safe execution, and backups.

## 🛡 Safety Features
- **Idempotency:** Running the same command multiple times results in no unnecessary system changes.
- **Auto-Rollback:** If the `verify()` phase fails after applying a change (e.g., losing network connectivity or SSH access), the system automatically restores the last known good configuration.
- **Atomic Writes:** Configuration files are never edited directly in-place. We use a temporary-copy-and-move strategy to prevent file corruption.
- **Dry-Run Mode:** See exactly what will change before it happens using the `--dry-run` flag.

---

## 📋 Requirements
- **OS:** Ubuntu 22.04+ (Initial MVP target)
- **Privileges:** Root / `sudo` access
- **Dependencies:** `jq`, `iproute2` (for the `ip` command), `netplan.io` 
*(Note: If installing via the `.deb` package, dependencies are handled automatically).*

---

## 🚀 Installation

### Option 1: Debian Package (Recommended for Ubuntu)
If you have the compiled `.deb` package (e.g., `srvctl_1.0.0-1_all.deb`), you can install it easily. This will automatically install dependencies and place files in the correct system directories (`/usr/bin/` and `/usr/share/srvctl/`).

```bash
sudo apt update
sudo apt install ./srvctl_1.0.0-1_all.deb

```

### Option 2: Manual Build & Install (From Source)

To build and install the Debian package directly from the source code:

```bash
# 1. Install build tools
sudo apt update && sudo apt install build-essential debhelper devscripts

# 2. Clone the repository
git clone [https://github.com/Ebyte-Lab/srvctl.git](https://github.com/Ebyte-Lab/srvctl.git)
cd srvctl

# 3. Build the Debian package
dpkg-buildpackage -us -uc

# 4. Install the newly built package (located one directory up)
sudo apt install ../srvctl_*.deb

```

---

## 💻 Usage

The basic syntax is:
`srvctl <domain> <module> <action> [options]`

### 1. Network Management

**Configure a Static IP:**

```bash
# See what will change (Dry-run)
sudo srvctl network static_ip plan --ip 192.168.1.50 --iface eth0

# Apply changes with auto-verify and rollback
sudo srvctl network static_ip apply --ip 192.168.1.50 --iface eth0

```

**Configure DHCP:**

```bash
sudo srvctl network dhcp apply --iface eth0

```

### 2. System Management

**Change Hostname:**

```bash
# Note: You must export the target or set it in your environment
export HOSTNAME_TARGET="prod-db-01"
sudo srvctl system hostname plan
sudo srvctl system hostname apply

```

### 3. Security Management

**Configure SSH (Disable Root Login & Password Auth):**

```bash
export SSH_PERMIT_ROOT_LOGIN="no"
export SSH_PASSWORD_AUTHENTICATION="no"
sudo srvctl security ssh_config apply

```

---

## 🛠 Module Lifecycle (The Contract)

Every module in `srvctl` enforces the following execution phases. If you are extending the framework, your module must implement these functions (e.g., `module_init`, `module_apply`):

1. **Init:** Environment and required command checks.
2. **Check:** Pre-condition validation (Input/System readiness).
3. **Plan:** Dry-run mode showing intended file diffs without making changes.
4. **Apply:** Atomic execution with mandatory backups.
5. **Verify:** Post-condition health checks (e.g., pinging the gateway).
6. **Rollback:** Automatic restoration on verification failure.

---

## 📂 Project Structure

```text
srvctl/
├── Makefile                # Defines system installation paths
├── debian/                 # Debian packaging metadata and rules
├── bin/
│   └── srvctl              # Main CLI entry point
├── core/                   # Core Engine Framework
│   ├── backup_manager.sh   # Config backup/restore logic
│   ├── executor.sh         # Safe command execution wrapper
│   ├── logger.sh           # Logging engine (Info, Warn, Error)
│   └── state_engine.sh     # JSON state management
├── modules/                # Domain Logic
│   ├── network/
│   │   ├── dhcp.sh
│   │   └── static_ip.sh
│   ├── security/
│   │   └── ssh_config.sh
│   └── system/
│       └── hostname.sh
├── adapters/               # OS Abstraction Layer
│   ├── rhel/
│   │   └── network.sh
│   └── ubuntu/
│       ├── netplan.sh
│       └── systemd.sh
├── lib/
│   └── common.sh           # Shared helper functions
└── tests/                  # Unit and Integration tests
    └── test_network.sh

```

---

## 🤝 Contributing

We welcome contributions! To add a new module:

1. Create a new folder under `modules/<domain>/`.
2. Create your module script (e.g., `firewall.sh`).
3. Implement the 6 standard lifecycle functions (`init`, `check`, `plan`, `apply`, `verify`, `rollback`).
4. Ensure your script is completely idempotent (it should safely exit `0` if the configuration is already applied).
5. Open a Pull Request.

---

## 📄 License

This project is licensed under the **Apache License 2.0**. See the `LICENSE` file for details.

```

```