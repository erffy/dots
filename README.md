![](assets/banner.png)

<br>

![](assets/desktop.png)

### Installation
#### 1. Clone repository
```sh
git clone https://github.com/erffy/dots.git
```

#### 2. Install required packages (aur-helper recommended, like [yay](https://github.com/Jguer/yay) or [paru](https://github.com/Morganamilo/paru) etc.)
```sh
pacman -S --needed $(cat dots/packages)
```

#### 3. Copy repository contents
```sh
cp -r dots/.* $HOME
```

#### 4. Restart system
```sh
reboot
```