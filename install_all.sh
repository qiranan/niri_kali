#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  niri_for_kali —— 一键安装脚本 (对 README「安装步骤」的可执行化 + 纠错版)
#
#  用法:
#      ./install_all.sh cachyos            # niri + Noctalia (config/niri-new + config/noctalia-new)
#      ./install_all.sh basic              # niri + waybar + swaync + swww + hyprlock + fuzzel
#      ./install_all.sh cachyos -y         # 全部自动确认 (apt / sddm 不再询问)
#      ./install_all.sh basic --no-sddm    # 不动登录管理器
#
#  相比 README 修掉的地方 (逐条对应):
#    1. `sudo apt install niri_x.deb` 少了 `./` —— apt 会当包名去找, 报 Unable to locate
#       package; 这里一律用 `apt-get install ./bin/xxx.deb`
#    2. README §1 的 apt 清单里有 `satty`, 但 Debian/Kali 仓库都没有这个包 ——
#       整条 apt 命令会失败。这里把包分「必需 / 可选」, 可选包逐个装, 坏一个不影响其他
#    3. README §5 说 Kali 没有 swaync 要自己编译 —— 已过时: kali-rolling 现在有
#       `sway-notification-center 0.12.6-1` (正是 README 要编的版本)。默认走 apt,
#       并用软链把 /usr/bin/swaync* 接到 ~/.local/bin, 这样现有配置一行都不用改
#    4. README §6 的 `sed 's|/home/zz|...'` 是死代码 (仓库里已无 /home/zz, 占位符叫
#       /home/YOUR_USERNAME) —— 结果 waybar 电源菜单指向不存在的家目录
#    5. README §7 的 sddm 主题: 仓库里的 backgrounds/wall.png 是绝对路径软链, 从 Windows
#       拷过来会丢 → 主题没有背景, 而且 finish_sudo_setup.sh 第 5 步会因父目录不存在直接失败
#    6. `sudo echo ... >> /etc/environment` 必然 Permission denied (重定向由当前用户执行)
#       → 改用 `sudo tee -a`
#    7. `echo "[Theme]..." | sudo tee /etc/sddm.conf` 会覆盖已有配置 → 写 conf.d 片段
#    8. bin/ 与 wallpapers/ 被 .gitignore 排除, 从 GitHub 克隆拿不到 → 本脚本逐项检查,
#       缺了就明确告诉你怎么补, 不会静默跳过
#    9. 从 Windows 拷来的文件可能带 CRLF → 脚本先统一成 LF (否则 bash 报 $'\r' 之类怪错)
#
#  ⚠️ 本脚本按仓库内容 + 2026-09 的 Kali/Debian 包状态编写, 但**未在全新 Kali 上端到端实测**。
#     每一步都会打印在做什么; 失败会停在该步并给出原因, 不会继续往下滚。
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

MODE=""
ASSUME_YES=0
DO_SDDM=1
for a in "$@"; do
    case "$a" in
        basic|cachyos) MODE="$a" ;;
        -y|--yes)      ASSUME_YES=1 ;;
        --no-sddm)     DO_SDDM=0 ;;
        -h|--help)     sed -n '2,30p' "$0"; exit 0 ;;
        *) echo "未知参数: $a (可用: basic | cachyos | -y | --no-sddm)"; exit 2 ;;
    esac
done
if [[ -z "$MODE" ]]; then
    echo "用法: ./install_all.sh basic|cachyos [-y] [--no-sddm]"
    exit 2
fi

CFG="$HOME/.config"
STAMP="$(date +%F-%H%M%S)"
OK=(); WARN=(); FAIL=()

