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
    qt6-qtmultimedia \
    ghostty \
    nautilus \
    lxqt-policykit \
    dcal \
    zsh \
    starship \
    zsh-autosuggestions \
    zsh-syntax-highlighting

### 3. Install Himalaya CLI
curl -Lo /usr/bin/himalaya https://github.com/pimalaya/himalaya/releases/latest/download/himalaya-linux-amd64
chmod +x /usr/bin/himalaya

### 4. DMS Configurations
git clone https://github.com/AvengeMedia/DankMaterialShell.git /tmp/dms-source
mkdir -p /etc/skel/.config
cp -r /tmp/dms-source/skel/.config/* /etc/skel/.config/ 2>/dev/null || true
rm -rf /tmp/dms-source

### 5. Disable COPRs
dnf5 -y copr disable avengemedia/danklinux
dnf5 -y copr disable avengemedia/dms
dnf5 -y copr disable scottames/ghostty
dnf5 -y copr disable atim/starship

### 6. Enable System Services
systemctl enable greetd.service

### 7. Bake in User Dotfiles
mkdir -p /etc/skel/.config
cp -a /ctx/skel/.config/* /etc/skel/.config/ 2>/dev/null || true
cp -a /ctx/skel/.[a-zA-Z0-9]* /etc/skel/ 2>/dev/null || true

### 8. Configure DMS Greeter as the Default Login
mkdir -p /etc/greetd

# Create a minimal Niri layout specifically for the login screen canvas
cat << 'EOF' > /etc/greetd/niri-greeter.kdl
layout {
    default-column-width { proportion 1.0; }
    focus-ring { off }
    border { off }
}
EOF

# Tell greetd to launch dms-greeter using the Niri canvas we just created
cat << 'EOF' > /etc/greetd/config.toml
[terminal]
vt = 1

[default_session]
command = "dms-greeter --command niri -C /etc/greetd/niri-greeter.kdl"
user = "greeter"
EOF
