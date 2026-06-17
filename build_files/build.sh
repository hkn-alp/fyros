#!/bin/bash
set -ouex pipefail

### 1. Enable Required COPR Repositories
dnf5 -y copr enable avengemedia/danklinux
dnf5 -y copr enable avengemedia/dms
dnf5 -y copr enable scottames/ghostty
dnf5 -y copr enable atim/starship

### 2. Install the Complete Ecosystem
dnf5 install -y --allowerasing \
    niri \
    dms \
    dms-greeter \
    dgop \
    dsearch \
    matugen \
    cliphist \
    ghostty \
    nautilus \
    gnome-network-displays \
    network-manager-applet \
    xdg-desktop-portal-gnome \
    cava \
    qt6ct \
    qt6-qtmultimedia \
    brightnessctl \
    playerctl \
    lxqt-policykit \
    dcal \
    zsh \
    starship \
    zsh-autosuggestions \
    zsh-syntax-highlighting

### 3. Install Himalaya CLI (Direct Binary)
curl -Lo /usr/bin/himalaya https://github.com/pimalaya/himalaya/releases/latest/download/himalaya-linux-amd64
chmod +x /usr/bin/himalaya

### 4. Disable COPRs
# Disabled to prevent conflicts during future automatic system updates
dnf5 -y copr disable avengemedia/danklinux
dnf5 -y copr disable avengemedia/dms
dnf5 -y copr disable scottames/ghostty
dnf5 -y copr disable atim/starship

### 5. Flatpak First-Boot Pre-installer
# Silently installs Flatpaks the moment the host machine gets internet
mkdir -p /usr/lib/systemd/system/

cat << 'EOF' > /usr/lib/systemd/system/flatpak-preinstall.service
[Unit]
Description=Install Custom Flatpaks on First Boot
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
# 1. Add the Flathub Nightly remote specifically for Valent
ExecStartPre=/usr/bin/flatpak remote-add --system --if-not-exists valent https://valent.andyholmes.ca/valent.flatpakrepo

# 2. Add the standard Flathub remote for normal apps
ExecStartPre=/usr/bin/flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# 3. Install Apps
ExecStart=/usr/bin/flatpak install --system -y valent ca.andyholmes.Valent
ExecStart=/usr/bin/flatpak install --system -y flathub dev.zed.Zed

# 4. Disable this service so it doesn't try to reinstall on future reboots
ExecStartPost=/usr/bin/systemctl disable flatpak-preinstall.service

[Install]
WantedBy=multi-user.target
EOF

# Enable the first-boot pre-installer
systemctl enable flatpak-preinstall.service

### 6. Enable Core System Services
systemctl enable greetd.service

### 7. Bake in Custom User Dotfiles
# Safely copies all custom layouts and configs from your GitHub repo into the OS skeleton
mkdir -p /etc/skel/.config
cp -a /ctx/skel/.config/* /etc/skel/.config/ 2>/dev/null || true
cp -a /ctx/skel/.[a-zA-Z0-9]* /etc/skel/ 2>/dev/null || true

### 8. Configure DMS Greeter as the Default Login Canvas
mkdir -p /etc/greetd

cat << 'EOF' > /etc/greetd/config.toml
[terminal]
vt = 1

[default_session]
command = "dms-greeter --command niri"
user = "greetd"
EOF

# Apply tmpfiles rules to guarantee cache directories exist on boot
mkdir -p /usr/lib/tmpfiles.d
cat << 'EOF' > /usr/lib/tmpfiles.d/greetd.conf
d /var/lib/greetd 0755 greetd greetd - -
d /var/cache/dms-greeter 0755 greetd greetd - -
EOF

# Force systemd to wait for those cache directories before starting the login screen
mkdir -p /usr/lib/systemd/system/greetd.service.d
cat << 'EOF' > /usr/lib/systemd/system/greetd.service.d/tmpfiles-wait.conf
[Unit]
After=systemd-tmpfiles-setup.service
Requires=systemd-tmpfiles-setup.service
EOF

### 9. Image Size Optimization
# Clears all downloaded DNF5 package data, saved info, and temp caches
dnf5 clean all
rm -rf /var/cache/* /tmp/*
