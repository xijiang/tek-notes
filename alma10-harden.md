# AlmaLinux 10 Laptop Server Hardening Summary

This document summarizes the configuration for a laptop running AlmaLinux 10 to behave as a reliable and secure server.

## 1. Laptop Power Management (Lid Switch)
To prevent the laptop from sleeping when the lid is closed, a drop-in override was created.
*   **File:** `/etc/systemd/logind.conf.d/ignore-lid.conf`
*   **Configuration:**
    ```ini
    [Login]
    HandleLidSwitch=ignore
    HandleLidSwitchExternalPower=ignore
    HandleLidSwitchDocked=ignore
    ```
*   **Apply:** `sudo systemctl restart systemd-logind`

## 2. Automatic Security Updates
AlmaLinux uses `dnf-automatic` to keep the system patched.
*   **Installation:** `sudo dnf install dnf-automatic -y`
*   **Configuration:** Set `apply_updates = yes` in `/etc/dnf/automatic.conf`.
*   **Activation:** `sudo systemctl enable --now dnf-automatic.timer`

## 3. SSH Hardening (RHEL/AlmaLinux Specific)
You can choose to stay on the standard port or use a custom one to reduce automated bot noise.

### Option A: Standard Port 22 (Convenient)
*   **Requirement:** Must be paired with **Fail2Ban** and **SSH Keys** (disable passwords) to prevent brute-force attacks.
*   **Firewall:** `sudo firewall-cmd --permanent --add-service=ssh`

### Option B: Custom Port 49222 (Hardened)
*   **SELinux Update:** `sudo semanage port -a -t ssh_port_t -p tcp 49222`
*   **Firewall Update:** `sudo firewall-cmd --permanent --add-port=49222/tcp`

### Common Steps:
*   **Apply Firewall:** `sudo firewall-cmd --reload`
*   **SSH Config:** Modify `/etc/ssh/sshd_config` to set your chosen `Port` and `PermitRootLogin no`.
*   **Restart:** `sudo systemctl restart sshd`

## 4. Firewall Management
AlmaLinux uses `firewalld`.
*   **Status:** `sudo firewall-cmd --state`
*   **Permit Services:** Use `firewall-cmd --permanent --add-service=...` for web (http/https) or other services.

## 5. Intrusion Prevention (Fail2Ban)
Fail2Ban is **essential**, especially if using Port 22, to block IPs after failed login attempts.
*   **Installation:** Requires EPEL (`sudo dnf install epel-release -y`), then `sudo dnf install fail2ban fail2ban-firewalld -y`.
*   **Configuration:** You **must** create `/etc/fail2ban/jail.local` to enable the protection:
    ```ini
    [sshd]
    enabled = true
    port = 22  # Change to 49222 if using Option B above
    maxretry = 5
    bantime = 1h
    ```
*   **Activation:** `sudo systemctl enable --now fail2ban`

## 6. System Integrity
*   **SELinux:** Must remain in `Enforcing` mode. Check with `getenforce`.
*   **User Management:** Avoid using the root account for daily tasks; use `sudo` with a standard user account.

## 7. Lenovo Battery Conservation
For laptops plugged in 24/7 (like servers), enabling "Conservation Mode" prevents battery swelling and degradation by limiting charge to 60%.
*   **Manual Enable:** `echo 1 | sudo tee /sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode`
*   **Persistence:** A systemd service `lenovo-battery-fix.service` should be created to apply this setting on every boot.
*   **Verification:** `cat /sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode` (1 = Active).

---
*Last Updated: April 23, 2026*
