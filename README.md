# Niri Desktop Configuration for Kali Linux

基于 Niri (Wayland 平铺窗口管理器) 的 Kali Linux 桌面配置，包含完整的 UI 主题、状态栏、锁屏和快捷键设置。

移植自这个cachyos[配置](https://github.com/LanRhyme/dotfiles)


## 目录结构

```
.
├── .gitignore              # 忽略 bin/ 与壁纸等大文件 (原因见文件内注释)
├── install_all.sh          # ★ 一键安装脚本 (basic / cachyos 两种模式)
├── install_noctalia.sh     # Noctalia v5 源码构建 + 安装脚本 (装到 ~/.local)
├── deploy_cachyos_config.sh# 部署 CachyOS 版配置到 ~/.config (备份 + 占位符替换 + 校验)
├── finish_sudo_setup.sh    # 需要 root 的收尾操作 (补装包 / satty / SDDM 背景软链)
├── bin/                    # 预编译二进制与安装包 —— ⚠️ 不进仓库, 见 bin/README.md
│   ├── niri_*.deb          # Niri 安装包
│   └── swww*               # 壁纸程序 (swww, swww-daemon)
├── config/                 # 用户配置 (部署到 ~/.config)
│   ├── fcitx5/             # 中文输入法
│   │   ├── config          # 按键/触发配置
│   │   ├── profile         # 输入法布局
│   │   └── conf/           # 拼音/界面等模块配置
│   ├── fuzzel/             # 应用启动器
│   │   └── fuzzel.ini      # Fuzzel 配置
│   ├── hypr/               # 锁屏
│   │   └── hyprlock.conf  # Hyprlock 样式
│   ├── kitty/              # 终端
│   │   └── kitty.conf     # Kitty 配置
│   ├── niri/               # Niri 主配置 (基础版)
│   │   └── config.kdl     # Niri 主配置
│   ├── niri-new/           # Niri 配置 (CachyOS 版, 按模块 include)
│   │   ├── config.kdl      # 主入口
│   │   └── cfg/            # autostart/keybinds/colors/display/... 分模块
│   ├── noctalia-new/       # Noctalia 一体化桌面壳 (CachyOS 版)
│   │   ├── config.toml     # v5 TOML 主配置
│   │   ├── settings.toml   # hooks: 壁纸变更触发 Morandi 取色
│   │   └── apply-morandi.sh / morandi-gen.py  # 全局配色生成
│   ├── satty/              # 截图标注编辑器
│   │   ├── config.toml     # 工具/输出配置
│   │   └── overrides.css   # 深色样式
│   ├── swaync/             # swaync 控制面板/通知中心
│   │   ├── config.json     # 位置/尺寸/组件
│   │   └── style.css       # 深色圆角主题
│   └── waybar/             # Waybar 状态栏 (左侧竖排)
│       ├── config.jsonc    # 模块配置
│       ├── style.css       # 样式
│       ├── power_menu.xml  # 电源菜单
│       └── power_status.sh # 电源状态脚本
├── sddm/                   # SDDM 登录主题 (部署到 /usr/share/sddm/themes/)
│   └── user/               # user 主题
│       ├── Main.qml        # 主界面
│       ├── theme.conf      # 主题配置
│       ├── Components/     # QML 组件
│       ├── assets/         # 资源文件
│       └── icons/          # 图标
├── scripts/                # 辅助脚本
│   └── ocr.sh             # OCR 脚本
└── wallpapers/             # 壁纸库 —— ⚠️ PNG 不进仓库 (含第三方作品, 且 43M)
    ├── __Main__.png        # 主壁纸
    ├── set-wallpaper.ps1   # 壁纸管理脚本 (自己写的, 保留)
    └── 1/                  # 随机壁纸轮换目录
```

## 快速安装 (推荐)

根目录的 `install_all.sh` 把下面「安装步骤」的全部操作串成一条命令，并修掉了手敲时最容易踩的坑。它适合已经准备好 Niri 的 Kali 主机；由于 Kali 没有 Niri/Noctalia/Swww 的完整发行版包，首次部署仍需要先按下方说明准备 Niri（或把预编译 deb 放进 `bin/`），Noctalia 还会进行源码编译：

```bash
./install_all.sh cachyos                  # niri + Noctalia 一体化 (推荐)
./install_all.sh basic                    # niri + waybar + swaync + swww + hyprlock + fuzzel
./install_all.sh cachyos -y --no-sddm     # 全自动 / 不动登录管理器
```

它会依次做：环境预检 → CRLF 修正 → apt 依赖(必需包一次装、可选包逐个装) → niri → swaync → swww / Noctalia →
字体 → 壁纸 → 部署配置(含占位符替换) → SDDM 主题 → `/etc/environment` → 自检清单。

> ⚠️ **先读这三条，否则一定卡住**
>
> 1. **本仓库不含 `bin/` 与壁纸 PNG**。`.gitignore` 把它们排除了：字体包 153M 超过 GitHub
>    单文件 100M 硬限制，壁纸 43M 且含第三方作品。从 GitHub 下载的包里这两个目录是**空的**，
>    而下面「2. 安装 Niri」「4. 安装 Swww」的方法 A 用的就是 `bin/` 里的文件 —— 要么向作者索取，
>    要么按各步骤的"方法 B"自行下载/编译。
> 2. **Kali 仓库里没有这 5 个包**（实测 `apt-cache policy` 全部 NOT-FOUND）：
>    `niri`、`niri-session`、`noctalia`、`swww`、`satty`。
>    前两个用预编译 deb，`swww` 用预编译二进制或自行编译，`satty` 从上游下载，`noctalia` **只能编译**。
> 3. **`swaync` 不用再编译了**（旧版本文说 Kali 没有，已过时）：kali-rolling 现提供
>    `sway-notification-center 0.12.6-1`，正是下面「5. 安装 SwayNC」让你编译的那个版本，
>    直接 apt 装 + 两个软链即可，**现有配置一行都不用改**。

## 安装步骤

### 1. 安装系统依赖

```bash
sudo apt update
sudo apt install --no-install-recommends sddm

sudo apt install  \
    hyprlock \
    waybar \
    fcitx5 fcitx5-chinese-addons \
    pavucontrol \
    kitty \
    fuzzel \
    procps \
    btop \
    mate-polkit \
    power-profiles-daemon \
    network-manager \
    fonts-font-awesome \
    xdg-user-dirs \
    xdg-utils \
    grim \
    slurp \
    wl-clipboard \
    tesseract-ocr tesseract-ocr-chi-sim tesseract-ocr-eng \
    translate-shell
```



#### 1.1 补充依赖（旧版清单漏掉的）

这些包被配置文件或键位真的用到，但旧版清单里没有：

```bash
sudo apt install  \
    playerctl \
    brightnessctl \
    libnotify-bin \
    mousepad \
    zsh \
    imagemagick \
    unzip \
    pipewire wireplumber \
    fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-frontend-qt6 \
    xdg-desktop-portal-gtk xdg-desktop-portal-wlr \
    gnome-keyring \
    upower
```

#### 1.2 satty

```bash
curl -fL --retry 3 -o /tmp/satty.tar.gz \
  https://github.com/Satty-org/Satty/releases/download/v0.20.1/satty-x86_64-unknown-linux-gnu.tar.gz
tar -xzf /tmp/satty.tar.gz -C /tmp
sudo install -m 755 /tmp/satty /usr/local/bin/satty
satty --version
```



### 2. 安装 Niri

Kali / Debian **没有任何 niri 二进制包**（仓库里只有 `librust-niri-ipc-dev` 和 `niri-companion`），
niri 上游 release 也**只发布源码**，所以只能走下面两条路之一。

```bash
# 方法 A: 使用预编译包 (bin/niri_26.4.0-1_amd64.deb, 22M)
cd bin
sudo apt install ./niri_26.4.0-1_amd64.deb

```

常见缺库与对应包（`libdisplay-info.so.3` 只在 Debian forky/sid 及当前 kali-rolling 上有；
Debian 13 "trixie" 只有 `libdisplay-info.so.2`，那份 deb 在 trixie 上装上也起不来）：

| 缺的 `.so` | Kali rolling / forky | Debian 13 trixie |
|---|---|---|
| `libdisplay-info.so.3` | `libdisplay-info3` (0.3.0) | ❌ 只有 `libdisplay-info2` (.so.2) → 需自行编译 niri |
| `libseat.so.1` | `libseat1` | `libseat1` |
| `libpipewire-0.3.so.0` | `libpipewire-0.3-0t64` | 同 |
| `libinput.so.10` `libgbm.so.1` `libxkbcommon.so.0` `libpixman-1.so.0` `libcairo.so.2` `libpango-1.0.so.0` `libpangocairo-1.0.so.0` `libudev.so.1` | `libinput10` `libgbm1` `libxkbcommon0` `libpixman-1-0` `libcairo2` `libpango-1.0-0` `libpangocairo-1.0-0` `libudev1` | 同 |

```bash
# 一条命令补齐 (Kali rolling)
sudo apt install -y libseat1 libpipewire-0.3-0t64 libdisplay-info3 \
    libinput10 libgbm1 libxkbcommon0 libpixman-1-0 libcairo2 \
    libpango-1.0-0 libpangocairo-1.0-0 libudev1

# 不确定某个 .so 属于哪个包时:
sudo apt install -y apt-file && sudo apt-file update && apt-file search libseat.so.1
```

```bash
# 方法 B: 从源码编译

# 1) 依赖 (比旧版清单多 7 个包: clang / libudev-dev / libdbus-1-dev / libsystemd-dev /
#    libpipewire-0.3-dev / libdisplay-info-dev / libegl1-mesa-dev)
sudo apt install -y gcc clang libudev-dev libgbm-dev libxkbcommon-dev \
    libegl1-mesa-dev libwayland-dev libinput-dev libdbus-1-dev libsystemd-dev \
    libseat-dev libpipewire-0.3-dev libpango1.0-dev libdisplay-info-dev

# 2) Rust: 官方要求"最新 stable"。Kali rolling 的 rustc 1.95 可以编 26.04,
#    但版本一旦落后就会编译失败, 建议用 rustup 固定工具链:
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 3) 编译 (⚠️ 千万别加 --all-features, 官方对此有明确警告)
git clone https://github.com/niri-wm/niri.git    # 上游已从 YaLTeR/niri 迁到 niri-wm/niri
cd niri && cargo build --release

# 4) 按官方推荐位置落盘 (niri.service 里写死的路径是 /usr/bin/niri)
sudo install -m755 target/release/niri          /usr/local/bin/niri
sudo install -m755 resources/niri-session       /usr/local/bin/niri-session
sudo install -Dm644 resources/niri.desktop      /usr/local/share/wayland-sessions/niri.desktop
sudo install -Dm644 resources/niri-portals.conf /usr/local/share/xdg-desktop-portal/niri-portals.conf
sudo install -Dm644 resources/niri.service resources/niri-shutdown.target /etc/systemd/user/
```

> 编译完必须确认 `/usr/share/wayland-sessions/niri.desktop`（方法 A 的 deb 里自带；
> 方法 B 用上面的 install 命令放到了 `/usr/local/share/wayland-sessions/`）——
> 少了它 SDDM 里就看不到 Niri 会话。

### 3. 安装字体

```bash
# 创建字体目录
mkdir -p ~/.local/share/fonts/MapleMono

# 方法 A: 使用项目自带字体包 (bin/MapleMonoNormal-NF-CN.zip)
#  bin/ 里的文件不在仓库里 ,
#  走方法 A 的话先把包下载/放到 bin/ 下
unzip bin/MapleMonoNormal-NF-CN.zip -d ~/.local/share/fonts/MapleMono/

# 方法 B: 从官方仓库下载 (原 Yermolai/MapleMono-NF-CN 仓库已失效)
wget -O MapleMonoNormal-NF-CN.zip "https://github.com/subframe7536/maple-font/releases/download/v7.9/MapleMonoNormal-NF-CN.zip"
unzip MapleMonoNormal-NF-CN.zip -d ~/.local/share/fonts/MapleMono/

# 安装 JetBrains Mono Nerd Font (备用)
sudo apt install fonts-jetbrains-mono

# 刷新字体缓存
fc-cache -fv
```

### 4. 安装 Swww (壁纸程序)

```bash
# 方法 A: 使用预编译二进制  
chmod +x bin/swww bin/swww-daemon
sudo install -m 755 bin/swww bin/swww-daemon /usr/local/bin/

# 方法 B: 从源码编译
# 旧版依赖清单不全, 而且漏了 MSRV:
#    · 上游 MSRV = Rust 1.87。Kali rolling 的 rustc 1.95 够用;
#      Debian 13 "trixie" 的 1.85 不够, 那种情况要先用 rustup 装新工具链。
#    · 除 wayland 外还需要 wayland-protocols 的 .xml (供 pkg-config 找到) 和 lz4。
sudo apt install -y cargo libwayland-dev wayland-protocols liblz4-dev scdoc
git clone https://github.com/LGFae/swww.git    # 上游已改名 awww 并搬到 Codeberg, 此地址仍可用
cd swww && cargo build --release
sudo install -m 755 target/release/swww target/release/swww-daemon /usr/local/bin/
```

> 方法 A 那两个二进制实测**几乎是静态链接**的：只依赖 `libc` `libgcc_s` `liblz4` `libm`
> （即有 `liblz4-1` 就能拷到别的 Kali 上跑），不必重新编译。

### 5. 安装 SwayNC (控制面板/通知中心)

**推荐：直接用发行版包。** 旧版写的"Kali 仓库暂无 swaync,需从源码编译"**已过时**：
kali-rolling 现在提供 `sway-notification-center 0.12.6-1`（Debian 13 trixie 是 0.11.0-1），
**正是旧版让你编译的那个版本**，而且省掉了整条编译链和 CSS 路径的坑：

```bash
sudo apt install sway-notification-center
swaync --version          # 应为 0.12.6

# 配置里写死了 ~/.local/bin/swaync*, 做两个软链即可完全兼容 —— 配置文件一行都不用改
mkdir -p ~/.local/bin
ln -sf /usr/bin/swaync        ~/.local/bin/swaync
ln -sf /usr/bin/swaync-client ~/.local/bin/swaync-client
```

> 用发行版包时系统 CSS 在 `/etc/xdg/swaync/style.css`，本来就在 swaync 的默认搜索路径里，
> 因此**不会**出现下面那个 `COULD NOT FIND CSS FILE` 的问题。
> niri 配置里的 `XDG_CONFIG_DIRS="$HOME/.local/etc/xdg:/etc/xdg"` 也包含 `/etc/xdg`，
> 所以那行不用动，两种安装方式都能用。
> 判断该走哪条路：`apt-cache policy sway-notification-center` 有 `Candidate:` 就用 apt。

<details>
<summary><b>备选：从源码编译</b>（仅当上面查不到 Candidate 时才需要）</summary>

```bash
# 安装编译依赖 (旧版这一步是对的, Kali 上这些包都有)
sudo apt install -y \
    meson ninja-build valac \
    libgtk-4-dev libadwaita-1-dev \
    libjson-glib-dev libgee-0.8-dev libgranite-7-dev \
    libnotify-dev libpulse-dev \
    libsoup-3.0-dev libgtk4-layer-shell-dev \
    blueprint-compiler sassc scdoc

# 获取源码 (github.com 直连超时的话走 gh-proxy 镜像)
wget -O /tmp/swaync.tar.gz "https://github.com/ErikReider/SwayNotificationCenter/archive/refs/tags/v0.12.6.tar.gz"
# 或: wget -O /tmp/swaync.tar.gz "https://gh-proxy.com/https://github.com/ErikReider/SwayNotificationCenter/archive/refs/tags/v0.12.6.tar.gz"

# 编译并安装到用户目录 (无需 root)
cd /tmp && tar xzf swaync.tar.gz && cd SwayNotificationCenter-0.12.6
meson setup build --prefix="$HOME/.local"
ninja -C build
ninja -C build install   # 安装到 ~/.local/bin/{swaync,swaync-client}
```

> ⚠️ **关键**: 装在 `~/.local` 时, swaync 的系统 CSS 在 `~/.local/etc/xdg/swaync/style.css`,
> 但它默认只在 `/etc/xdg` 和 `/usr/local/etc/xdg` 里找。找不到会打印
> `COULD NOT FIND CSS FILE! REINSTALL THE PACKAGE!` 并直接退出 (面板打不开)。
> 本项目已在 niri 里用 `XDG_CONFIG_DIRS` 指过去, 无需手动处理; 若你手动启动, 用:
>
> ```bash
> XDG_CONFIG_DIRS="$HOME/.local/etc/xdg:/etc/xdg" swaync &
> ```

### 6. 部署配置文件

```bash
# 备份现有配置 
for d in niri waybar hypr kitty fuzzel fcitx5 satty swaync fastfetch; do
    [ -e ~/.config/$d ] && mv ~/.config/$d ~/.config/$d.bak
done

# 复制配置文件
mkdir -p ~/.config/{niri,waybar,hypr,kitty,fuzzel,fcitx5,satty,swaync,fastfetch} ~/Documents/_zshrc/
cp -r config/niri/*      ~/.config/niri/
cp -r config/waybar/*    ~/.config/waybar/
cp -r config/hypr/*      ~/.config/hypr/
cp -r config/kitty/*     ~/.config/kitty/
cp -r config/fuzzel/*    ~/.config/fuzzel/
cp -r config/fcitx5/*    ~/.config/fcitx5/
cp -r config/satty/*     ~/.config/satty/
cp -r config/swaync/*    ~/.config/swaync/
cp -r config/fastfetch/* ~/.config/fastfetch/
cp -r scripts/ocr.sh     ~/Documents/_zshrc/ocr.sh
chmod +x ~/.config/waybar/power_status.sh ~/Documents/_zshrc/ocr.sh

# niri 的截图目录 (~/Pictures/Screenshots) 与基础版壁纸轮换目录
mkdir -p ~/Pictures/Screenshots ~/Pictures/wallpapers

# 替换路径占位符 —— ⚠️ 旧版这里写的是 sed 's|/home/zz|...|g', 但仓库里**早已没有
# /home/zz** (占位符统一叫 /home/YOUR_USERNAME), 所以那三行是死代码, 跑完
# ~/.config/waybar/config.jsonc 里仍然留着 /home/YOUR_USERNAME/...,
# 结果是状态栏电源按钮点了弹不出菜单。正确写法:
grep -rl 'YOUR_USERNAME' ~/.config | xargs -r sed -i "s|/home/YOUR_USERNAME|$HOME|g"
grep -rn 'YOUR_USERNAME' ~/.config || echo "占位符已全部替换"

# 校验 niri 配置语法
niri validate -c ~/.config/niri/config.kdl
```

> `Mod+S` 的 OCR 绑定写的是 `zsh ~/Documents/_zshrc/ocr.sh`，所以**必须装 zsh**
> （见 1.1），否则这个键位静默无效。`ocr.sh` 还依赖 `grim slurp tesseract-ocr
> tesseract-ocr-chi-sim translate-shell xdg-utils(mousepad) libnotify-bin`。

### 7. 部署 SDDM 登录主题

```bash
# 1) 复制主题文件
sudo cp -r sddm/user /usr/share/sddm/themes/

# 2) 壁纸: 桌面 / 锁屏 / 登录页共用同一张
#     wallpapers/ 被 .gitignore 排除 —— 从 GitHub 下载的包里没有这张图, 换成你自己的
sudo mkdir -p /usr/share/backgrounds/user
sudo cp wallpapers/__Main__.png /usr/share/backgrounds/user/    # 没有就换成自己的图

# 3) 修好主题里的背景软链
#    仓库里的 sddm/user/backgrounds/wall.png 是指向 /usr/share/backgrounds/user/__Main__.png
#    的**绝对路径软链**。用 U 盘/压缩包从 Windows 拷过来时软链会丢(目录整个消失),
#    登录页就没有背景; 而且 finish_sudo_setup.sh 的第 5 步会因为父目录不存在而失败。
sudo mkdir -p /usr/share/sddm/themes/user/backgrounds
sudo ln -sf /usr/share/backgrounds/user/__Main__.png \
            /usr/share/sddm/themes/user/backgrounds/wall.png
readlink /usr/share/sddm/themes/user/backgrounds/wall.png   # 应打印上面那个路径

# 4) 让 SDDM 使用此主题
#    旧版是 `... | sudo tee /etc/sddm.conf` —— tee 不带 -a 会**覆盖整个文件**,
#    清掉系统原有的 SDDM 配置。写 conf.d 片段更安全:
sudo mkdir -p /etc/sddm.conf.d
printf '[Theme]\nCurrent=user\n' | sudo tee /etc/sddm.conf.d/20-niri-user-theme.conf

# 5) SDDM 以 sddm 用户运行, 看不到 ~/.local/share/fonts ——
#    想让登录页用上 Maple 字体, 得往系统字体目录也放一份
sudo cp -r ~/.local/share/fonts/MapleMono /usr/local/share/fonts/ 2>/dev/null
sudo fc-cache -f >/dev/null
```

> ⚠️ **Kali 默认桌面是 XFCE，通常自带 lightdm**。两个显示管理器同时 enabled 会互抢 VT，
> 启用 sddm 后建议关掉另一个：
>
> ```bash
> systemctl is-enabled lightdm 2>/dev/null && sudo systemctl disable lightdm
> sudo systemctl enable sddm
> sudo systemctl set-default graphical.target
> ```

### 8. 中文输入

编辑 `/etc/environment`：

```bash
sudo tee -a /etc/environment >/dev/null <<'EOF'

# fcitx5输入法
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
INPUT_METHOD=fcitx
EOF

grep -i fcitx /etc/environment     # 检查; 改完需重新登录才生效
```

> 装好 `fcitx5` 本体只是第一步：GTK/Qt 程序还需要对应的 frontend（见 1.1 的
> `fcitx5-frontend-gtk3/gtk4/qt6`），否则浏览器、终端里可能切不出中文。
> 登录后确认它在跑：`pgrep -a fcitx5`。
> 基础版由 niri 的 `spawn-at-startup "fcitx5"` 拉起；**CachyOS 版没有这一行**，
> 依赖 xdg-autostart —— 如果 `pgrep` 不到，就在 `config/niri-new/cfg/autostart.kdl`
> 里补一行 `spawn-sh-at-startup "fcitx5"`。

## 启动配置

### 使用 SDDM 登录 (推荐)

```bash
# 启用 SDDM
sudo systemctl enable sddm
sudo systemctl set-default graphical.target
```

### 常驻组件启动方式

| 组件 | 启动方式 |
|------|----------|
| niri | SDDM Wayland 会话 (`/usr/share/wayland-sessions/niri.desktop`) |
| fcitx5 / swww / waybar / swaync | niri `spawn-at-startup` (见 `config/niri/config.kdl`) |

### 收尾脚本

`finish_sudo_setup.sh` 把"需要 root 的零碎操作"打包好了：补装 `playerctl / brightnessctl /
libnotify-bin / mousepad / libadwaita-1-0`、按需安装 satty、修 SDDM 主题的背景软链。

```bash
sudo bash finish_sudo_setup.sh
```

### 登录后自检

```bash
niri msg outputs                                # 显示器名, 与 cfg/display.kdl 不符就改
ldd "$(command -v niri)" | grep 'not found'     # 应无输出 (见第 2 步)
pgrep -a fcitx5                                 # 中文输入法在不在
command -v wpctl || echo "装 pipewire+wireplumber 后基础版音量键才有效"
command -v satty || echo "没装 satty: Mod+Shift+S 只能截图, 不能标注"
```




## 快捷键说明

> `Mod` 键 = `Alt` (在终端中) 或 `Super` (在窗口环境中)

### 窗口操作

| 快捷键 | 功能 |
|--------|------|
| `Mod + Q` | 关闭窗口 |
| `Mod + F` | 最大化列 |
| `Mod + Shift + F` | 全屏窗口 |
| `Mod + C` | 居中窗口 |
| `Mod + V` | 切换浮动状态 |
| `Mod + W` | 切换标签页模式 |

### 应用启动

| 快捷键 | 功能 |
|--------|------|
| `Mod + T` | 打开终端 (Kitty) |
| `Mod + D` | 应用启动器 (Fuzzel) |
| `Mod + E` | 打开文件管理器 |

### 工作区

| 快捷键 | 功能 |
|--------|------|
| `Mod + 1-9` | 切换到工作区 1-9 |
| `Mod + Ctrl + 1-9` | 移动窗口到工作区 |
| `Mod + PageUp/Down` | 切换上/下一个工作区 |

### 焦点移动

| 快捷键 | 功能 |
|--------|------|
| `Mod + H / Left` | 聚焦左侧窗口 |
| `Mod + J / Down` | 聚焦下方窗口 |
| `Mod + K / Up` | 聚焦上方窗口 |
| `Mod + L / Right` | 聚焦右侧窗口 |

### 布局调整

| 快捷键 | 功能 |
|--------|------|
| `Mod + R` | 切换预设列宽 |
| `Mod + +/-` | 减少/增加列宽 10% |
| `Mod + Shift + +/-` | 减少/增加窗口高度 10% |

### 系统功能

| 快捷键 | 功能 |
|--------|------|
| `Mod + N` | 打开控制面板/通知中心 (swaync) |
| `Mod + S` | 屏幕 OCR |
| `Mod + Shift + S` | 区域截图 (grim + satty) |

### 媒体控制

| 快捷键 | 功能 |
|--------|------|
| `音量 +/-` | 调节音量 |
| `静音键` | 静音开关 |
| `麦克风静音` | 麦克风静音 |
| `播放/暂停` | 媒体播放控制 |

### 亮度控制

| 快捷键 | 功能 |
|--------|------|
| `亮度 +/-` | 调节屏幕亮度 |

## 自定义配置

### 界面布局

- **左侧竖排状态栏**: `config/waybar/config.jsonc` 中 `"position": "left"`、`"width": 52`,从上到下依次为工作区 → 时钟 → 通知铃铛 → 系统托盘 → 电源按钮。
- **控制面板**: swaync 提供通知中心,右侧滑出,含勿扰开关、媒体播放器 (MPRIS)、通知列表。
  - `Mod + N` 或点击状态栏铃铛图标打开/关闭
  - 铃铛上**右键**清除全部通知
  - 图标随状态变化:空心铃铛 (无通知) / 实心铃铛 (有通知) / 斜杠铃铛 (勿扰)

想改状态栏宽度,改 `"width"` 即可;想调整竖排顺序,调整 `modules-right` 数组顺序(数组末尾最靠下)。

### 统一壁纸机制

桌面、锁屏、SDDM 登录页共用同**一个**壁纸文件 `/usr/share/backgrounds/user/__Main__.png`，改一张即三处统一：

| 场景 | 引用方式 |
|------|----------|
| 桌面 (swww) | `config/niri/config.kdl` → `spawn-at-startup "swww" "img" "/usr/share/backgrounds/user/__Main__.png"` |
| 锁屏 (hyprlock) | `config/hypr/hyprlock.conf` → `path = /usr/share/backgrounds/user/__Main__.png` |
| 登录 (SDDM) | `sddm/user/backgrounds/wall.png` 软链接 → `/usr/share/backgrounds/user/__Main__.png` |

### 修改壁纸

推荐用 `set-wallpaper.ps1`，它会校验 PNG、同步复制到上面这个统一壁纸源并立即应用到桌面：

```zsh
# 添加到zsh配置 ( 前提是装了 PowerShell: sudo apt install powershell
#                     —— kali-rolling 仓库里有, 实测 7.6.2)
alias wallpaper="pwsh ~/Pictures/wallpapers/set-wallpaper.ps1"
```

```bash
wallpaper 图片路径或轮换文件夹名   # 传文件 = 直接设置；传目录 = 随机选一张
```

> 脚本路径写的是 `~/Pictures/wallpapers/`，而仓库里的壁纸在 `wallpapers/`（不进 git）。
> 想直接用仓库里的脚本，把 `wallpapers/set-wallpaper.ps1` 复制到 `~/Pictures/wallpapers/`，
> 或者把 alias 改成脚本的实际位置。另外 `.gitignore` 里把它标注为"Windows 端管理脚本"，
> 但脚本调用的是 `sudo install` / `swww img`（Linux 侧命令），所以它实际是在**Kali 上**
> 用 pwsh 跑的 —— 两处说法不一致，按上面的用法即可。

手动方式（任意图片路径，不需要 PowerShell）：

```bash
sudo install -m 644 你的图片.png /usr/share/backgrounds/user/__Main__.png
swww img /usr/share/backgrounds/user/__Main__.png --transition-type any
```

锁屏与登录页无需额外操作，下次显示即自动换成新壁纸。

### Noctalia 版本说明（重要）

原 dotfiles 的 Noctalia 配置是 **v4** 时代的（Quickshell 架构：`settings.json`
`settingsVersion: 59` + `plugins.json` + `plugins/*.luau`）。

Noctalia **v5 是彻底重写**——原生 C++23 / OpenGL ES 程序，配置改为 **TOML**，
不读取 `settings.json`，官方明确说明 **v4 → v5 配置不迁移**。

因此本仓库的 `config/noctalia-new/config.toml` 是按 v5 schema **重新翻译**的，
不是原文件副本。原 `settings.json` / `plugins.json` / `plugins/` 在 v5 下不会被读取，
保留仅为存档（属于无害的死文件）。判断依据：原 dotfiles 的 niri 快捷键用的是 v5 语法
`noctalia msg ...`（v4 是 `noctalia-shell ipc call`），插件含 `plugin.toml` 清单。

### 1. 安装 Noctalia v5

官方 APT 源的包在 Kali 上依赖无法满足（`libxml2` / `libstdc++6` / `libwebp7`
版本对不上），**只能源码编译**：

```bash
cd /path/to/niri_for_kali-main     # 换成你自己的实际路径 (旧版写死了 ~/下载/...)
./install_noctalia.sh              # 首次运行会列出需要 sudo 安装的依赖并退出
sudo apt install -y <上面列出的包>
./install_noctalia.sh              # 再次运行: 编译 + 安装
```

装到 `~/.local` 前缀（**无需 root**），二进制为 `~/.local/bin/noctalia`。
niri 配置的 `environment { PATH }` 已包含该目录。

- 构建要求 GCC 13+（kali-rolling 实测 GCC 15.3，满足）；`just` 由发行版提供
  （kali-rolling 是 1.58，无需自己装）。
- 依赖清单里 `libcurl4-*-dev` 的坑见下面的说明块；脚本已经改成 gnutls 版。
- **不要只拷二进制**：Noctalia 运行时要 `share/noctalia/assets/`，脚本用的
  `just install release` 会一起装好（上游 `BUILDING.md` 明确写了这一点）。
- 想一步到位：`./install_all.sh cachyos` 会自动补依赖、编译并部署配置。

> **依赖坑（务必注意）**：上游 `BUILDING.md` 写的 `libcurl4-openssl-dev` 在 Kali/Debian 上
> **装不上** —— 它与 `libqalculate-dev`（Noctalia 计算器需要）所依赖的
> `libcurl4-gnutls-dev` **互斥**（Conflicts）。直接照抄会报
> `libcurl4-gnutls-dev 冲突 libcurl4-openssl-dev` / `Unable to satisfy dependencies`。
> 本仓库的 `install_noctalia.sh` 已改为 **`libcurl4-gnutls-dev`**。
> Noctalia 的 meson 只用 pkg-config 找 `libcurl`，两种 flavor 都提供 `libcurl.pc`，无副作用。

### 2. 部署配置

**推荐**：直接用仓库里的部署脚本（自动备份、替换占位符、部署 fcitx5 配置、校验语法）：

```bash
cd /path/to/niri_for_kali-main
./deploy_cachyos_config.sh
```

<details>
<summary><b>手动部署</b>（等价步骤，注意别漏掉第 3 步）</summary>

```bash
cd /path/to/niri_for_kali-main

# 1. 备份现有配置
mv ~/.config/niri       ~/.config/niri.bak-$(date +%F)      2>/dev/null || true
mv ~/.config/noctalia   ~/.config/noctalia.bak-$(date +%F)  2>/dev/null || true

# 2. 部署
cp -r config/niri-new     ~/.config/niri
cp -r config/noctalia-new ~/.config/noctalia
cp -r config/kitty-new/.  ~/.config/kitty/          # 用 . 合并: 别删掉 morandi.conf
cp -r config/fastfetch/.  ~/.config/fastfetch/
cp -r config/fcitx5/.     ~/.config/fcitx5/         # 中文输入法的 profile/简体拼音

# 3. 替换 /home/YOUR_USERNAME 占位符 —— 旧版手动步骤漏了这一步,
#    后果是 niri 的 environment{PATH} 里留着 /home/YOUR_USERNAME/.local/bin,
#    登录后找不到 noctalia, 状态栏/壁纸/锁屏全都不出现:
grep -rl 'YOUR_USERNAME' ~/.config | xargs -r sed -i "s|/home/YOUR_USERNAME|$HOME|g"
grep -rn 'YOUR_USERNAME' ~/.config || echo "占位符已全部替换"

# 4. 校验
niri validate -c ~/.config/niri/config.kdl
```

#### 壁纸目录与默认壁纸

Noctalia 的壁纸模块**不展开 `~` 也不展开 `$HOME`**（见 `config.toml` 里的注释），
所以 `[wallpaper] directory` 与 `[wallpaper.default] path` 写的是占位符
`/home/YOUR_USERNAME/Pictures/wallpapers`，由部署脚本替换成 `$HOME`。
**那个目录和默认壁纸要你自己准备**，否则登录后是纯色桌面：

```bash
mkdir -p ~/Pictures/wallpapers
cp <任意一张图>.png ~/Pictures/wallpapers/__Main__.png
# 或者登录后在控制中心 → 壁纸 里重新选一张 (会自动改写 state 里的值)
```

### 3. 配置的两层结构

Noctalia v5 按下列顺序加载，**后者覆盖前者**：

1. 程序内置默认值
2. `~/.config/noctalia/*.toml` ← 本仓库的 `config.toml`（手写）、`settings.toml`（hooks）
3. `~/.local/state/noctalia/settings.toml` ← **GUI 改设置时由程序写入**

所以：在设置界面里改过的项会覆盖 `config.toml` 里的同名项。若手写值「不生效」，
先看 `~/.local/state/noctalia/settings.toml`。

### 4. 从原 dotfiles 移植时做的必要改动

| 项目 | 原 dotfiles | 本仓库 | 原因 |
|---|---|---|---|
| 会话菜单 | `noctalia msg panel-toggle sessionMenu` | `panel-toggle session` | v5 的 panel id 已改为 `session`（v4 才是 `sessionMenu`） |
| `cfg/colors.kdl` | **缺失** | 新建（Morandi 静态配色占位） | niri 遇到 include 缺失会**拒绝加载整个配置** |
| NVIDIA 环境变量 | `__NV_PRIME_RENDER_OFFLOAD` 等 | 删除 | 本机 nvidia 驱动未加载（仅 i915），设置后 GL 程序起不来 |
| polkit 代理路径 | `/usr/lib/...` | 启动时探测 Debian/Kali 常见路径 | 不同安装方式的路径不同 |
| 显示器 | `DP-1` | 默认自动探测 | 配置不再写死某台机器的输出名，按需编辑 `cfg/display.kdl` |
| 终端 | ghostty | kitty | ghostty 官方**无 Linux 预编译包**，Kali 仓库也没有；外观已逐项移植，见「6. 终端样式」 |
| `clipse` / `kando` / `ugee` / `slugcatpet` | 有 | 删除 | Kali 无对应包，或为原作者个人工具 |
| 工作区背景 | — | `background-color "transparent"` | 让 Noctalia 壁纸层常驻可见（官方 Option 2） |
| 壁纸 / 头像路径 | 原作者的家目录 | 本机家目录 | 路径迁移，仓库里统一用 `/home/YOUR_USERNAME` 占位（见上） |
| 天气位置 | Zhejiang | Zhejiang（**请改成你自己的**） | 这是原作者的位置 |
| 遥测 | 开启 | 关闭 | 上游默认关闭，不代你开启上报 |
| 提示音 | v4 `notifications.sounds` | v5 `[audio] enable_sounds` | v5 把提示音统一到 `[audio]` |
| 程序坞占位 | 未设（吃默认 `reserve_space = true`） | `reserve_space = false` | 默认值下 **自动隐藏的 dock 仍会预留桌面空间**，窗口下方凭空多出 92px |

### 5. 已知的作者个人配置（请手动调整）

- **状态栏宽度**：`thickness = 29`。

  **改 `thickness` 时必须同时调 `scale`** —— 两者是分开的旋钮，`thickness` 只管栏有多宽，
  **不会连带缩放里面的图标和文字**（依据 `widget.h:101` `fontScale() = m_contentScale * m_fontScale`，
  图标同理乘 `m_contentScale`）。只收窄栏宽会让内容相对胶囊变大、顶出去：实测 `scale` 仍为 0.9 时
  sysmon 的 `34%` 宽 23px 已超出 22px 胶囊，4 字符的 `100%` 外推 ≈31px 会溢出 29px 栏体被裁。
  当前 `thickness = 29` + `scale = 0.72`。该值下 `34%` 宽 16px、`100%` ≈21px，均在 22px 胶囊内。
  想让文字在此基础上单独再大/小一点，用 `font_scale`（在 `scale` 之上再乘一次）。

- **v4 插件无对应**：`notes-scratchpad`、`kde-connect`、`micyou`、`github-feed` 未纳入
  （v5 插件体系完全不同，用 `noctalia/wallhaven:browser` 这类注册表 id）。

- **主题模板**：原配置启用 `zenBrowser / btop / steam / gtk / starship / code`，
  v5 内置集里只有 `btop / gtk3 / gtk4`（starship 由 `morandi-gen.py` 接管）。
  可用 `noctalia theme --list-templates` 查看全部。

- **`[idle]`（已改为屏幕常亮）**：原 dotfiles 是熄屏 600s / 锁屏 660s，现按需求
  **两项都关闭**（`enabled = false`）—— 屏幕不会自动变黑，也不会自动上锁。
  - 手动兜底仍在：`Mod+Shift+P` 熄屏、`Mod+Alt+L` 锁屏。
  - 只想**临时**常亮（看视频/读长文）：`noctalia msg caffeine-toggle`，
    或在控制中心加一个 `caffeine` 快捷开关，不必改配置。
  - 播放视频本就不会熄屏 —— v5 会响应应用的 D-Bus 空闲抑制请求
    （Chrome / Firefox / Steam / portal / logind）。
  - 想恢复自动行为：把 `config.toml` 里对应 `enabled` 改回 `true`，
    再 `noctalia msg config-reload`（无需重新登录）。
  - 注意：`enabled = false` 会让 `createBehavior()` 直接不注册
    `ext_idle_notification_v1` 对象，计时器在协议层面就不存在，比「到点不执行」更彻底。
  - 挂起（suspend）未启用，需要的话在 GUI 里加。

### 6. 终端样式（ghostty → kitty 移植）

原 dotfiles 用 **ghostty**，本机用 **kitty**。原因是 ghostty 官方 release
**只提供 macOS 二进制**（`Ghostty.dmg` / `ghostty-macos-universal.zip`）与源码 tarball，
**没有 Linux 预编译包**；Kali 仓库里也没有（`apt-cache search ghostty` 无结果），
系统亦无 flatpak / snap。要装只能自备 Zig 从源码构建，对本人这台 4 核 Broadwell 笔记本
代价过大。因此把 ghostty 的**外观与操作逐项映射**到 kitty。

配置在 `config/kitty-new/kitty.conf`，每条都标注了对应的 ghostty 原项。

#### 逐项对照

| ghostty | kitty | 说明 |
|---|---|---|
| `font-family = JetBrainsMono Nerd Font` | `font_family JetBrainsMono Nerd Font` | 同名字体，见下方「字体」 |
| `font-size = 12` | `font_size 12.0` | |
| `font-feature = calt` | **无需配置** | kitty 对每个字体**无条件开启 `calt`**（`fonts.c:491`） |
| `font-feature = liga` | **省略** | 该字体**没有 `liga` 表**，JetBrains Mono 的连字放在 `calt` 里 |
| `window-padding-x/y = 16` + `window-padding-balance = true` | `window_padding_width 16` | kitty 四边等宽，天然等价 balance |
| `window-decoration = true` | `hide_window_decorations no` | |
| `scrollback-limit = 10000` | `scrollback_lines 10000` | |
| `scrollbar = system` | `scrollbar scrolled` | kitty 无 `system` 取值，`scrolled` 最接近覆盖式滚动条 |
| `cursor-style = bar` | `cursor_shape beam` | kitty 管竖线叫 `beam` |
| `cursor-style-blink = true` | `cursor_blink_interval 0.5` | kitty 默认 `-1`（跟随系统），正值才强制闪 |
| `custom-shader = shaders/cursor.frag` | `cursor_trail 500` | **无法原样移植**，见下 |
| `mouse-hide-while-typing = true` | `mouse_hide_wait -1.0` | 负值 = 打字即隐藏指针 |
| `copy-on-select = true` | `copy_on_select clipboard` | |
| `keybind = ctrl+c=copy_to_clipboard` | `map ctrl+c copy_or_interrupt` | **不能照抄**，见下 |
| `keybind = ctrl+v=paste_from_clipboard` | `map ctrl+v paste_from_clipboard` | |
| `keybind = ctrl+0=reset_font_size` | `map ctrl+0 reset_font_size` | |
| `config-file = theme` | `include morandi.conf` | 同一套 Morandi 生成机制 |

#### 三处不能直接移植的地方

1. **`ctrl+c` 必须用 `copy_or_interrupt`，不能写 `copy_to_clipboard`。**
   原配置注释写的是 "Smart Ctrl+C: selection → copy, no selection → cancel task / SIGINT"，
   而 `copy_to_clipboard` 会把 Ctrl+C 的**中断功能彻底废掉** —— 终端里再也发不出 SIGINT。
   kitty 的 `copy_or_interrupt` 语义才与之完全一致。

2. **光标拖尾（`cursor.frag`）无法移植。**
   那个着色器用了 Ghostty 专有 uniform：`iPreviousCursor` / `iCurrentCursor` /
   `iCurrentCursorColor` / `iTimeCursorChange`，kitty 的着色器 API 没有这些，
   也取不到上一帧的光标位置。改用 kitty 原生 `cursor_trail` 实现相近观感：
   静止 500ms 后触发拖尾（对应原着色器 `duration_seconds = 0.52`），
   衰减速度沿用默认 `cursor_trail_decay 0.1 0.4`。

3. **`font_features` 按 PostScript 名精确匹配，不是家族名。**
   极易踩坑：kitty 源码 `fonts.c:450` 是 `strcmp(e->psname, psname) == 0`，
   **没有前缀匹配**。所以写 `JetBrainsMonoNerdFont`（家族名去空格）永远匹配不上，
   必须写 `JetBrainsMonoNF-Regular` / `-Bold` / `-Italic` 这类完整 PostScript 名。
   本仓库的配置因此**不写** `font_features` —— `calt` 反正默认开启，`liga` 又不存在。

#### 字体

已安装 **JetBrainsMono Nerd Font**（nerd-fonts v3.4.0），位于
`~/.local/share/fonts/JetBrainsMonoNF/`（16 个静态字重）。重新安装：

```bash
curl -L -o /tmp/jb.tar.xz \
  https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.tar.xz
mkdir -p ~/.local/share/fonts/JetBrainsMonoNF
tar -xJf /tmp/jb.tar.xz -C ~/.local/share/fonts/JetBrainsMonoNF \
    --wildcards 'JetBrainsMonoNerdFont-*.ttf'
fc-cache -f ~/.local/share/fonts
fc-match "JetBrainsMono Nerd Font"     # 应命中 JetBrainsMonoNerdFont-Regular.ttf
```

> **下载坑**：`JetBrainsMono.zip`（123 MB）在这条网络上反复中断。
> 同 release 的 **`JetBrainsMono.tar.xz` 只有 6 MB**（xz 压缩，内容相同），成功率高得多 —— 优先用它。
> 另注意 `curl -C -` 续传在本机是**假成功**：服务器忽略 Range，curl 从头重下并追加，
> 生成一个 100 MB+ 没有合法尾部的垃圾文件，`unzip -t` 报损坏但 curl 退出码是 0。宁可整个重下。

**中文会回退。** JetBrainsMono Nerd Font **不含 CJK 字形**，汉字/假名由 fontconfig
回退到 **Noto Sans CJK SC**（已装，显示正常，不会出方块），代价是同一行里中英文是两个
不同字体。若想风格统一，在 `kitty.conf` 里补一行即可（kitty 按顺序回退，
只对主字体缺的字形生效，不影响英文）：

```
font_family Maple Mono Normal NF CN
```

#### 配色随壁纸自动重生成

`morandi-gen.py` 生成 `~/.config/kitty/morandi.conf`，与 Noctalia 主题、starship
共用同一套 Morandi 调色板。换壁纸时由 `settings.toml` 的 `wallpaper_changed` 钩子
自动重跑，kitty 颜色随之更新（与 ghostty 的 `config-file = theme` 是同一机制）。
也可手动跑：`python3 ~/.config/noctalia/morandi-gen.py`。

#### fastfetch：打开终端自动显示系统信息

在 `~/.zshrc` 末尾（**不在仓库里** —— 这是本机用户配置，不是 dotfiles 的一部分）加了：

```zsh
if [[ -o interactive ]] && [[ -t 1 ]] && [[ -z $FASTFETCH_SHOWN ]] \
   && (( ${COLUMNS:-0} == 0 || COLUMNS >= 80 )); then
    export FASTFETCH_SHOWN=1
    fastfetch
fi
```

原 dotfiles 是在 `.zshrc` 里**裸写一个 `fastfetch`**（见 `dot_zshrc:12`），没有任何判断。
这在几种情况下会出问题，所以加了四重守卫：

| 守卫 | 挡掉的情况 |
|---|---|
| `-o interactive` | 脚本 / cron / git hook 等非交互场景 |
| `-t 1` | `zsh -i -c '命令' > 文件` —— 交互式但输出被重定向，会污染结果文件 |
| `-z $FASTFETCH_SHOWN` | 在终端里再敲一次 `zsh` 时重复刷屏（靠导出的环境变量传递） |
| `COLUMNS >= 80` | 窄分屏里 logo 会挤成一团 |

> **宽度判断刻意写成「失败安全」**：`${COLUMNS:-0} == 0` 时**照常显示**。
> zsh 在极少数情况下拿不到终端宽度（此时 `COLUMNS=0`），若直接写 `COLUMNS >= 80`
> 就会永久静默 —— 「突然不显示了」是最难排查的一类问题。
> 实测边界：`空/0 → 显示`、`40/79 → 跳过`、`80/120 → 显示`。

配置文件在 `~/.config/fastfetch/config.jsonc`（仓库内 `config/fastfetch/config.jsonc`，
由 `deploy_cachyos_config.sh` 首次落地），由 `morandi-gen.py` 的 `write_fastfetch`
在**每次换壁纸时全量重写**，配色永远跟着壁纸走。

该函数第一行是 `if not FASTFETCH_CONFIG.exists(): return` —— 这是**刻意的引导逻辑**，
文件不存在就完全不碰，不会替你创建。必须先有这份文件，脚本才会接管。

**logo 用 kitty 图形协议，不是原 dotfiles 的 chafa**：chafa 本机未装、装它要 sudo，
而 kitty 原生图形协议画质远好于字符画且零依赖。

**头像**：把任意 PNG 放到 `~/.config/fastfetch/avatar.png` 即生效。文件不存在时
fastfetch 会**静默回退到内置 logo**（已实测：不报错、不影响退出码），所以现在没头像也能正常用。

#### 半透明背景

原 ghostty 配置里**没有**透明度设置（`window-padding-color = background` 只是让内边距
区域取背景色，与透明度无关），所以严格照搬的话终端是不透明的。按需开启了半透明：

```ini
background_opacity 0.8
dynamic_background_opacity yes
```

**模糊不需要在 kitty 里设。** niri 的 `config.kdl` 已有一条覆盖全部窗口的规则：

```kdl
window-rule {
    match app-id=".*"
    exclude app-id="org.kde.krita"
    opacity 0.98
    background-effect { blur true }
}
```

所有窗口本来就带模糊，只是背景不透明时看不见 —— 把背景调透，模糊自然露出来。
（kitty 在 Wayland 下确实以 `app-id="kitty"` 出现并被 `".*"` 匹配到，已用 `niri msg -j windows` 实测确认。）

因此**不需要** `background_blur`；若哪天删掉 niri 那条规则，再打开配置里注释着的那行即可。

> **热改透明度**：`ctrl+shift+a` 是前缀键（man page 写作 `ctrl+shift+a>m`），要按两下：
> `m` 更不透明(+0.1)、`l` 更透明(-0.1)、`1` 恢复完全不透明、`d` 回到配置值 0.8。
> 这几个绑定只在 `dynamic_background_opacity yes` 时才生效。

**两条官方提醒**（man page 原文）：

- *"Be aware that using a value less than 1.0 is a (possibly significant) performance hit."*
  这台是 4 核 Broadwell + Intel HD 5500，透明与模糊都要走 GPU。觉得卡就把值调高或关掉。
- *"Changing this option when reloading the config will only work if
  `dynamic_background_opacity` was enabled in the original config."*
  —— **已经在运行的 kitty 窗口不会热更新透明度**（它启动时该选项还是关的），
  要**新开一个窗口**才能看到效果，`ctrl+shift+f5` 重载也不行。

### 7. 快捷键

**完全采用原 dotfiles 的按键方案**（与基础版不同，需要重新适应）。重点：

| 按键 | 功能 |
|---|---|
| `Mod+Return` | 终端 (kitty) |
| `Mod+CTRL+Return` | 应用启动器 |
| `Mod+A` | 控制中心 |
| `Mod+Shift+Q` | 会话菜单（锁屏/重启/关机） |
| `Mod+ALT+L` | 立即锁屏 |
| `Mod+V` | 剪贴板面板 |
| `Mod+Z` | 总览 (overview) |
| `Mod+B` / `Mod+E` | Firefox / Nautilus |
| `Mod+Shift+ESCAPE` | 快捷键总览 |

完整 101 条见 `config/niri-new/cfg/keybinds.kdl`。

>  三个容易"按了没反应"的点：
> - `Mod+B` / `Mod+E` 分别需要 `firefox` 与 `nautilus`，安装步骤里**没有装**
>   （`sudo apt install firefox-esr nautilus`）。
> - 音量 / 亮度 / 媒体键全部走 `noctalia msg ...`，**必须 Noctalia 在跑**；
>   基础版那套 `wpctl` / `playerctl` / `brightnessctl` 绑定在 CachyOS 版里不存在。
> - `Mod+Shift+Q` 的会话菜单 id 是 v5 的 `session`（v4 才叫 `sessionMenu`），
>   已按 v5 改好，别再改回去。

### 8. 验证清单

```bash
niri validate -c ~/.config/niri/config.kdl                # niri 配置语法
ldd "$(command -v niri)" | grep 'not found'               # 应无输出; 有输出就是缺库(见「2. 安装 Niri」)
pgrep -a fcitx5                                           # CachyOS 版没有 spawn 行, 确认它在跑
~/.local/bin/noctalia --version                           # 二进制就位
noctalia config validate ~/.config/noctalia/config.toml   # Noctalia 配置校验（权威）
noctalia config export                                    # 查看合并后的实际生效值
noctalia msg config-reload                                # 改完配置热重载，无需重新登录

# kitty 配置（用 kitty 自己的解析器，能抓出被静默忽略的坏行）
python3 -c "
import sys; sys.path.insert(0, '/usr/lib/kitty')
from kitty.config import load_config
bad = []; o = load_config('$HOME/.config/kitty/kitty.conf', accumulate_bad_lines=bad)
print('坏行:', len(bad) or '无'); print('字体:', o.font_family)"
fc-match "JetBrainsMono Nerd Font"                        # 应命中 JetBrainsMonoNerdFont-Regular.ttf
```

### 9. Windows 字体（Segoe UI + 微软雅黑 UI）

桌面 UI 字体从 `Noto Sans` 换成了 Win11 的 **Segoe UI**（拉丁）+ **微软雅黑 UI**（中文）。
终端 kitty **不受影响**，它只读自己的 `~/.config/kitty/kitty.conf`。

**字体来源**：Segoe UI / 微软雅黑是微软**专有字体**，Kali 源里没有，必须从 Windows 机器的
`C:\Windows\Fonts\` 自行拷出（**ISO 也不需要**，直接从任何一台 Win10/11 上拷即可）。
本仓库**不包含也不分发**这些字体文件。装到 `~/.local/share/fonts/Windows/`，无需 sudo。

实际用到的 16 个文件：

| 文件 | 家族 |
|---|---|
| `segoeui.ttf` `segoeuib.ttf` `segoeuii.ttf` `segoeuiz.ttf` | Segoe UI 常规/粗/斜/粗斜 |
| `segoeuil.ttf` `segoeuisl.ttf` `seguisb.ttf` `seguisbi.ttf` | Light / Semilight / Semibold / Semibold Italic |
| `msyh.ttc` `msyhbd.ttc` `msyhl.ttc` | Microsoft YaHei UI（简中） |
| `seguiemj.ttf` | Segoe UI Emoji |
| `consola.ttf` `consolab.ttf` `consolai.ttf` `consolaz.ttf` | Consolas |

关键：必须写逗号分隔的族名列表，不能只写 `"Segoe UI"`。**
Segoe UI **不含任何 CJK 字形**（`fc-list ':charset=中'` 里 0 条），只写它的话汉字会掉回
fontconfig 的默认中文（Noto Sans CJK SC），变成一行里中英两种字体。正确写法：

```toml
font_family = "Segoe UI, Microsoft YaHei UI"     # Noctalia
```
```ini
gtk-font-name=Segoe UI, Microsoft YaHei UI 10    # GTK
```

Pango ≥1.44 支持有序回退列表，逐字按「主字体有没有这个字形」自动选。实测
`pango_font_description_set_family()`（Noctalia 走的这条路，见 `cairo_text_renderer.cpp:411`）
与 `from_string()`（GTK 走的这条路）**两者都正确支持**：

| | 中文 | 英文 |
|---|---|---|
| 结果 | Microsoft YaHei UI | Segoe UI |

不要试图用 fontconfig 规则代替族名列表**，两条路实测都会出问题：

- `<test name="lang">` **会误伤英文** —— Pango 把整个 layout 的 lang 设成 locale（`zh-cn`），
  而不是按字符判断，于是连 `English` 那条 run 也命中，英文全变成雅黑那套难看的拉丁字形。
- `<test name="charset">` **不生效** —— Pango 传给 fontconfig 的查询里并不带 charset 属性
  （字形覆盖是 Pango 自己在排序后逐字筛的），测试 1 里中文仍回退到 Noto Sans CJK。

同理也**不要**把雅黑 prepend 到 `sans-serif` 链上，那会污染所有拉丁文本。

**字体设定在 4 处**，换字体时要一起改：

| 位置 | 键 |
|---|---|
| `~/.config/noctalia/config.toml` | `[shell] font_family` |
| `gsettings org.gnome.desktop.interface` | `font-name` 与 `document-font-name` |
| `~/.config/gtk-3.0/settings.ini` `~/.config/gtk-4.0/settings.ini` | `gtk-font-name` |
| `~/.gtkrc-2.0` | `gtk-font-name` |

**未改动**：`monospace-font-name`（GTK 应用的等宽字体，仍是 `Fira Code`）——它与 kitty 无关，
kitty 不读这个键。想换成 Win11 的 Consolas 就改它。

**字号**：沿用原来的 10pt。注意 Segoe UI 的 x-height 比 Noto Sans 小，同样 10pt 看起来会**略小**，
觉得小就调到 11。

## 故障排除

### Niri 无法启动

```bash
# 检查日志
journalctl -b -u niri

# 检查 Wayland 环境
echo $WAYLAND_DISPLAY

# 检查 Niri 配置语法
niri --help
```

### Niri 启动即退出：`error while loading shared libraries: xxx.so`

预编译 deb **不声明任何库依赖**（`Depends` 只有 `alacritty, fuzzel`），缺库时 apt 不报错，
niri 却在启动瞬间死掉。在 TTY 里直接敲 `niri` 就能看到缺哪个 `.so`：

```bash
ldd "$(command -v niri)" | grep 'not found'
```

最常见的是 `libseat.so.1` → `sudo apt install libseat1`；`libdisplay-info.so.3` →
`libdisplay-info3`（Debian 13 "trixie" 只有 `.so.2`，那份 deb 在 trixie 上无解，
需自行编译或换 trixie 版 deb）。完整对照表见「2. 安装 Niri」。

### 在 WSL / 无 3D 加速的虚拟机里启动黑屏或直接失败

niri 需要 DRM/GBM 设备与 seat：

```bash
ls /dev/dri          # WSLg 里通常没有这个目录 → 跑不了
```

这种环境只能用来看包、改配置，验证桌面请用真机，或开启 3D 加速的虚拟机
（VMware/VirtualBox 需装 Guest 的 3D 驱动并启用加速）。

### 换壁纸后配色只变了一半 / morandi-gen.py 中途报错

`morandi-gen.py` 的 `apply_system_changes()` 里有两条调用原本没做保护：

- `sudo magick <壁纸> ... /boot/efi/limine_bg.png`：没装 imagemagick、`/boot/efi`
  不存在、或 sudo 需要密码时都会抛异常，**中断整个脚本**，后面的配色不再写；
  而且它在 main() 里被调用了两次，等于每次换壁纸要弹两次 sudo 密码。
- `subprocess.Popen(["fcitx5"])`：没装 fcitx5 时抛 `FileNotFoundError`，同样中断。

现已修：`magick` / `/boot/efi` 缺失只是打印一行提示并跳过，`apply_system_changes()`
在 main() 里只调用一次，且每个 `write_*` 都被 `safe()` 包住 ——
单个目标软件失败只打印警告，不再影响其他软件。
彻底不需要 Limine 引导图的话，把文件顶部的 `ENABLE_LIMINE` 改成 `False`。

### 状态栏电源按钮点了没反应

`~/.config/waybar/config.jsonc` 的 `menu-file` 是**路径而不是命令**（waybar 用 GLib
直接读该文件，不经过 shell），所以必须是绝对路径。旧版部署命令里的
`sed 's|/home/zz|...|'` 无效（仓库里根本没有 `/home/zz`），占位符
`/home/YOUR_USERNAME` 会原样留下 → 菜单文件找不到。修：

```bash
grep -rn 'YOUR_USERNAME' ~/.config
grep -rl 'YOUR_USERNAME' ~/.config | xargs -r sed -i "s|/home/YOUR_USERNAME|$HOME|g"
```

### 音量键 / 亮度键 / 媒体键没反应

| 键位所属 | 依赖 | 检查 |
|---|---|---|
| 基础版 音量、麦克风静音 | `wpctl`（包 `pipewire` + `wireplumber`） | `command -v wpctl` |
| 基础版 媒体键 | `playerctl` | `command -v playerctl` |
| 基础版 亮度键 | `brightnessctl` | `command -v brightnessctl` |
| CachyOS 版 全部多媒体键 | `noctalia msg ...` | `pgrep -a noctalia` |

### `Mod+S` 屏幕 OCR 没反应

该键位执行 `zsh ~/Documents/_zshrc/ocr.sh`，需要 **zsh**（旧版安装步骤里没装）、
`grim slurp tesseract-ocr tesseract-ocr-chi-sim translate-shell wl-clipboard
libnotify-bin mousepad`，以及 `~/Documents/_zshrc/ocr.sh` 这个文件（第 6 步会复制）。

### 状态栏/控制面板不显示

```bash
# 重启状态栏
pkill waybar && waybar &

# 重启控制面板
pkill swaync && swaync &

# 手动测试控制面板开关
swaync-client -t -sw      # 开关面板
swaync-client -d -sw      # 清除全部通知
swaync-client -swb        # 查看状态 JSON (供 waybar 使用)

# 查看 swaync 日志
swaync -s 2>&1 | tail -30

# 确认二进制在 PATH
command -v swaync swaync-client

# 面板打不开的常见原因
# 1. 报 COULD NOT FIND CSS FILE → 见上, 需 XDG_CONFIG_DIRS 指向 ~/.local/etc/xdg
# 2. 报 Could not acquire notification name → 有残留通知守护进程 (KDE/mako/dunst), 先 pkill 掉
```

### swaync 打不开: `COULD NOT FIND CSS FILE`

> 用 `apt install sway-notification-center` 装的**不会有这个问题**（系统 CSS 在
> `/etc/xdg/swaync/`，本来就在搜索路径里）。这一节只针对**源码编译装到 `~/.local`** 的情况。

swaync 装在 `~/.local` 时,系统 CSS 不在其默认搜索路径 (`/etc/xdg`、`/usr/local/etc/xdg`) 里,启动即退出。

```bash
# 确认 CSS 在不在
ls -l ~/.local/etc/xdg/swaync/style.css

# 正确启动方式 (niri 配置里已用此方式)
XDG_CONFIG_DIRS="$HOME/.local/etc/xdg:/etc/xdg" swaync &
```

### 壁纸不显示

```bash
# 启动 swww daemon
swww-daemon &


```

### 电源状态不显示

```bash
# 检查 powerprofilesctl
powerprofilesctl list
powerprofilesctl get

# 检查电池路径
ls /sys/class/power_supply/

# 手动测试脚本
~/.config/waybar/power_status.sh
```

### 中文输入法不工作

```bash
# 启动 fcitx5
fcitx5 &

# 检查环境变量
echo $GTK_IM_MODULE
echo $QT_IM_MODULE

# 重启输入法
fcitx5 -r
```

### Waybar 不显示

```bash
# 检查配置
waybar --help

# 使用默认配置测试
waybar -c /dev/null -s /dev/null

# 检查日志
waybar > ~/.config/waybar/waybar.log 2>&1 &
```

### SDDM 登录后黑屏

```bash
# 检查 .xprofile 或 .profile 语法
bash ~/.profile

# 检查 niri 是否正常启动
niri
```

### 触控板不工作

```bash
# 检查 libinput
libinput list-devices

# 临时禁用触控板
xinput disable "SynPS/2 Synaptics TouchPad"
```

### Noctalia：dock / 状态栏突然消失，或改 config.toml 不生效

`noctalia msg bar-hide|bar-show|dock-hide|dock-show` **不是临时显隐**，它们会把
`enabled = false/true` **写进 `~/.local/state/noctalia/settings.toml` 持久化**，
该文件优先级高于 `config.toml`，于是之后改 `config.toml` 就被遮蔽了。

```bash
# 看 state 里有没有残留覆盖
grep -n -A3 '^\[dock\]\|^\[bar' ~/.local/state/noctalia/settings.toml

# 确认当前实际生效的值（不是 config.toml 里写的）
noctalia config export | grep -A6 '^\[dock\]'
```

清理办法：编辑 state 文件删掉对应表（`[dock]` 等），再 `noctalia msg config-reload`。

### 终端字体不对 / 中文出方块 / 连字没了

先确认字体本身到位：

```bash
fc-match "JetBrainsMono Nerd Font"                  # 应命中 JetBrainsMonoNerdFont-Regular.ttf
fc-list :charset=E0B0 family | grep -i jetbrains    # Nerd 图标字形是否存在
```

`fc-match` 若返回 `NotoSansCJK-*` 或 `DejaVuSans`，说明字体没装或缓存没刷新，
重跑 `fc-cache -f ~/.local/share/fonts`。

再确认 kitty 真的读到了配置 —— **别靠肉眼猜**，kitty 对不认识的选项是静默忽略：

```bash
python3 -c "
import sys; sys.path.insert(0, '/usr/lib/kitty')
from kitty.config import load_config
bad = []; o = load_config('$HOME/.config/kitty/kitty.conf', accumulate_bad_lines=bad)
print('坏行:', len(bad) or '无'); print('字体:', o.font_family); print('背景:', o.background)"
```

| 现象 | 原因与处理 |
|---|---|
| 中文显示成方块 | 没有可用的 CJK 回退字体。装 `fonts-noto-cjk`，或在 `kitty.conf` 加 `font_family Maple Mono Normal NF CN` |
| 图标显示成方块 | 装的是普通 JetBrains Mono 而非 Nerd Font 版（普通版没有图标字形）。用上面的 `fc-list :charset=E0B0` 查 |
| 连字（`->` `!=`）不出来 | 多半是 `font_features` 写错 —— 它按 **PostScript 名精确匹配**（`JetBrainsMonoNF-Regular`），写家族名会静默失效。`calt` 是 kitty 无条件开启的，正常情况下不写也有连字 |
| 改了配置没反应 | kitty **会自动重载**（`auto_reload_config`）；没生效按 `ctrl+shift+f5` 手动重载。极少数选项需整个重开窗口 |
| 配色没跟着壁纸变 | `~/.config/kitty/morandi.conf` 没重生成。手动跑 `python3 ~/.config/noctalia/morandi-gen.py` |

### 中文没跟着变成微软雅黑（桌面 / GTK 应用，非终端）

只写 `"Segoe UI"` 就会这样 —— 它**不含 CJK 字形**，汉字掉回 Noto Sans CJK。必须是
逗号列表 `"Segoe UI, Microsoft YaHei UI"`。详见上面「9. Windows 字体」一节。

先确认字体装上了：

```bash
fc-match "Segoe UI"              # 应 → segoeui.ttf
fc-match "Microsoft YaHei UI"    # 应 → msyh.ttc
```

再确认每一处都用了列表写法（共 4 处，见上表）；改完 `noctalia msg config-reload`，
GTK 应用要**重开**才生效。

想直接查「某个字体描述下每个字实际用了哪个字体」，用这段（比看截图可靠）：

```bash
python3 - <<'PY'
import gi
gi.require_version('Pango','1.0'); gi.require_version('PangoCairo','1.0')
from gi.repository import Pango, PangoCairo
import cairo
lay = PangoCairo.create_layout(cairo.Context(cairo.ImageSurface(cairo.FORMAT_ARGB32,10,10)))
lay.set_text("中文 English", -1)
lay.set_font_description(Pango.FontDescription.from_string("Segoe UI, Microsoft YaHei UI 12"))
lay.set_single_paragraph_mode(True)
it = lay.get_iter()
while True:
    r = it.get_run_readonly()
    if r: print(repr("中文 English".encode()[r.item.offset:r.item.offset+r.item.length].decode()),
                "→", r.item.analysis.font.describe().get_family())
    if not it.next_run(): break
PY
```

## 卸载

```bash
# 移除 Niri
sudo dpkg -r niri

# 移除 apt 装的组件 (按需)
sudo apt remove sway-notification-center satty
sudo rm -f /usr/local/bin/satty          # 手动装的 satty

# 移除 Noctalia (源码编译的, 装在 ~/.local)
rm -rf ~/.local/bin/noctalia ~/.local/share/noctalia ~/.cache/noctalia-src

# 恢复原配置
rm -rf ~/.config/niri ~/.config/waybar ~/.config/hypr ~/.config/kitty ~/.config/fuzzel ~/.config/fcitx5 ~/.config/satty ~/.config/swaync ~/.config/noctalia ~/.config/fastfetch
mv ~/.config/niri.bak ~/.config/niri
mv ~/.config/waybar.bak ~/.config/waybar
mv ~/.config/hypr.bak ~/.config/hypr
mv ~/.config/kitty.bak ~/.config/kitty
mv ~/.config/fuzzel.bak ~/.config/fuzzel
mv ~/.config/fcitx5.bak ~/.config/fcitx5
mv ~/.config/satty.bak ~/.config/satty
rm ~/Documents/_zshrc/ocr.sh

# 移除 SDDM 主题与主题配置片段
sudo rm -rf /usr/share/sddm/themes/user
sudo rm -rf /usr/share/backgrounds/user
sudo rm -f /etc/sddm.conf.d/20-niri-user-theme.conf

# 移除 /etc/environment 里的 fcitx 变量 (按需)
sudo sed -i '/^# fcitx5输入法$/,/^INPUT_METHOD=fcitx$/d' /etc/environment

# 如果之前为了这个桌面装过 pipewire / wireplumber / zsh 等, 自行决定是否卸载
```


## 参考链接

- [Niri 官方文档](https://yalter.github.io/niri/)
- [Waybar GitHub](https://github.com/Alexays/Waybar)
- [SDDM 主题](https://github.com/catppuccin/sddm)
- [Catppuccin 主题](https://github.com/catppuccin/catppuccin)
