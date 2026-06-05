#!/bin/bash

set -ouex pipefail

## DNF5 Speedup
sed -i '/^\[main\]/a max_parallel_downloads=10' /etc/dnf/dnf.conf

## 2. Remove COSMIC Shell
dnf -y remove cosmic-*

## 3. Install GNOME DE
dnf install -y \
    gdm \
    gnome-shell \
    gnome-session \
    gnome-software \
    nautilus \
    gnome-control-center \
    gnome-terminal \
    gnome-tweaks \
    xdg-desktop-portal-gnome \
    gnome-keyring \
    gvfs-fuse \
    gnome-backgrounds \
    dconf-editor \
    gnome-shell-extension-dash-to-dock \
    gnome-settings-daemon \
    gnome-disk-utility \
    polkit-gnome \
    file-roller \
    gnome-system-monitor

systemctl enable gdm.service

# System apps
dnf install -y libvirt virt-manager qemu-kvm

# User apps
dnf install -y kitty zsh unzip

# Nautilus open any terminal extension
curl -Lo /etc/yum.repos.d/nautilus-open-any-terminal.repo \
  https://copr.fedorainfracloud.org/coprs/monkeygold/nautilus-open-any-terminal/repo/fedora-$(rpm -E %fedora)/monkeygold-nautilus-open-any-terminal-fedora-$(rpm -E %fedora).repo
dnf install -y nautilus-open-any-terminal

cat << 'EOF' > /usr/share/glib-2.0/schemas/99-mazzuos.gschema.override
[com.github.stunkymonkey.nautilus-open-any-terminal]
terminal='kitty'
EOF

glib-compile-schemas /usr/share/glib-2.0/schemas
#gsettings set com.github.stunkymonkey.nautilus-open-any-terminal terminal kitty

# Installing Terminal Font
mkdir -p /usr/share/fonts/maple-mono-nf
curl -L -o /tmp/MapleMono-NF.zip https://github.com/subframe7536/maple-font/releases/download/v7.9/MapleMono-NF.zip
unzip -o /tmp/MapleMono-NF.zip -d /usr/share/fonts/maple-mono-nf/
rm /tmp/MapleMono-NF.zip
fc-cache -f -v

# Copy Kitty Config
mkdir -p /etc/skel/.config/kitty
cp -rf /ctx/dot_config/kitty/kitty.conf /etc/skel/.config/kitty/

systemctl enable podman.socket

## 5. ZSH & Starship Configuration 
cat << 'EOF' > /usr/local/bin/set-user-shell.sh
#!/bin/bash
for user in $(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd); do
    usermod -s /bin/zsh "$user"
done
touch /var/lib/.shell-set
EOF
chmod +x /usr/local/bin/set-user-shell.sh

cat << 'EOF' > /etc/systemd/system/set-user-shell.service
[Unit]
Description=Set default shell to zsh for existing users
After=local-fs.target
ConditionPathExists=!/var/lib/.shell-set

[Service]
Type=oneshot
ExecStart=/usr/local/bin/set-user-shell.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl enable set-user-shell.service

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

cp /etc/zsh/zshrc /etc/skel/.zshrc

# Install Spinner Theme
dnf -y remove origami-plymouth-theme || true
dnf install -y plymouth-theme-spinner
plymouth-set-default-theme spinner

# Disable Origami tips
mv /etc/profile.d/origami-aliases.sh /etc/profile.d/origami-aliases.sh.bak

## CLEAN UP
# Clean up dnf cache to reduce image size
dnf5 -y clean all
rm -rf /run/dnf /run/selinux-policy
rm -rf /var/lib/dnf
