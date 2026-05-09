
# Contributing to srvctl

First off, thank you for considering contributing to **srvctl**! 

`srvctl` is designed to be a highly predictable, safe, and idempotent configuration framework. Because we touch critical server infrastructure, we have strict design patterns. This guide will help you understand our architecture and how to successfully contribute to the project.

---

## 🛠 Development Environment Setup

1. **Fork the repository** on GitHub.
2. **Clone your fork** locally:
   ```bash
   git clone [https://github.com/](https://github.com/)<your-username>/srvctl.git
   cd srvctl

```

3. **Create a feature branch:**
```bash
git checkout -b feature/your-feature-name

```



---

## 🏗 Architecture Principles

To keep `srvctl` safe, we separate **intent** from **implementation**:

* **Modules (`modules/`):** Define *what* should happen (e.g., "Set a static IP"). They are OS-agnostic where possible.
* **Adapters (`adapters/`):** Define *how* it happens on a specific OS (e.g., "Write a Netplan file on Ubuntu").
* **Core (`core/`):** Handles shared framework logic (Logging, State Management, Backups, Execution).

---

## 📜 The Module Lifecycle Contract

Every new module added to `srvctl` **must** implement the following six bash functions. Replace `<module>` with your module's name (e.g., `firewall_init`).

### 1. `<module>_init`

Check for root privileges, validate environment variables, and ensure required system binaries (like `jq` or `iptables`) are installed using `require_cmd`.

### 2. `<module>_check`

Validate input parameters and current system readiness. If the user provided invalid data (like an improperly formatted IP address), fail here.

### 3. `<module>_plan`

The `--dry-run` phase. Show the user exactly what files will change or what commands will be executed. **Do not make any system changes in this phase.** Use `diff` to show intended file changes.

### 4. `<module>_apply`

Execute the configuration change.

* **Rule 1:** Always use `backup_create <file>` before modifying an existing configuration file.
* **Rule 2:** Use atomic writes. Create a temporary file, write your changes there, and use `mv` to replace the destination file.
* **Rule 3:** Update the state engine using `state_set "key" "value"` upon success.

### 5. `<module>_verify`

Run health checks to ensure the `apply` phase worked. (e.g., If you applied an IP address, ping the gateway; if you restarted SSH, verify the port is open). Return `0` on success, `1` on failure.

### 6. `<module>_rollback`

If `verify` fails, `srvctl` will automatically call this function.

* Use `backup_restore <file>` to revert file changes.
* Restart necessary services.
* Use `state_delete "key"` to clean up the state file.

---

## 💻 Coding Standards

* **Bash Strict Mode:** Every script MUST start with:
```bash
#!/usr/bin/env bash
set -euo pipefail

```


* **Idempotency is Mandatory:** Running your module twice should result in zero changes the second time. Always check if the desired state already exists before applying.
* **Execution:** Do not run system commands directly if they modify state. Wrap them in the safe executor so they respect dry-runs:
```bash
safe_exec systemctl restart sshd

```


* **Logging:** Do not use `echo` or `printf` for status updates. Use the built-in logger:
```bash
log_info "Applying firewall rules..."
log_warn "Port 22 is open."
log_error "Failed to find netplan config."

```



---

## 🚀 Submitting a Pull Request

1. **Test your code:** Ensure your module runs successfully and passes the idempotency test (running it twice does nothing the second time).
2. **Commit your changes:** Write clear, descriptive commit messages.
```bash
git commit -m "feat(network): add firewall module with ufw adapter"

```


3. **Push to your fork:**
```bash
git push origin feature/your-feature-name

```


4. **Open a Pull Request (PR):** Navigate to the original repository and click "New Pull Request". Describe your changes, why they are needed, and how you tested them.

Thank you for helping make Linux server management safer!

```

```