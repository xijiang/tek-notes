# Jellyfin Deployment on AlmaLinux 10 (Docker)

For your setup, **Docker is the superior choice** over RPM for several reasons:
1. **Isolation:** Jellyfin and its dependencies (like FFmpeg) won't conflict with AlmaLinux's base system.
2. **Hardware Acceleration:** Passing through your GPU (Intel QuickSync or AMD) is much easier to manage in Docker.
3. **Consistency:** It matches your existing Immich and NPM setup, allowing you to use your `update-docker.sh` script to keep it updated.

## 1. Preparation
Create the directory for Jellyfin:
```bash
mkdir -p ~/Music/jellyfin/{config,cache}
```

## 2. Docker Compose Configuration
Create `~/Music/jellyfin/docker-compose.yml`:

```yaml
services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    user: 1000:1000 # Your UID:GID
    network_mode: bridge
    ports:
      - 8096:8096
    volumes:
      - ./config:/config
      - ./cache:/cache
      - /mnt/backup_storage/media:/media # Assuming you have a 'media' folder on your HDD
    restart: 'unless-stopped'
    # Hardware Acceleration (Intel/AMD)
    devices:
      - /dev/dri/renderD128:/dev/dri/renderD128
      - /dev/dri/card0:/dev/dri/card0
```

## 3. Deployment Steps

1. **Permissions:**
   Ensure the media directory exists on your HDD:
   ```bash
   mkdir -p /mnt/backup_storage/media
   ```

2. **SELinux (Critical for AlmaLinux):**
   Allow Docker to access the new volumes:
   ```bash
   sudo chcon -Rt svirt_sandbox_file_t ~/Music/jellyfin /mnt/backup_storage/media
   ```

3. **Start the Service:**
   ```bash
   cd ~/Music/jellyfin
   docker compose up -d
   ```

4. **Firewall:**
   Open port 8096 for local access (optional, since NPM will handle external traffic):
   ```bash
   sudo firewall-cmd --permanent --add-port=8096/tcp
   sudo firewall-cmd --reload
   ```

## 4. Nginx Proxy Manager Integration

1. Go to your NPM Admin UI (`http://<internal-ip>:81`).
2. **Add Proxy Host**:
   - **Domain Names:** `media.xijiang.org`
   - **Scheme:** `http`
   - **Forward IP:** Your laptop's internal IP (e.g., `192.168.x.x`)
   - **Forward Port:** `8096`
   - **Websockets Support:** Enabled.
3. **SSL Tab**:
   - Select **Request a new SSL Certificate**.
   - Enable **Force SSL**.

## 5. Update Automation
Update your `update-docker.sh` to include Jellyfin:

```bash
# Add this to your update-docker.sh
echo "Updating Jellyfin..."
cd ~/Music/jellyfin
docker compose pull
docker compose up -d
```

## 6. Hardware Acceleration Setup
Once Jellyfin is running:
1. Access `https://media.xijiang.org`.
2. Go to **Dashboard > Playback > Transcoding**.
3. Set **Hardware acceleration** to:
   - **Intel QuickSync** (if Intel CPU).
   - **VAAPI** (if AMD or generic Intel).
4. Check "Enable hardware encoding".