say()  { printf '\n\033[1;36m═══ %s ═══\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; OK+=("$*"); }
warn() { printf '  \033[33m⚠\033[0m %s\n' "$*"; WARN+=("$*"); }
die()  { printf '  \033[31m✗ %s\033[0m\n' "$*"; FAIL+=("$*"); }

confirm() {
    [[ $ASSUME_YES -eq 1 ]] && return 0
    local r
    read -r -p "  → $1 [Y/n] " r
    [[ -z "$r" || "$r" =~ ^[Yy] ]]
}

SUDO=""
if [[ $EUID -ne 0 ]]; then
    if sudo -n true 2>/dev/null; then SUDO="sudo -n"
    elif confirm "需要 sudo 密码来装系统包/写 /usr, 继续吗?"; then SUDO="sudo"
    else echo "已取消"; exit 1
    fi
fi

# 装包: 必需包一次装; 可选包逐个装, 失败只警告 (README §1 就是因为清单里混进了
# 不存在的 satty, 让整条命令全灭)
apt_required() {
    say "apt 必需依赖"
    $SUDO apt-get update -qq
    if $SUDO apt-get install -y --no-install-recommends "$@"; then
        ok "必需依赖已装"
    else
        die "必需依赖安装失败"
        return 1
    fi
}
apt_optional() {
    local p
    say "apt 可选依赖 (缺一个不影响整体)"
    for p in "$@"; do
        if dpkg -s "$p" >/dev/null 2>&1; then ok "$p 已装"; continue; fi
        if $SUDO apt-get install -y --no-install-recommends "$p" >/dev/null 2>&1; then
            ok "$p"
        else
            warn "$p 装不上 (仓库里可能没这个包名, 或版本换代改名) —— 功能会少一块"
        fi
    done
}

# ── 0. 环境自检 + CRLF 清理 ───────────────────────────────────────────────────
say "0/11 环境检查"
[[ "$(uname -m)" == "x86_64" ]] || warn "仓库里的 niri deb / swww 是 amd64 的, 当前架构 $(uname -m)"
command -v apt-get >/dev/null || { echo "这不是 Debian/Kali 系发行版, 脚本退出"; exit 1; }
ok "架构 $(uname -m), 发行版 $(. /etc/os-release; echo "$PRETTY_NAME")"

# 先确认本次模式所需的核心程序可获得。干净的 GitHub 克隆不包含 bin/ 中的
# 预编译文件；如果此时才装完一堆 apt 包再失败，用户会得到半完成的系统。
if ! command -v niri >/dev/null 2>&1 \
   && ! compgen -G "bin/niri_*_amd64.deb" >/dev/null 2>&1 \
   && ! apt-cache policy niri 2>/dev/null | grep -q 'Candidate: [0-9]'; then
    echo "✗ 找不到 niri: PATH 中没有 niri, bin/ 中没有 deb, Kali apt 也没有 Candidate。"
    echo "  请先按 README 的 Niri 源码编译步骤安装 niri, 或把匹配的 deb 放入 bin/。"
    exit 1
fi
if [[ "$MODE" == "basic" ]] \
   && ! command -v swww-daemon >/dev/null 2>&1 \
   && [[ ! -x bin/swww || ! -x bin/swww-daemon ]]; then
    echo "✗ basic 模式需要 swww-daemon, 但 PATH 和 bin/ 都没有。"
    echo "  请先按 README 的 Swww 编译步骤安装, 或把 swww 与 swww-daemon 放入 bin/。"
    exit 1
fi

# 从 Windows 拷来的文件常带 CRLF, 会让 .sh 报 "$'\r': command not found"
while IFS= read -r -d '' f; do
    grep -qU $'\r' "$f" 2>/dev/null && sed -i 's/\r$//' "$f" || true
done < <(find . -type f \( -name '*.sh' -o -name '*.kdl' -o -name '*.toml' -o -name '*.py' -o -name '*.conf' -o -name '*.json' -o -name '*.jsonc' -o -name '*.css' -o -name '*.ini' \) -not -path './.git/*' -print0)
ok "已统一换行符 (Windows 拷贝常见坑)"

# ── 1. 必需依赖 ──────────────────────────────────────────────────────────────
apt_required \
    hyprlock waybar fcitx5 fcitx5-chinese-addons pavucontrol kitty fuzzel \
    procps btop mate-polkit power-profiles-daemon network-manager \
    fonts-font-awesome xdg-user-dirs xdg-utils \
    grim slurp wl-clipboard \
    tesseract-ocr tesseract-ocr-chi-sim tesseract-ocr-eng \
    translate-shell libseat1

# README §1 里没有、但配置/键位真的会用到的
apt_optional \
    playerctl brightnessctl libnotify-bin mousepad zsh unzip wget curl \
    fonts-jetbrains-mono imagemagick pipewire wireplumber \
    libpipewire-0.3-0t64 libdisplay-info3 libgtk4-layer-shell0 \
    xdg-desktop-portal-gtk xdg-desktop-portal-wlr \
    fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-frontend-qt6 \
    gnome-keyring upower firefox-esr nautilus

# satty: Debian/Kali 都没有这个包 (README §1 写 apt install satty 会整条失败)
if ! command -v satty >/dev/null 2>&1; then
    warn "satty 不在 Debian/Kali 仓库 (README §1 的 satty 会让整条 apt 命令失败)"
    if confirm "现在从上游下载 satty 预编译二进制到 /usr/local/bin 吗?"; then
        tmp="$(mktemp -d)"
        if curl -fL --retry 3 -o "$tmp/satty.tar.gz" \
            "https://github.com/Satty-org/Satty/releases/download/v0.20.1/satty-x86_64-unknown-linux-gnu.tar.gz"; then
            tar -xzf "$tmp/satty.tar.gz" -C "$tmp"
            if [[ -f "$tmp/satty" ]]; then
                $SUDO install -m 755 "$tmp/satty" /usr/local/bin/satty && ok "satty 已装到 /usr/local/bin"
            else
                warn "压缩包里没找到 satty 可执行文件, 请手动查看 $tmp"
            fi
        else
            warn "下载失败 —— 截图标注 (Mod+Shift+S) 会不可用; 也可用 flatpak 版"
        fi
    else
        warn "跳过 satty: Mod+Shift+S 截图标注会失败 (grim 截图本身没问题)"
    fi
else
    ok "satty 已存在"
fi

# ── 2. Niri ─────────────────────────────────────────────────────────────────
say "2/11 安装 niri"
if command -v niri >/dev/null 2>&1; then
    ok "niri 已在: $(command -v niri)"
else
    deb="$(ls bin/niri_*_amd64.deb 2>/dev/null | head -n1 || true)"
    if [[ -n "$deb" ]]; then
        # ⚠️ 必须带 ./ 前缀, 否则 apt 会把它当包名
        $SUDO apt-get install -y "./$deb" && ok "已安装 $deb"
    elif apt-cache policy niri 2>/dev/null | grep -q 'Candidate: [0-9]'; then
        $SUDO apt-get install -y niri && ok "已从发行版仓库安装 niri"
    else
        die "装不了 niri: bin/ 里没有 deb, 仓库里也没有 niri 包 (Debian/Kali 至今没有 niri 二进制包)"
        cat <<'EOF'
    两条路:
      A) 把作者那份 bin/niri_26.4.0-1_amd64.deb 放进 bin/ 再重跑本脚本;
      B) 自己编译 (官方文档只认这条路, 从不提 cargo deb):
           sudo apt-get install -y gcc clang libudev-dev libgbm-dev libxkbcommon-dev \
             libegl1-mesa-dev libwayland-dev libinput-dev libdbus-1-dev libsystemd-dev \
             libseat-dev libpipewire-0.3-dev libpango1.0-dev libdisplay-info-dev
           curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh   # 用 rustup, 别用发行版 cargo
           git clone https://github.com/niri-wm/niri.git && cd niri
           cargo build --release
           # 官方推荐的落盘位置 (niri.service 默认找 /usr/bin/niri):
           sudo install -m755 target/release/niri /usr/local/bin/niri
           sudo install -m755 resources/niri-session /usr/local/bin/niri-session
           sudo install -Dm644 resources/niri.desktop /usr/local/share/wayland-sessions/niri.desktop
           sudo install -Dm644 resources/niri-portals.conf /usr/local/share/xdg-desktop-portal/niri-portals.conf
           sudo install -Dm644 resources/niri.service resources/niri-shutdown.target /etc/systemd/user/
