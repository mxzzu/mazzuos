#!/bin/bash

set -ouex pipefail

## DNF5 Speedup
sed -i '/^\[main\]/a max_parallel_downloads=10' /etc/dnf/dnf.conf

## 2. Remove COSMIC Shell and Waybar
dnf -y remove cosmic-comp cosmic-initial-setup cosmic-settings cosmic-settings-daemon cosmic-store 

## 3. Install GNOME DE
dnf group install -y "GNOME Desktop Environment"
dnf install -y gdm gnome-session gnome-shell nautilus
systemctl enable gdm.service

# System apps
dnf install -y libvirt virt-manager qemu-kvm bitwarden-cli

# User apps
dnf install -y kitty zsh

# Nautilus open any terminal extension
curl -Lo /etc/yum.repos.d/nautilus-open-any-terminal.repo \
  https://copr.fedorainfracloud.org/coprs/monkeygold/nautilus-open-any-terminal/repo/fedora-$(rpm -E %fedora)/monkeygold-nautilus-open-any-terminal-fedora-$(rpm -E %fedora).repo
dnf install -y nautilus-open-any-terminal
glib-compile-schemas /usr/share/glib-2.0/schemas
gsettings set com.github.stunkymonkey.nautilus-open-any-terminal terminal kitty

# Installing Terminal Font
mkdir -p /usr/share/fonts/maple-mono-nf
curl -L -o /tmp/MapleMono-NF.zip https://github.com/subframe7536/maple-font/releases/download/v7.9/MapleMono-NF.zip
dnf install -y unzip
unzip -o /tmp/MapleMono-NF.zip -d /usr/share/fonts/maple-mono-nf/
rm /tmp/MapleMono-NF.zip
fc-cache -f -v

# Copy Kitty Config
mkdir -p /etc/skel/.config/kitty
cp -rf /ctx/dot_config/kitty/kitty.conf /etc/skel/.config/kitty/

systemctl enable podman.socket

## 5. ZSH & Starship Configuration 
sed -i 's|SHELL=/bin/bash|SHELL=/bin/zsh|' /etc/default/useradd

mkdir -p /etc/zsh
cat << 'EOF' > /etc/zsh/zshrc
# Inizializzazione globale di Zsh
if [ -x "$(command -v starship)" ]; then
    eval "$(starship init zsh)"
fi

# Mantieni il completamento e la storia base
autoload -U compinit && compinit
HISTFILE=~/.zsh_history
HISTSIZE=1000
SAVEHIST=1000
setopt appendhistory

# Importa gli alias globali se esistono ancora
if [ -f /etc/profile.d/origami-aliases.sh ]; then
    source /etc/profile.d/origami-aliases.sh
fi
EOF

# Install Spinner Theme
dnf install -y plymouth-theme-spinner
plymouth-set-default-theme spinner
true

# Disable Origami tips
sudo mv /etc/profile.d/origami-aliases.sh /etc/profile.d/origami-aliases.sh.bak

## CLEAN UP
# Clean up dnf cache to reduce image size
dnf5 -y clean all
rm -rf /run/dnf /run/selinux-policy
rm -rf /var/lib/dnf
