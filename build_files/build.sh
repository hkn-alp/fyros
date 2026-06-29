#!/bin/bash
set -ouex pipefail

### 1. Enable Required COPR Repositories
dnf5 -y copr enable avengemedia/danklinux
dnf5 -y copr enable avengemedia/dms
dnf5 -y copr enable scottames/ghostty
dnf5 -y copr enable atim/starship
dnf5 -y copr enable lihaohong/yazi

### 2. Purge Base Image Bloat
# Ripping out the native versions so we can use Flatpaks or our preferred apps
dnf5 remove -y firefox firefox-langpacks alacritty nvtop htop btop

### 3. Install the Hyper-Optimized Native Ecosystem
dnf5 install -y --allowerasing --exclude=alacritty \
    niri \
    cliphist \
    ghostty \
    nautilus \
    network-manager-applet \
    cava \
    brightnessctl \
    playerctl \
    zsh \
    starship \
    zsh-autosuggestions \
    zsh-syntax-highlighting \
    power-profiles-daemon \
    cups-pk-helper \
    input-remapper \
    gnome-firmware \
    tailscale \
    grim \
    slurp \
    swappy \
    gvfs \
    gcr \
    i2c-tools \
    ddcutil \
    yazi \
    ffmpegthumbnailer \
    7zip \
    jq \
    poppler-utils \
    fd-find \
    ripgrep \
    fzf \
    zoxide \
    ImageMagick \
    adw-gtk3-theme \
    xdg-desktop-portal-gtk \
    xdg-desktop-portal-gnome \
    papirus-icon-theme \
    dms \
    dms-greeter \
    dgop \
    dsearch \
    dcal \
    matugen \
    xdg-user-dirs \
    fastfetch
    
# Install Qt Wayland and Theming backends
dnf5 install -y --setopt=install_weak_deps=False \
    qt5ct \
    qt6ct \
    qt5-qtwayland \
    qt6-qtwayland

# Destroy the Qt Settings app launcher icons
rm -f /usr/share/applications/qt5ct.desktop /usr/share/applications/qt6ct.desktop 2>/dev/null || true

### 5. Disable COPRs
dnf5 -y copr disable avengemedia/danklinux
dnf5 -y copr disable avengemedia/dms
dnf5 -y copr disable scottames/ghostty
dnf5 -y copr disable atim/starship
dnf5 -y copr disable lihaohong/yazi

### 6. The Global Flatpak Installer
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

# Attempt to install Valent independently
ExecStartPre=-/usr/bin/flatpak install --system -y valent ca.andyholmes.Valent

# Loop to install Flatpak Apps
ExecStart=/bin/bash -c 'for app in dev.zed.Zed org.mozilla.firefox io.github.kolunmi.Bazaar io.github.flattool.Warehouse com.github.tchx84.Flatseal org.gnome.Snapshot org.gnome.SoundRecorder org.gnome.TextEditor com.ranfdev.DistroShelf org.gnome.Boxes io.gitlab.adhami3310.Impression org.gnome.World.PikaBackup org.gnome.baobab org.gnome.Connections org.gnome.FileRoller org.gnome.NetworkDisplays io.github.hkdb.Aerion org.gnome.Loupe org.gnome.Showtime org.gnome.Papers org.gnome.Maps org.gnome.Calculator com.github.jeromerobert.pdfarranger com.github.xournalpp.xournalpp; do /usr/bin/flatpak install --system -y flathub "$app" || true; done'

ExecStartPost=/usr/bin/systemctl disable flatpak-preinstall.service

[Install]
WantedBy=multi-user.target
EOF

systemctl enable flatpak-preinstall.service

### 7. Enable Core System Services
systemctl enable greetd.service
systemctl --global enable dms.service
systemctl enable power-profiles-daemon.service
systemctl enable tailscaled.service
systemctl --global enable gcr-ssh-agent.socket

# Lock DMS so it ONLY runs inside Niri
mkdir -p /usr/lib/systemd/user/dms.service.d
cat << 'EOF' > /usr/lib/systemd/user/dms.service.d/niri-only.conf
[Unit]
ConditionEnvironment=XDG_CURRENT_DESKTOP=niri
EOF

# Enable hardware DDC/CI control for external monitors
mkdir -p /usr/lib/modules-load.d
echo "i2c-dev" > /usr/lib/modules-load.d/i2c.conf