EOF
    fi
fi

if command -v niri >/dev/null 2>&1; then
    # 作者那份 deb 的 Depends 只有 alacritty, fuzzel —— 没有任何库依赖声明,
    # 缺库时 apt 不报错, 而是启动即崩。所以这里自己查一次。
    missing="$(ldd "$(command -v niri)" 2>/dev/null | awk '/not found/{print $1}' | sort -u || true)"
    if [[ -n "$missing" ]]; then
        die "niri 缺运行库: $(echo "$missing" | tr '\n' ' ')"
        cat <<'EOF'
    已知对应关系 (Debian 13 trixie 与当前 kali-rolling 名称不同):
      libdisplay-info.so.3 → libdisplay-info3   (trixie 只有 .so.2 = libdisplay-info2,
                              kali-rolling 已升到 0.3, 所以 rolling 上一般没问题)
      libpipewire-0.3.so.0 → libpipewire-0.3-0t64
      libseat.so.1         → libseat1        libinput.so.10   → libinput10
      libgbm.so.1          → libgbm1         libxkbcommon.so.0 → libxkbcommon0
      libpixman-1.so.0     → libpixman-1-0   libcairo.so.2    → libcairo2
      libpango-1.0.so.0    → libpango-1.0-0  libpangocairo-1.0.so.0 → libpangocairo-1.0-0
    不确定包名时: sudo apt-get install -y apt-file && sudo apt-file update && apt-file search <那个.so>
