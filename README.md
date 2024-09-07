## Erffy Dotfiles
- My config files.

### Installation
```sh
# clone repository
git clone https://github.com/erffy/dotfiles.git
# install required packages (requires root)
pacman -S --needed $(cat dotfiles/packages)
# copy repository contents to HOME
cp -r dotfiles/.* $HOME
# enable Update Lock service
systemctl --user daemon-reload
systemctl --user enable --now updatelock
# restart system
reboot
```