### 8. Bake in Custom User Dotfiles
mkdir -p /etc/skel/.config
cp -a /ctx/skel/.config/* /etc/skel/.config/ 2>/dev/null || true
cp -a /ctx/skel/.[a-zA-Z0-9]* /etc/skel/ 2>/dev/null || true
cp -a /ctx/skel/.var /etc/skel/ 2>/dev/null || true

# Bake the DMS KDEConnect Plugin into the system skeleton
echo "Fetching dankKDEConnect plugin..."
mkdir -p /etc/skel/.config/DankMaterialShell/plugins
JSON_URL="https://raw.githubusercontent.com/AvengeMedia/dms-plugin-registry/master/plugins/dank-kdeconnect.json"

PLUGIN_JSON=$(curl -sL "$JSON_URL")
PLUGIN_REPO=$(echo "$PLUGIN_JSON" | jq -r '.repo')
PLUGIN_PATH=$(echo "$PLUGIN_JSON" | jq -r '.path // empty')

if [[ "$PLUGIN_REPO" != http* ]]; then
    PLUGIN_REPO="https://github.com/${PLUGIN_REPO}.git"
fi

if [[ -n "$PLUGIN_PATH" ]]; then
    echo "Monorepo detected. Extracting $PLUGIN_PATH..."
    git clone --depth 1 "$PLUGIN_REPO" /tmp/dms-plugin-repo
    mkdir -p /etc/skel/.config/DankMaterialShell/plugins/dankKDEConnect
    cp -a "/tmp/dms-plugin-repo/$PLUGIN_PATH/." "/etc/skel/.config/DankMaterialShell/plugins/dankKDEConnect/"
    rm -rf /tmp/dms-plugin-repo
else
    echo "Dedicated repo detected. Cloning..."
    git clone "$PLUGIN_REPO" /etc/skel/.config/DankMaterialShell/plugins/dankKDEConnect
fi

#### 9. Existing User Dotfile Injector
mkdir -p /usr/lib/systemd/user/
cat << 'EOF' > /usr/lib/systemd/user/fyros-dotfiles.service
[Unit]
Description=Inject All Fyros Dotfiles for Existing Users
ConditionPathExists=!%h/.local/state/fyros-dotfiles-injected

[Service]
Type=oneshot
ExecStartPre=/usr/bin/mkdir -p %h/.local/state
ExecStart=/usr/bin/cp -rn /etc/skel/. %h/
ExecStart=/usr/bin/sed -i "s|HOME_PLACEHOLDER|%h|g" %h/.config/DankMaterialShell/settings.json
ExecStartPost=/usr/bin/xdg-user-dirs-update
ExecStartPost=/usr/bin/touch %h/.local/state/fyros-dotfiles-injected

[Install]
WantedBy=default.target
EOF

systemctl --global enable fyros-dotfiles.service

### 10. Configure DMS Greeter as the Default Login Canvas
mkdir -p /etc/greetd

cat << 'EOF' > /etc/greetd/config.toml
[terminal]
vt = 1

[default_session]
command = "/usr/bin/dms-greeter --command niri --cache-dir /var/cache/dms-greeter -C /etc/greetd/niri/config.kdl"
user = "greetd"
EOF

# Bake the Niri configurations needed specifically for the login screen
mkdir -p /etc/greetd/niri

cat << 'EOF' > /etc/greetd/niri/config.kdl
hotkey-overlay {
    skip-at-startup
}

environment {
    DMS_RUN_GREETER "1"
}

gestures {
    hot-corners {
        off
    }
}

layout {
    background-color "#000000"
}

include "/etc/greetd/niri/dms.kdl"
EOF

cat << 'EOF' > /etc/greetd/niri/dms.kdl
input {
    keyboard {
        xkb
        numlock
    }
    touchpad {
        tap
        natural-scroll
    }
    mouse
    trackpoint
}

debug {
    honor-xdg-activation-with-invalid-serial
}
EOF

# Move the pre-generated defaults into the immutable image's safe storage
mkdir -p /usr/share/dms-greeter/
cp /ctx/branding/greeter-defaults/session.json /usr/share/dms-greeter/default-session.json 2>/dev/null || true
cp /ctx/branding/greeter-defaults/colors.json /usr/share/dms-greeter/default-colors.json 2>/dev/null || true
cp /ctx/branding/greeter-defaults/settings.json /usr/share/dms-greeter/default-settings.json 2>/dev/null || true

# Instruct systemd to copy defaults into the volatile cache and assert strict greetd ownership
mkdir -p /usr/lib/tmpfiles.d
cat << 'EOF' > /usr/lib/tmpfiles.d/greetd.conf
d /var/lib/greetd 0755 greetd greetd - -
d /var/cache/dms-greeter 0775 greetd greeter - -
d /var/cache/dms-greeter/.local/state 0775 greetd greeter - -

C /var/cache/dms-greeter/session.json - - - - /usr/share/dms-greeter/default-session.json
C /var/cache/dms-greeter/colors.json - - - - /usr/share/dms-greeter/default-colors.json
C /var/cache/dms-greeter/settings.json - - - - /usr/share/dms-greeter/default-settings.json

Z /var/cache/dms-greeter/ - greetd greeter - -
Z /var/cache/dms-greeter/.local/ - greetd greeter - -
EOF

mkdir -p /usr/lib/systemd/system/greetd.service.d
cat << 'EOF' > /usr/lib/systemd/system/greetd.service.d/tmpfiles-wait.conf
[Unit]
After=systemd-tmpfiles-setup.service
Requires=systemd-tmpfiles-setup.service
EOF

### 11. Fyros Custom Branding
echo "fyros" > /etc/hostname

BUILD_DATE=$(date +'%Y.%m.%d')
sed -i "s/^NAME=.*/NAME=\"Fyros\"/" /usr/lib/os-release
sed -i "s/^DEFAULT_HOSTNAME=.*/DEFAULT_HOSTNAME=\"fyros\"/" /usr/lib/os-release
sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"Fyros ${BUILD_DATE}\"/" /usr/lib/os-release
sed -i "s|^ID=fedora|ID=fyros\nID_LIKE=\"fedora\"|" /usr/lib/os-release
sed -i "s|^VARIANT_ID=.*|VARIANT_ID=fyros|" /usr/lib/os-release
sed -i "s/^LOGO=.*/LOGO=fyros-logo/" /usr/lib/os-release
sed -i "s/^ANSI_COLOR=.*/ANSI_COLOR=\"0;38;2;255;54;75\"/" /usr/lib/os-release
sed -i "s|^HOME_URL=.*|HOME_URL=\"https://github.com/hkn-alp/fyros\"|" /usr/lib/os-release
sed -i "s|^DOCUMENTATION_URL=.*|DOCUMENTATION_URL=\"https://github.com/hkn-alp/fyros\"|" /usr/lib/os-release
sed -i "s|^SUPPORT_URL=.*|SUPPORT_URL=\"https://github.com/hkn-alp/fyros/issues\"|" /usr/lib/os-release
sed -i "s|^BUG_REPORT_URL=.*|BUG_REPORT_URL=\"https://github.com/hkn-alp/fyros/issues\"|" /usr/lib/os-release

