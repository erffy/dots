## Erffy Dotfiles
- My config files.

### Installation
```sh
# clone repository
git clone https://github.com/erffy/dotfiles.git
# install required packages (requires root)
pacman -S --needed - < dotfiles/packages
# copy repository contents to HOME
cp -r dotfiles/* $HOME
# restart system
reboot
```