EOF
    else
        ok "niri 运行库齐全, 版本: $(niri --version 2>/dev/null || echo '?')"
    fi
    [[ -f /usr/share/wayland-sessions/niri.desktop ]] \
        && ok "登录会话文件 /usr/share/wayland-sessions/niri.desktop 就位" \
        || warn "缺 /usr/share/wayland-sessions/niri.desktop —— SDDM 里看不到 Niri 会话"
fi

# ── 3. swaync (通知中心/控制面板) ────────────────────────────────────────────
say "3/11 swaync"
if command -v swaync >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/swaync" ]]; then
    ok "swaync 已存在"
elif apt-cache policy sway-notification-center 2>/dev/null | grep -q 'Candidate: [0-9]'; then
    # kali-rolling 有 0.12.6-1, trixie 有 0.11.0-1 —— 不用编译
    $SUDO apt-get install -y sway-notification-center
    mkdir -p "$HOME/.local/bin"
    # 配置里写死了 ~/.local/bin/swaync*, 软链一下就完全兼容, 不必改任何配置文件
    ln -sf /usr/bin/swaync        "$HOME/.local/bin/swaync"
    ln -sf /usr/bin/swaync-client "$HOME/.local/bin/swaync-client"
    ok "已用发行版包安装 (版本 $(dpkg-query -W -f='${Version}' sway-notification-center)), 并软链到 ~/.local/bin"
else
    warn "仓库里没有 sway-notification-center, 走源码编译 (README §5 的流程)"
    $SUDO apt-get install -y meson ninja-build valac libgtk-4-dev libadwaita-1-dev \
        libjson-glib-dev libgee-0.8-dev libgranite-7-dev libnotify-dev libpulse-dev \
        libsoup-3.0-dev libgtk4-layer-shell-dev blueprint-compiler sassc scdoc
    tmp="$(mktemp -d)"
    curl -fL --retry 3 -o "$tmp/swaync.tar.gz" \
        "https://github.com/ErikReider/SwayNotificationCenter/archive/refs/tags/v0.12.6.tar.gz" \
        || curl -fL --retry 3 -o "$tmp/swaync.tar.gz" \
        "https://gh-proxy.com/https://github.com/ErikReider/SwayNotificationCenter/archive/refs/tags/v0.12.6.tar.gz"
    tar -xzf "$tmp/swaync.tar.gz" -C "$tmp"
    ( cd "$tmp"/SwayNotificationCenter-0.12.6 \
      && meson setup build --prefix="$HOME/.local" \
      && ninja -C build && ninja -C build install )
    # 装在 ~/.local 时系统 CSS 在 ~/.local/etc/xdg/swaync/style.css, 而 swaync 默认
    # 只在 /etc/xdg、/usr/local/etc/xdg 里找 → niri 配置里已经用 XDG_CONFIG_DIRS 指过去了
    ok "swaync 已编译安装到 ~/.local"
fi

