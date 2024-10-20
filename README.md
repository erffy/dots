![](assets/banner.png)

## Erffy Dotfiles
- My config files.

### Installation
```sh
# clone repository
git clone https://github.com/erffy/dots.git
# install required packages (requires root)
pacman -S --needed $(cat dots/packages)
# copy repository contents to HOME
cp -r dots/.* $HOME
# restart system
reboot
```