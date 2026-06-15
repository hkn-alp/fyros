#!/bin/bash

set -ouex pipefail

### 1. Enable Required COPR Repositories
# This adds the custom repositories for Niri, DMS, and Ghostty
dnf5 -y copr enable avengemedia/danklinux
dnf5 -y copr enable avengemedia/dms

### 2. Install the Complete Ecosystem
# This installs the Wayland compositor, the shell, the terminal, and essentials
dnf5 install -y \
    niri \
    dms \
    quickshell \
    dms-greeter \
    dgop \
    dsearch \
    matugen \
    cliphist \
    alacritty \
    nautilus \
    lxqt-policykit

### 3. Disable COPRs
# This is a best practice so they don't cause conflicts during future updates
dnf5 -y copr disable avengemedia/danklinux
dnf5 -y copr disable avengemedia/dms

### 4. Enable System Services
# This ensures your login screen automatically starts when you boot
systemctl enable greetd.service