# ── 4. swww (只有基础版需要; CachyOS 版壁纸由 Noctalia 接管) ─────────────────
if [[ "$MODE" == "basic" ]]; then
    say "4/11 swww 壁纸程序"
    if command -v swww-daemon >/dev/null 2>&1; then
        ok "swww 已存在"
    elif [[ -x bin/swww && -x bin/swww-daemon ]]; then
        $SUDO install -m 755 bin/swww bin/swww-daemon /usr/local/bin/
        ok "已用仓库自带二进制安装 (只需 liblz4-1, 一般系统自带)"
    else
        warn "bin/ 里没有 swww 二进制 —— 上游没有 Debian 包, 只能编译"
        cat <<'EOF'
    编译要点 (README §4 方法 B 的依赖清单不全, 且漏了 MSRV):
      · 上游 MSRV = Rust 1.87; Debian 13 trixie 的 rustc 只有 1.85 → 发行版 cargo 编不过,
        必须用 rustup 装新版; 依赖: libwayland-dev wayland-protocols liblz4-dev scdoc
      · 上游已改名 awww 并搬到 Codeberg, 老仓库 LGFae/swww 仍可克隆
      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
      cargo install --git https://github.com/LGFae/swww swww  # 或 git clone 后 cargo build --release
EOF
    fi
else
    say "4/11 swww —— CachyOS 版不需要 (壁纸交给 Noctalia), 跳过"
fi

# ── 5. Noctalia v5 (必须源码编译; 官方 APT 包在 Kali 上依赖不满足) ───────────
if [[ "$MODE" == "cachyos" ]]; then
    say "5/11 编译安装 Noctalia v5 (耗时较长)"
    if [[ -x "$HOME/.local/bin/noctalia" ]]; then
        ok "Noctalia 已存在: $("$HOME/.local/bin/noctalia" --version 2>/dev/null || echo '?')"
    else
        # 用英文目录, 避免 README 里 ~/下载 这种中文目录假设
        export NOCTALIA_SRC="$HOME/.cache/noctalia-src"
        export PREFIX="$HOME/.local"
        out=""
        if out="$(bash install_noctalia.sh 2>&1)"; then
            echo "$out" | tail -n 20
            [[ -x "$HOME/.local/bin/noctalia" ]] && ok "Noctalia 已装到 ~/.local/bin/noctalia (assets 也在 ~/.local/share/noctalia)" \
                || die "Noctalia 脚本返回成功, 但没有找到 ~/.local/bin/noctalia"
        elif grep -q '缺少' <<<"$out"; then
            pkgs="$(grep -o 'apt install -y .*' <<<"$out" | head -n1 | sed 's/apt install -y //')"
            if [[ -z "$pkgs" ]]; then
                echo "$out" | tail -n 20
                die "Noctalia 依赖检查失败, 但未能解析依赖包清单"
                pkgs=""
            fi
            if [[ -n "$pkgs" ]]; then
                say "补装 Noctalia 构建依赖"
                echo "  $pkgs"
                # shellcheck disable=SC2086
                $SUDO apt-get install -y $pkgs
                if bash install_noctalia.sh; then
                    [[ -x "$HOME/.local/bin/noctalia" ]] \
                        && ok "Noctalia 已装到 ~/.local/bin/noctalia (assets 也在 ~/.local/share/noctalia)" \
                        || die "Noctalia 构建返回成功, 但没有找到 ~/.local/bin/noctalia"
                else
                    die "Noctalia 构建失败"
                fi
            fi
        else
            echo "$out" | tail -n 20
            die "Noctalia 构建失败 —— 上面是 install_noctalia.sh 的输出"
        fi
    fi
else
    say "5/11 Noctalia —— 基础版不用, 跳过"
fi

# ── 6. 字体 ─────────────────────────────────────────────────────────────────
say "6/11 字体"
mkdir -p "$HOME/.local/share/fonts/MapleMono"
if fc-list 2>/dev/null | grep -qi 'Maple Mono Normal NF CN'; then
    ok "Maple Mono Normal NF CN 已在"
elif [[ -f bin/MapleMonoNormal-NF-CN.zip ]]; then
    unzip -oq bin/MapleMonoNormal-NF-CN.zip -d "$HOME/.local/share/fonts/MapleMono/" && ok "从 bin/ 解压了 Maple Mono (16 个字重)"
else
    warn "bin/ 里没有字体包 (153M, 超过 GitHub 单文件限制, 被 .gitignore 排除)"
    if confirm "现在从上游下载 Maple Mono NF CN (~50MB) 吗?"; then
        curl -fL --retry 3 -o /tmp/MapleMono.zip \
            "https://github.com/subframe7536/maple-font/releases/download/v7.9/MapleMonoNormal-NF-CN.zip" \
            && unzip -oq /tmp/MapleMono.zip -d "$HOME/.local/share/fonts/MapleMono/" && ok "已下载并解压"
    fi
