# AlmaLinux 10 Home Server Setup Summary (Laptop)

This document summarizes the configuration of the home server (formerly `pi.xijiang.org`, now migrated to an AlmaLinux 10 laptop) for photo backups and secure remote access.

## 1. DNS & Dynamic DNS (DDNS)
*   **Domain:** `xijiang.org` (managed via Cloudflare).
*   **Subdomain:** `pi.xijiang.org`.
*   **DDNS Script:** A bash script (`cloudflare-ddns.sh`) runs via cron every 5 minutes to update the Cloudflare A record with the laptop's current public IP.
*   **Cloudflare Proxy:** Set to **Orange Cloud (Proxied)** to enable Cloudflare's SSL and security features.

## 2. SSH Hardening & Firewall
*   **Port Change:** SSH moved from default `22` to `49222` in `/etc/ssh/sshd_config`.
*   **Firewall (firewalld):**
    ```bash
    sudo firewall-cmd --permanent --add-port=49222/tcp
    sudo firewall-cmd --permanent --remove-service=ssh
    sudo firewall-cmd --permanent --add-service={http,https}
    sudo firewall-cmd --reload
    ```
*   **Security Recommendation:** Disable password authentication in favor of SSH Keys.

## 3. Laptop-Specific Configuration
To ensure the server stays online when the laptop lid is closed:
*   **Lid Settings:** Edit `/etc/systemd/logind.conf`:
    ```ini
    HandleLidSwitch=ignore
    HandleLidSwitchExternalPower=ignore
    HandleLidSwitchDocked=ignore
    ```
*   **Apply Changes:** `sudo systemctl restart systemd-logind`

## 4. Storage & Backup (Immich)
*   **Hardware:** 500GB HDD attached and mounted at `/mnt/backup_storage`.
*   **Mounting:** Persistent via `/etc/fstab` using UUID.
*   **Software:** **Immich** installed via Docker Compose.
*   **Data Path:** `UPLOAD_LOCATION` in the `.env` file points to the external HDD.
*   **SELinux:** Ensure Docker can access the mount:
    ```bash
    sudo chcon -Rt svirt_sandbox_file_t /mnt/backup_storage
    ```
    *Note: Alternatively, use the `:Z` flag in docker-compose volume mappings.*

## 5. HTTPS & Reverse Proxy
This layer manages SSL encryption and routes external traffic to internal services.

*   **Tool:** **Nginx Proxy Manager (NPM)** running in a standalone Docker container.
*   **Workflow:**
    1.  Incoming traffic hits `https://pi.xijiang.org` (Port 443).
    2.  NPM terminates SSL using a **Let's Encrypt** certificate.
    3.  NPM forwards traffic internally to the Immich server on port `2283`.
*   **Core Configuration (`docker-compose.yml`):**
    ```yaml
    services:
      app:
        image: 'jc21/nginx-proxy-manager:latest'
        ports:
          - '80:80'   # Required for Let's Encrypt verification
          - '81:81'   # Admin UI
          - '443:443' # HTTPS traffic
        volumes:
          - ./data:/data
          - ./letsencrypt:/etc/letsencrypt
    ```

### 5.1 Critical AlmaLinux Pitfalls & Solutions
During the May 2026 migration, several AlmaLinux-specific issues were identified:

*   **Port 80 Conflict:** AlmaLinux may have `httpd` (Apache) running by default. This must be stopped to allow NPM to start.
    ```bash
    sudo systemctl stop httpd
    sudo systemctl disable httpd
    ```
*   **Firewall Masquerading:** Docker networking on AlmaLinux often requires IP masquerading to allow containers to talk to the internet/host.
    ```bash
    sudo firewall-cmd --zone=public --add-masquerade --permanent
    sudo firewall-cmd --reload
    ```
*   **SELinux Blocking:** If NPM cannot write to its `data` folder or if you see "521" errors from Cloudflare, SELinux may be the cause. 
    *   *Test:* `sudo setenforce 0` (Set to permissive).
    *   *Fix:* `sudo chcon -Rt svirt_sandbox_file_t ./data ./letsencrypt`.
*   **NPM Proxy Host Settings:** When adding the host in the NPM UI:
    *   **Forward Host/IP:** Use the laptop's **Internal WiFi/Ethernet IP** (e.g., `192.168.x.x`) rather than `localhost` to ensure the two separate Docker stacks can communicate.
    *   **Websockets Support:** Must be **Enabled** for Immich to function correctly.
*   **App Connection/Backup Failure ("Unable to check version"):** Immich requires large upload limits and websocket headers to function correctly via its mobile app.
    *   In NPM Proxy Host > **Advanced**, add:
        ```nginx
        client_max_body_size 50000M;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        ```
*   **Cloudflare "521" Error:** This indicates the laptop is refusing the connection on Port 443. Ensure NPM is actually running (`docker ps`) and that an SSL certificate has been successfully issued in the NPM "SSL" tab.

## 6. Automated System Updates
On AlmaLinux, **dnf-automatic** is used for security patches.
*   **Installation:** `sudo dnf install -y dnf-automatic`
*   **Configuration:** Edit `/etc/dnf/automatic.conf`:
    ```ini
    upgrade_type = security
    apply_updates = yes
    ```
*   **Enable:** `sudo systemctl enable --now dnf-automatic.timer`

## 7. Automated Docker Updates
To keep Immich and NPM updated with the latest features and security fixes, a weekly update script is configured as a **user-level systemd service**.

*   **Update Script (`update-docker.sh`):**
    ```bash
    #!/bin/bash
    set -e
    cd ~/Music/npm && docker compose pull && docker compose up -d
    cd /mnt/backup/immich-app && docker compose pull && docker compose up -d
    docker image prune -f
    ```
*   **Automation:** Managed via user-level systemd timer (`docker-update.timer`) to run every Sunday at 3:00 AM.
*   **Deployment:**
    1. Create the local bin directory: `mkdir -p ~/.local/bin`.
    2. Place `update-docker.sh` in `~/.local/bin/` and `chmod +x`.
    3. Place `.service` and `.timer` files in `~/.config/systemd/user/`.
    4. `systemctl --user daemon-reload`
    5. `systemctl --user enable --now docker-update.timer`
*   **Manual Run:** `systemctl --user start docker-update.service`
*   **Check Logs:** `journalctl --user -u docker-update.service` or `tail -f /var/log/docker-update.log`
*   **Persistence:** Ensure the user session stays active after logout: `sudo loginctl enable-linger xijiang`.

## 8. Credentials Reference
*   **Immich:** Access via `https://pi.xijiang.org`.
*   **NPM Admin:** Access via `http://<Internal-IP>:81`.
*   **SSH:** `ssh -p 49222 <user>@pi.xijiang.org`.

## 8. Photo Management & Safety
*   **Safe Deletion:** Always use the **"Free up device storage"** feature within the Immich app.
*   **The 3-2-1 Rule:**
    *   **3** copies of data (Original + Laptop HDD + Backup).
    *   **2** different media types (HDD + Cloud/Second HDD).
    *   **1** copy offsite.
*   **Recommendation:** Periodically sync `/mnt/backup_storage` to another drive or encrypted cloud storage.

---
*Last Updated: May 9, 2026*
