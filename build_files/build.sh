#!/bin/bash
set -ouex pipefail

### 1. Enable Required COPR Repositories
dnf5 -y copr enable avengemedia/danklinux
dnf5 -y copr enable avengemedia/dms
dnf5 -y copr enable scottames/ghostty
dnf5 -y copr enable atim/starship

### 2. Purge Base Image Bloat
# Ripping out the native versions so we can use Flatpaks or our preferred apps
dnf5 remove -y firefox firefox-langpacks alacritty

### 3. Install the Hyper-Optimized Native Ecosystem
dnf5 install -y --allowerasing \
    niri \
    dms \
    dms-greeter \
    dgop \
    dsearch \
    matugen \
    cliphist \
    ghostty \
    nemo \
    file-roller \
    gnome-network-displays \
    network-manager-applet \
    cava \
    brightnessctl \
    playerctl \
    mate-polkit \
    dcal \
    zsh \
    starship \
    zsh-autosuggestions \
    zsh-syntax-highlighting \
    power-profiles-daemon \
    cups-pk-helper \
    input-remapper \
    gnome-firmware \
    tailscale \
    btop \
    grim \
    slurp \
    swappy \
    gvfs \
    gcr

### 4. Install Himalaya CLI (Direct Binary)
curl -Lo /usr/bin/himalaya https://github.com/pimalaya/himalaya/releases/latest/download/himalaya-linux-amd64
chmod +x /usr/bin/himalaya

### 5. Disable COPRs
dnf5 -y copr disable avengemedia/danklinux
dnf5 -y copr disable avengemedia/dms
dnf5 -y copr disable scottames/ghostty
dnf5 -y copr disable atim/starship

### 6. The Fyros First-Boot Welcome App
# 1. Create the installation script (Changed to /usr/bin)
cat << 'EOF' > /usr/bin/fyros-welcome.sh
#!/bin/bash

# Ensure flathub and valent repos are active
flatpak remote-add --user --if-not-exists valent https://valent.andyholmes.ca/valent.flatpakrepo
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Launch the GUI Checklist with your COMPLETE app arsenal
CHOICES=$(zenity --list --checklist \
    --title="Welcome to Fyros" \
    --text="Select the applications you want to install to customize your system:" \
    --column="Install" --column="App ID" --column="Application" \
    TRUE "dev.zed.Zed" "Zed Code Editor" \
    TRUE "org.mozilla.firefox" "Firefox Browser" \
    TRUE "page.codeberg.bazaar.bazaar" "Bazaar (App Store)" \
    TRUE "io.github.flattool.Warehouse" "Warehouse (Flatpak Manager)" \
    TRUE "com.github.tchx84.Flatseal" "Flatseal (Permissions)" \
    TRUE "org.gnome.Snapshot" "Camera" \
    TRUE "org.gnome.SoundRecorder" "Sound Recorder" \
    TRUE "org.gnome.TextEditor" "Text Editor" \
    TRUE "ca.andyholmes.Valent" "Valent (Phone Sync)" \
    TRUE "io.github.dvlv.boxbuddy" "BoxBuddy (Distrobox Manager)" \
    TRUE "org.gnome.Boxes" "GNOME Boxes (Virtual Machines)" \
    TRUE "io.gitlab.adhami3310.Impression" "Impression (USB Flasher)" \
    TRUE "org.gnome.World.PikaBackup" "Pika Backup" \
    TRUE "org.gnome.baobab" "Disk Usage Analyzer" \
    TRUE "org.gnome.Connections" "Remote Connections" \
    --width=650 --height=600 --separator=" ")

# If the user clicks Cancel or closes the window, exit gracefully
if [ -z "$CHOICES" ]; then
    zenity --info --title="Setup Skipped" --text="You can always install these apps later via the terminal or Bazaar."
    rm -f ~/.config/autostart/fyros-welcome.desktop
    exit 0