fi
fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || true
fc-match "Maple Mono Normal NF CN" | grep -qi maple && ok "fontconfig 能命中 Maple Mono" || warn "fc-match 没命中 Maple Mono (中文/连字可能回退)"

if [[ "$MODE" == "cachyos" ]]; then
    # Noctalia 桌面 UI 字体是 Win11 的 Segoe UI + 微软雅黑 UI
    if fc-match "Segoe UI" 2>/dev/null | grep -qi segoe; then
        ok "Segoe UI 已装"
    else
        warn "缺 Segoe UI / 微软雅黑 UI —— 这两套是微软专有字体, Kali 仓库没有, 也无法替你下载"
        cat <<'EOF'
    自己去任意一台 Windows 的 C:\Windows\Fonts\ 拷这 16 个文件到
    ~/.local/share/fonts/Windows/ (无需 sudo), 然后 fc-cache -f:
      segoeui.ttf segoeuib.ttf segoeuii.ttf segoeuiz.ttf
      segoeuil.ttf segoeuisl.ttf seguisb.ttf seguisbi.ttf
      msyh.ttc msyhbd.ttc msyhl.ttc seguiemj.ttf
      consola.ttf consolab.ttf consolai.ttf consolaz.ttf
    不装也能用, 只是界面字体回退成 Noto Sans (中文会变 Noto Sans CJK)。
EOF
    fi
fi

# ── 7. 壁纸 (桌面 / 锁屏 / SDDM 三处共用一张) ────────────────────────────────
say "7/11 壁纸"
wall=""
[[ -f wallpapers/__Main__.png ]] && wall="wallpapers/__Main__.png"
if [[ -z "$wall" ]]; then
    wall="$(find wallpapers -maxdepth 2 -type f -iname '*.png' 2>/dev/null | head -n1 || true)"
fi
if [[ -n "$wall" ]]; then
    $SUDO install -d /usr/share/backgrounds/user
    $SUDO install -m 644 "$wall" /usr/share/backgrounds/user/__Main__.png
    ok "壁纸已就位: /usr/share/backgrounds/user/__Main__.png (来自 $wall)"
else
    warn "仓库里没有壁纸 (wallpapers/ 被 .gitignore 排除)"
    echo "     桌面/锁屏/SDDM 都指向 /usr/share/backgrounds/user/__Main__.png, 缺图就是纯色背景。"
    echo "     自己放一张: sudo install -d /usr/share/backgrounds/user && sudo install -m644 你的图.png /usr/share/backgrounds/user/__Main__.png"
fi
# CachyOS 版的 Noctalia 默认壁纸目录/默认图写的是 $HOME/Pictures/wallpapers
mkdir -p "$HOME/Pictures/wallpapers" "$HOME/Pictures/Screenshots"
if [[ ! -f "$HOME/Pictures/wallpapers/__Main__.png" && -f /usr/share/backgrounds/user/__Main__.png ]]; then
    cp /usr/share/backgrounds/user/__Main__.png "$HOME/Pictures/wallpapers/" && ok "已把壁纸复制到 ~/Pictures/wallpapers (Noctalia 默认目录)"
fi

# ── 8. 部署配置 ─────────────────────────────────────────────────────────────
say "8/11 部署配置到 ~/.config"
backup() {
    local d="$1"
    [[ -e "$CFG/$d" ]] && { mv "$CFG/$d" "$CFG/$d.bak-$STAMP"; echo "  备份 ~/.config/$d → $d.bak-$STAMP"; }
    return 0
}
if [[ "$MODE" == "cachyos" ]]; then
    bash deploy_cachyos_config.sh
