#!/bin/bash

set -ouex pipefail

### 1. Enable Required COPR Repositories
# This adds the custom repositories for Niri, DMS, and Ghostty
dnf5 -y copr enable avengemedia/danklinux
dnf5 -y copr enable avengemedia/dms
dnf5 -y copr enable scottames/ghostty

### 2. Install the Complete Ecosystem
# This installs the Wayland compositor, the shell, the terminal, and essentials
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
    lxqt-policykit \
    dcal

### 3. Install Himalaya CLI (Direct Binary)
# Downloading the pre-compiled binary directly to avoid F44 COPR conflicts
curl -Lo /usr/bin/himalaya https://github.com/pimalaya/himalaya/releases/latest/download/himalaya-linux-amd64
chmod +x /usr/bin/himalaya

### 4. Disable COPRs
# This is a best practice so they don't cause conflicts during future updates
dnf5 -y copr disable avengemedia/danklinux
dnf5 -y copr disable avengemedia/dms
dnf5 -y copr disable scottames/ghostty

### 5. Enable System Services
# This ensures your login screen automatically starts when you boot
systemctl enable greetd.service

### 6. Bake in Default Dotfiles
# This creates the system skeleton folder and copies your configurations into it
mkdir -p /etc/skel/.config
cp -a /ctx/skel/.config/* /etc/skel/.config/