# Fix GRUB bootloader path
sed -i "s|^EFIDIR=.*|EFIDIR=\"fedora\"|" /usr/sbin/grub2-switch-to-blscfg

mkdir -p /usr/share/plymouth/themes/spinner/
mkdir -p /usr/share/pixmaps/
cp /ctx/branding/watermark.png /usr/share/plymouth/themes/spinner/watermark.png 2>/dev/null || true
cp /ctx/branding/fyros-logo.png /usr/share/pixmaps/fyros-logo.png 2>/dev/null || true

### 12. Custom System Wallpapers
# Wipe default Fedora wallpapers to save image size
rm -rf /usr/share/backgrounds/f44 2>/dev/null || true
rm -rf /usr/share/backgrounds/fedora-workstation 2>/dev/null || true

# Install Fyros wallpapers
mkdir -p /usr/share/backgrounds/fyros
cp -a /ctx/wallpapers/* /usr/share/backgrounds/fyros/ 2>/dev/null || true

### 13. Bake in the Fyros Welcome Screen (MOTD)
mkdir -p /etc/profile.d/

cat << 'EOF' > /etc/profile.d/fyros-motd.sh
if [[ $- == *i* ]]; then
    clear
    
    # Run fastfetch using the Kitty graphics protocol to render the actual PNG logo
    fastfetch \
        --logo /usr/share/pixmaps/fyros-logo.png \
        --logo-type kitty \
        --logo-width 28 \
        --structure Title:Separator:OS:Host:Kernel:Uptime:Packages:Shell:Display:WM:Terminal:CPU:GPU:Memory:Disk:LocalIP

    echo -e "\e[1;31m=============================================================\e[0m"
    echo -e " \e[1;37m🔥 Welcome to Fyros OS — Atomic Wayland Architecture 🔥\e[0m"
    echo -e "\e[1;31m=============================================================\e[0m"
    echo -e " \e[1;36m📖 Documentation:\e[0m https://github.com/hkn-alp/fyros"
    echo -e " \e[1;36m🐛 Bug Reports:\e[0m   https://github.com/hkn-alp/fyros/issues"
    echo -e " \e[1;36m📦 Updates:\e[0m       Run \e[1;32msudo bootc upgrade\e[0m to fetch new layers."
    echo -e "\e[1;31m-------------------------------------------------------------\e[0m"
    echo -e " \e[1;33m💡 Quick Tip:\e[0m Press \e[1;37mSUPER + SHIFT + /\e[0m to view the dynamic"
    echo -e "               Niri keybind overlay at any time."
    echo -e "\e[1;31m=============================================================\e[0m"
    echo ""
fi
EOF

chmod +x /etc/profile.d/fyros-motd.sh

### 14. GUI Cleanups
# Remove Himalaya's desktop file so it doesn't clutter the graphical launcher with broken icons
rm -f /usr/share/applications/himalaya.desktop 2>/dev/null || true

### 15. Image Size Optimization
dnf5 clean all
rm -rf /var/cache/* /tmp/*