else
    for d in niri waybar hypr kitty fuzzel fcitx5 satty swaync fastfetch; do backup "$d"; done
    mkdir -p "$CFG"/{niri,waybar,hypr,kitty,fuzzel,fcitx5,satty,swaync,fastfetch} "$HOME/Documents/_zshrc"
    cp -r config/niri/*      "$CFG/niri/"
    cp -r config/waybar/*    "$CFG/waybar/"
    cp -r config/hypr/*      "$CFG/hypr/"
    cp -r config/kitty/*     "$CFG/kitty/"
    cp -r config/fuzzel/*    "$CFG/fuzzel/"
    cp -r config/fcitx5/*    "$CFG/fcitx5/"
    cp -r config/satty/*     "$CFG/satty/"
    cp -r config/swaync/*    "$CFG/swaync/"
    cp -r config/fastfetch/* "$CFG/fastfetch/"
    # ⚠️ README §6 写的是 sed 's|/home/zz|...' —— 仓库里根本没有 /home/zz,
    #    占位符叫 /home/YOUR_USERNAME, 结果 waybar 电源菜单指向不存在的家目录
    grep -rl 'YOUR_USERNAME' "$CFG/waybar" "$CFG/niri" "$CFG/fastfetch" 2>/dev/null \
        | xargs -r sed -i "s|/home/YOUR_USERNAME|$HOME|g"
    chmod +x "$CFG/waybar/power_status.sh" 2>/dev/null || true
    ok "基础版配置已部署 (占位符已替换成 $HOME)"
fi
# 占位符替换 (CachyOS 版的 deploy 脚本会做 niri/noctalia/fastfetch; 这里兜底 + 覆盖 waybar)
grep -rl 'YOUR_USERNAME' "$CFG" 2>/dev/null | xargs -r sed -i "s|/home/YOUR_USERNAME|$HOME|g" || true
# OCR 脚本 (niri 里 Mod+S 用 `zsh ~/Documents/_zshrc/ocr.sh`)
if [[ -f scripts/ocr.sh ]]; then
    install -m 755 scripts/ocr.sh "$HOME/Documents/_zshrc/ocr.sh" && ok "OCR 脚本 → ~/Documents/_zshrc/ocr.sh (依赖 zsh + tesseract + trans + mousepad)"
fi
if ! command -v zsh >/dev/null 2>&1; then
    warn "没有 zsh —— Mod+S 的 OCR 绑定用的是 `zsh ocr.sh`, 不装 zsh 这个键没反应"
fi
if command -v niri >/dev/null 2>&1; then
    niri validate -c "$CFG/niri/config.kdl" >/dev/null 2>&1 && ok "niri 配置语法通过" \
        || { niri validate -c "$CFG/niri/config.kdl" || die "niri 配置有语法错误 (见上)"; }
fi

# ── 9. SDDM 登录主题 ────────────────────────────────────────────────────────
if [[ "$DO_SDDM" -eq 1 ]]; then
    say "9/11 SDDM 登录主题"
    $SUDO apt-get install -y --no-install-recommends sddm
    $SUDO cp -r sddm/user /usr/share/sddm/themes/
    # 仓库里 sddm/user/backgrounds/wall.png 是指向 /usr/share/backgrounds/user/__Main__.png
    # 的绝对软链, 从 Windows 拷过来会丢 → 目录都不存在, finish_sudo_setup.sh 会在这里失败
    $SUDO mkdir -p /usr/share/sddm/themes/user/backgrounds
    $SUDO ln -sf /usr/share/backgrounds/user/__Main__.png /usr/share/sddm/themes/user/backgrounds/wall.png
    ok "主题已装, 背景软链已修好 ($(readlink /usr/share/sddm/themes/user/backgrounds/wall.png))"
    # SDDM 以 sddm 用户运行, 看不到 ~/.local/share/fonts —— 想让登录页用 Maple 得装到系统目录
    if [[ -d "$HOME/.local/share/fonts/MapleMono" ]] && ! fc-list 2>/dev/null | grep -qi 'maple'; then :; fi
    $SUDO mkdir -p /usr/local/share/fonts
    if [[ -d "$HOME/.local/share/fonts/MapleMono" && ! -d /usr/local/share/fonts/MapleMono ]]; then
        $SUDO cp -r "$HOME/.local/share/fonts/MapleMono" /usr/local/share/fonts/ && $SUDO fc-cache -f >/dev/null 2>&1 || true
        ok "Maple 字体也放到了 /usr/local/share/fonts (SDDM 登录页才能用上)"
    fi
    # 写 conf.d 片段而不是覆盖 /etc/sddm.conf (README §7 的写法会清掉已有配置)
    $SUDO mkdir -p /etc/sddm.conf.d
    printf '[Theme]\nCurrent=user\n' | $SUDO tee /etc/sddm.conf.d/20-niri-user-theme.conf >/dev/null
    ok "已写 /etc/sddm.conf.d/20-niri-user-theme.conf (没有覆盖 /etc/sddm.conf)"
    # Kali 默认桌面是 XFCE, 常自带 lightdm; 两个 DM 同时 enable 会抢 VT
    for dm in lightdm gdm3 gdm; do
        if systemctl is-enabled "$dm" >/dev/null 2>&1; then
            warn "$dm 也是 enabled —— 建议 sudo systemctl disable $dm, 只留 sddm"
        fi
    done
    $SUDO systemctl enable sddm >/dev/null 2>&1 && ok "sddm 已 enable"
    $SUDO systemctl set-default graphical.target >/dev/null 2>&1 || true
else
    say "9/11 SDDM —— 按参数跳过"
fi

# ── 10. 输入法环境变量 ──────────────────────────────────────────────────────
say "10/11 中文输入法环境变量"
if grep -q '^GTK_IM_MODULE=fcitx' /etc/environment 2>/dev/null; then
    ok "/etc/environment 里已有 fcitx 变量"
else
    # ⚠️ README §8 的 `sudo echo "..." >> /etc/environment` 一定失败:
    #    重定向 >> 是当前 shell(普通用户)做的, sudo 只管 echo
    printf '# fcitx5 输入法\nGTK_IM_MODULE=fcitx\nQT_IM_MODULE=fcitx\nXMODIFIERS=@im=fcitx\nSDL_IM_MODULE=fcitx\nINPUT_METHOD=fcitx\n' \
        | $SUDO tee -a /etc/environment >/dev/null
    ok "已用 sudo tee -a 追加到 /etc/environment"
fi

# ── 11. 自检 & 收尾 ─────────────────────────────────────────────────────────
say "11/11 自检"
for c in niri niri-session kitty fuzzel hyprlock fcitx5; do
    command -v "$c" >/dev/null 2>&1 && ok "$c" || warn "缺可执行文件: $c"
done
[[ "$MODE" == "basic" ]]   && { command -v waybar >/dev/null && ok "waybar" || warn "缺 waybar"
                                command -v swww-daemon >/dev/null && ok "swww-daemon" || warn "缺 swww-daemon"; }
[[ "$MODE" == "cachyos" ]] && { [[ -x "$HOME/.local/bin/noctalia" ]] && ok "noctalia" || warn "缺 ~/.local/bin/noctalia"; }
command -v satty >/dev/null && ok "satty" || warn "缺 satty —— Mod+Shift+S 标注不可用"
command -v swaync >/dev/null || [[ -x "$HOME/.local/bin/swaync" ]] && ok "swaync" || warn "缺 swaync"

cat <<EOF

═══════════════════════════════════════════════════════════════════════════════
  完成 ($MODE 版)。成功 ${#OK[@]} 项, 警告 ${#WARN[@]} 项。

  下一步:
    1. 重新登录 / 重启, 在登录界面右上角选 "Niri" 会话
       (没装 SDDM 的话: 在 TTY 直接敲 niri-session)
    2. 登录后自检:
         niri msg outputs                 # 确认显示器名, 与 config/niri-new/cfg/display.kdl 对不上就改
         pgrep -a fcitx5                  # CachyOS 版没有 spawn fcitx5 行, 靠 xdg-autostart
         niri msg -j windows | head -c 300
    3. Morandi 配色 (只有 CachyOS 版): 换壁纸后自动跑; 手动跑
         python3 ~/.config/noctalia/morandi-gen.py
       ⚠️ 它的 apply_system_changes() 里有一句没加保护的 `sudo magick ... /boot/efi/limine_bg.png`,
          没装 imagemagick 或 sudo 要密码时会抛异常, 直接中断整个脚本 (后半段配色不会写)。
          用不到 Limine 引导图的话, 建议把那两行注释掉。
    4. 两套方案互斥: 用了 CachyOS 版就别再启动 waybar / swaync / swww, 会和 Noctalia 抢通知守护和图层。
EOF

if (( ${#FAIL[@]} > 0 )); then
    printf '\n失败项:\n'; printf '  ✗ %s\n' "${FAIL[@]}"
    exit 1
fi
