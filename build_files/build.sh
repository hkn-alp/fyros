#!/bin/bash
set -ouex pipefail

### 1. Enable Required COPR Repositories
dnf5 -y copr enable avengemedia/danklinux
dnf5 -y copr enable avengemedia/dms
dnf5 -y copr enable scottames/ghostty
dnf5 -y copr enable atim/starship

### 2. Install the Complete Ecosystem (Added missing System Check packages!)
dnf5 install -y --allowerasing \
    niri \
    dms \
    dms-greeter \
    dgop \
    accountsservice \
    dsearch \
    matugen \
    cliphist \
    ghostty \
    nautilus \
    gnome-network-displays \
    network-manager-applet \
    xdg-desktop-portal-gtk \
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
    zsh-syntax-highlighting \
    power-profiles-daemon \
    cups-pk-helper \
    kf6-kimageformats

### 3. Install Himalaya CLI (Direct Binary)
curl -Lo /usr/bin/himalaya https://github.com/pimalaya/himalaya/releases/latest/download/himalaya-linux-amd64
chmod +x /usr/bin/himalaya

### 4. Disable COPRs
dnf5 -y copr disable avengemedia/danklinux
dnf5 -y copr disable avengemedia/dms
dnf5 -y copr disable scottames/ghostty
dnf5 -y copr disable atim/starship

### 5. Flatpak First-Boot Pre-installer
mkdir -p /usr/lib/systemd/system/

cat << 'EOF' > /usr/lib/systemd/system/flatpak-preinstall.service
[Unit]
Description=Install Custom Flatpaks on First Boot
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStartPre=/usr/bin/flatpak remote-add --system --if-not-exists valent https://valent.andyholmes.ca/valent.flatpakrepo
ExecStartPre=/usr/bin/flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
ExecStart=/usr/bin/flatpak install --system -y valent ca.andyholmes.Valent
ExecStart=/usr/bin/flatpak install --system -y flathub dev.zed.Zed
ExecStartPost=/usr/bin/systemctl disable flatpak-preinstall.service

[Install]
WantedBy=multi-user.target
EOF

systemctl enable flatpak-preinstall.service

### 6. Enable Core System Services
systemctl enable greetd.service
systemctl --global enable add-wants niri.service dms.service
systemctl enable power-profiles-daemon.service

### 7. Bake in Custom User Dotfiles
mkdir -p /etc/skel/.config
cp -a /ctx/skel/.config/* /etc/skel/.config/ 2>/dev/null || true
cp -a /ctx/skel/.[a-zA-Z0-9]* /etc/skel/ 2>/dev/null || true

#### 8. Existing User Dotfile Injector
# Safely copies all dotfiles to existing accounts without overwriting user data
mkdir -p /usr/lib/systemd/user/
cat << 'EOF' > /usr/lib/systemd/user/fyros-dotfiles.service
[Unit]
Description=Inject All Fyros Dotfiles for Existing Users
# Check if our custom injection has ever run for this user before
ConditionPathExists=!%h/.local/state/fyros-dotfiles-injected

[Service]
Type=oneshot
# 1. Create the state directory just in case it doesn't exist
ExecStartPre=/usr/bin/mkdir -p %h/.local/state
# 2. Safely copy ALL skel files. The -n flag means NEVER overwrite existing files!
ExecStart=/usr/bin/cp -rn /etc/skel/. %h/
# 3. Leave a hidden stamp so systemd knows the job is done and never runs this again
ExecStartPost=/usr/bin/touch %h/.local/state/fyros-dotfiles-injected

[Install]
WantedBy=default.target
EOF

systemctl --global enable fyros-dotfiles.service

### 9. Configure DMS Greeter as the Default Login Canvas
mkdir -p /etc/greetd

cat << 'EOF' > /etc/greetd/config.toml
[terminal]
vt = 1

[default_session]
command = "dms-greeter --command niri"
user = "greetd"
EOF

mkdir -p /usr/lib/tmpfiles.d
cat << 'EOF' > /usr/lib/tmpfiles.d/greetd.conf
d /var/lib/greetd 0755 greetd greetd - -
d /var/cache/dms-greeter 0755 greetd greetd - -
EOF

mkdir -p /usr/lib/systemd/system/greetd.service.d
cat << 'EOF' > /usr/lib/systemd/system/greetd.service.d/tmpfiles-wait.conf
[Unit]
After=systemd-tmpfiles-setup.service
Requires=systemd-tmpfiles-setup.service
EOF

### 10. Fyros Custom Branding
echo "fyros" > /etc/hostname

# 1. Overwrite the OS Identity with our custom static file
cp /ctx/branding/os-release /usr/lib/os-release

# 2. Dynamically inject the build date (Rolling Release!)
BUILD_DATE=$(date +'%Y.%m.%d')
sed -i "s/VERSION=\"1.0\"/VERSION=\"${BUILD_DATE}\"/" /usr/lib/os-release
sed -i "s/PRETTY_NAME=\"Fyros\"/PRETTY_NAME=\"Fyros ${BUILD_DATE}\"/" /usr/lib/os-release

# 3. Apply the Boot & UI Logos
mkdir -p /usr/share/plymouth/themes/spinner/
mkdir -p /usr/share/pixmaps/
cp /ctx/branding/watermark.png /usr/share/plymouth/themes/spinner/watermark.png 2>/dev/null || true
cp /ctx/branding/fyros-logo.png /usr/share/pixmaps/fyros-logo.png 2>/dev/null || true

### 11. Custom System Wallpapers
mkdir -p /usr/share/backgrounds/fyros
cp -a /ctx/wallpapers/* /usr/share/backgrounds/fyros/ 2>/dev/null || true

### 12. Image Size Optimization (Moved to the very end!)
dnf5 clean all
rm -rf /var/cache/* /tmp/*
