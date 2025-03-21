> [!IMPORTANT]
> I'm no longer using Sway. Some configurations may be outdated.


![](assets/banner.png)

<br>

![](assets/desktop.png)

A minimalist desktop configuration for Arch Linux using SwayWM.

## Installation

### Prerequisites
Before proceeding with the installation, ensure you have a working Arch Linux installation.

### Backup Existing Configuration
First, backup your existing configuration files:
```sh
mkdir -p ~/dotfiles-backup
cp -r ~/.config ~/dotfiles-backup/
```

### Installation

1. Clone the repository:
```sh
git clone https://github.com/erffy/dots.git
cd dots
```

2. Install required packages:
```sh
# Using pacman
sudo pacman -S --needed - < packages

# Or using yay
yay -S --needed - < packages

# Or using paru
paru -S --needed - < packages
```

3. Copy configuration files:
```sh
# Create necessary directories
mkdir -p ~/.config ~/.local/share/applications

# Copy files (use -n to prevent overwriting existing files)
cp -rn .* ~/

# If you want to force overwrite, remove -n flag
# cp -r .* ~/
```

4. Apply permissions:
```sh
# Make scripts executable
chmod +x ~/.local/bin/* ~/.config/waybar/bin/*
```

5. Restart your system:
```sh
reboot
```
