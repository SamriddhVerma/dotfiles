# Shared Dotfiles

System-wide dotfiles for an Arch Linux + Hyprland desktop, stored in a shared
folder so every user on the machine can read and edit them, and symlink them
into their own `~/.config`.

Included configs:

| Folder       | Application | Links to                    |
| ------------ | ----------- | --------------------------- |
| `hypr`       | Hyprland    | `~/.config/hypr`            |
| `nvim`       | Neovim (LazyVim) | `~/.config/nvim`       |
| `quickshell` | Quickshell  | `~/.config/quickshell`      |

---

## 1. Shared folder setup (admin, one time)

The repo lives in `/opt/shared-configs` and is owned by a common group
(`sharedconfig`) so any member can edit the files.

```bash
# Create the shared group
sudo groupadd sharedconfig

# Add each user who should be able to edit the configs
sudo gpasswd -a <username> sharedconfig   # repeat per user

# Clone (or move) the repo into the shared location
sudo git clone git@github.com:SamriddhVerma/dotfiles.git /opt/shared-configs

# Give the group ownership of everything
sudo chgrp -R sharedconfig /opt/shared-configs

# Make it group-writable, and set the setgid bit on all directories so new
# files/dirs automatically inherit the sharedconfig group
sudo chmod -R g+rwX /opt/shared-configs
sudo find /opt/shared-configs -type d -exec chmod g+s {} +
```

> Group membership only takes effect on a new login — log out/in (or run
> `newgrp sharedconfig`) after being added.

Optional: set a default ACL so future files stay group-writable regardless of
each user's umask:

```bash
sudo setfacl -R -d -m g:sharedconfig:rwX /opt/shared-configs
```

---

## 2. Install the required packages

All configs target Arch Linux, installed with `pacman` (AUR helper such as
`yay`/`paru` needed for the AUR items).

```bash
# Core desktop (Hyprland session)
sudo pacman -S --needed \
  hyprland kitty thunar fuzzel \
  grim slurp wl-clipboard \
  brightnessctl playerctl \
  pipewire pipewire-pulse wireplumber \
  networkmanager upower bluez bluez-utils

# Neovim (LazyVim) + common tooling
sudo pacman -S --needed neovim git ripgrep fd

# AUR packages
yay -S quickshell mpvpaper
```

Optional, only if you run a hybrid NVIDIA setup (the wallpaper autostart uses
`prime-run`):

```bash
sudo pacman -S --needed nvidia-prime
```

Enable the required services:

```bash
sudo systemctl enable --now NetworkManager bluetooth
```

---

## 3. Symlink the configs into your `~/.config`

Point your personal config directories at the shared folder. Existing configs
are backed up first.

```bash
SRC=/opt/shared-configs
mkdir -p ~/.config

for cfg in hypr nvim quickshell; do
  # back up an existing real config if present
  [ -e ~/.config/$cfg ] && [ ! -L ~/.config/$cfg ] && \
    mv ~/.config/$cfg ~/.config/$cfg.bak

  ln -sfn "$SRC/$cfg" ~/.config/$cfg
done
```

Verify:

```bash
ls -l ~/.config/hypr ~/.config/nvim ~/.config/quickshell
```

Because the targets are symlinks into the shared repo, any edit you make (as a
`sharedconfig` member) is shared with every other user, and can be committed
back with `git`.

---

## Notes

- **Hyprland** uses the Lua config (`hypr/hyprland.lua`); make sure your
  Hyprland build supports the Lua configuration API. The `.bak` files are the
  previous plain-text config kept for reference.
- **Quickshell** is launched automatically from Hyprland (`qs`) and relies on
  the Pipewire, UPower, Bluetooth and NetworkManager services above.
- **Neovim** bootstraps its plugins on first launch via LazyVim; `git`,
  `ripgrep` and `fd` are required for full functionality.