fi

# Show a progress bar while installing the selected apps
(
    total_apps=$(echo $CHOICES | wc -w)
    current_app=0
    
    for APP in $CHOICES; do
        flatpak install --user -y $APP
        current_app=$((current_app + 1))
        percentage=$((current_app * 100 / total_apps))
        echo "$percentage"
        echo "# Installing $APP..."
    done
) | zenity --progress --title="Installing Applications" --text="Preparing setup..." --percentage=0 --auto-close

zenity --info --title="Setup Complete" --text="Your Fyros installation is fully customized and ready to use!"

# Self-destruct the autostart trigger so this NEVER runs again
rm -f ~/.config/autostart/fyros-welcome.desktop
EOF

chmod +x /usr/bin/fyros-welcome.sh

# 2. Create the Autostart trigger inside the user's skeleton folder
mkdir -p /etc/skel/.config/autostart
cat << 'EOF' > /etc/skel/.config/autostart/fyros-welcome.desktop
[Desktop Entry]
Type=Application
Name=Fyros Welcome Setup
Exec=/usr/bin/fyros-welcome.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

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

### 8. Bake in Custom User Dotfiles
mkdir -p /etc/skel/.config
cp -a /ctx/skel/.config/* /etc/skel/.config/ 2>/dev/null || true
cp -a /ctx/skel/.[a-zA-Z0-9]* /etc/skel/ 2>/dev/null || true

# Download and inject DMS plugins directly into the user skeleton
mkdir -p /etc/skel/.config/DankMaterialShell/plugins
HOME=/etc/skel dms plugins install dankKDEConnect

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
# Dynamically overwrite the placeholder with the user's real absolute path
ExecStart=/usr/bin/sed -i "s|HOME_PLACEHOLDER|%h|g" %h/.config/DankMaterialShell/settings.json
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

### 11. Fyros Custom Branding
echo "fyros" > /etc/hostname

BUILD_DATE=$(date +'%Y.%m.%d')
sed -i "s/^NAME=.*/NAME=\"Fyros\"/" /usr/lib/os-release
sed -i "s/^DEFAULT_HOSTNAME=.*/DEFAULT_HOSTNAME=\"fyros\"/" /usr/lib/os-release
sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"Fyros ${BUILD_DATE}\"/" /usr/lib/os-release
sed -i "s/^LOGO=.*/LOGO=fyros-logo/" /usr/lib/os-release
sed -i "s/^ANSI_COLOR=.*/ANSI_COLOR=\"0;38;2;255;54;75\"/" /usr/lib/os-release
sed -i "s|^HOME_URL=.*|HOME_URL=\"https://github.com/hkn-alp/fyros\"|" /usr/lib/os-release
sed -i "s|^DOCUMENTATION_URL=.*|DOCUMENTATION_URL=\"https://github.com/hkn-alp/fyros\"|" /usr/lib/os-release
sed -i "s|^SUPPORT_URL=.*|SUPPORT_URL=\"https://github.com/hkn-alp/fyros/issues\"|" /usr/lib/os-release
sed -i "s|^BUG_REPORT_URL=.*|BUG_REPORT_URL=\"https://github.com/hkn-alp/fyros/issues\"|" /usr/lib/os-release

mkdir -p /usr/share/plymouth/themes/spinner/
mkdir -p /usr/share/pixmaps/
cp /ctx/branding/watermark.png /usr/share/plymouth/themes/spinner/watermark.png 2>/dev/null || true
cp /ctx/branding/fyros-logo.png /usr/share/pixmaps/fyros-logo.png 2>/dev/null || true

### 12. Custom System Wallpapers
mkdir -p /usr/share/backgrounds/fyros
cp -a /ctx/wallpapers/* /usr/share/backgrounds/fyros/ 2>/dev/null || true

### 13. Image Size Optimization
dnf5 clean all
rm -rf /var/cache/* /tmp/*
