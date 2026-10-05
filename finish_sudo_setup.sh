#!/bin/bash
# niri_for_kali 收尾脚本 —— 所有需要 root 权限的操作
# 用法: sudo bash finish_sudo_setup.sh
#
# ⚠️ 旧版有两个会让脚本"跑一半就退出"的问题 (set -e 下直接中断, 后面的步骤全都不执行):
#    · 第 3 步写死了 `install -m 755 /tmp/satty /usr/bin/satty`:
#      satty **不在 Debian/Kali 仓库里**, /tmp/satty 通常根本不存在 → install 报错退出
#    · 第 5 步 `ln -sf /usr/share/backgrounds/user/__Main__.png .../backgrounds/wall.png`:
#      仓库里的 sddm/user/backgrounds/wall.png 是**绝对路径软链**, 从 Windows 用 U 盘/压缩包
#      拷过来时整个 backgrounds/ 目录会消失 → ln 因父目录不存在而失败
#    本版已修: 包逐个装(一个装不上不影响其他)、satty 按需从上游下载、ln 前先 mkdir -p。
set -euo pipefail

if [ -n "${SUDO_USER:-}" ]; then
    TARGET_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
    TARGET_HOME="${HOME:-/root}"
fi
THEME_DIR=/usr/share/sddm/themes/user
WALL=/usr/share/backgrounds/user/__Main__.png

echo "=== 1/6 更新软件源 ==="
apt update

echo
echo "=== 2/6 安装缺失软件包 (逐个装, 坏一个不影响其他) ==="
# Debian/Kali 的 apt 是"全有或全无": 清单里只要有一个不存在的包名, 整条命令都会失败。
# README 第 1 步的原始清单里就有 `satty` 这个不存在的包, 所以这里不复用那条命令。
for p in mousepad playerctl brightnessctl libnotify-bin libadwaita-1-0 \
         pipewire wireplumber zsh imagemagick unzip; do
    if dpkg -s "$p" >/dev/null 2>&1; then
        echo "  ✓ $p 已装"
    elif apt-get install -y --no-install-recommends "$p" >/dev/null 2>&1; then
        echo "  ✓ $p"
    else
        echo "  ⚠ $p 装不上 (仓库里可能没有这个包名), 跳过"
    fi
done

echo
echo "=== 3/6 satty (截图标注工具) ==="
if command -v satty >/dev/null 2>&1; then
    echo "  ✓ satty 已在: $(command -v satty)"
elif [ -x /tmp/satty ]; then
    install -m 755 /tmp/satty /usr/bin/satty
    echo "  ✓ 已从 /tmp/satty 安装"
else
    # 上游只发布 flatpak 和二进制 tar.gz, 没有 .deb, Debian/Kali 也从未打包
    tmp="$(mktemp -d)"
    if curl -fL --retry 3 -o "$tmp/satty.tar.gz" \
        "https://github.com/Satty-org/Satty/releases/download/v0.20.1/satty-x86_64-unknown-linux-gnu.tar.gz" \
       && tar -xzf "$tmp/satty.tar.gz" -C "$tmp" \
       && [ -f "$tmp/satty" ]; then
        install -m 755 "$tmp/satty" /usr/local/bin/satty
        echo "  ✓ satty 已下载并安装到 /usr/local/bin/satty"
    else
        echo "  ⚠ satty 下载失败 —— Mod+Shift+S 会只能截图、不能标注 (不影响 grim 本身)"
    fi
    rm -rf "$tmp"
fi

echo
echo "=== 4/6 swaync (通知中心 / 控制面板) ==="
# kali-rolling 现已提供 sway-notification-center 0.12.6-1, 不必再源码编译
if command -v swaync >/dev/null 2>&1; then
    echo "  ✓ swaync 已装: $(command -v swaync)"
elif apt-get install -y sway-notification-center >/dev/null 2>&1; then
    # 配置里写死了 ~/.local/bin/swaync*, 软链一下即可完全兼容
    install -d -o "${SUDO_USER:-root}" "$TARGET_HOME/.local/bin"
    ln -sf /usr/bin/swaync        "$TARGET_HOME/.local/bin/swaync"
    ln -sf /usr/bin/swaync-client "$TARGET_HOME/.local/bin/swaync-client"
    echo "  ✓ 已安装, 并软链到 $TARGET_HOME/.local/bin (配置文件一行都不用改)"
else
    echo "  ⚠ 仓库里没有 sway-notification-center 这个包"
    echo "     → 按 README「5. 安装 SwayNC」里的备选方案源码编译 (meson + ninja)"
fi

echo
echo "=== 5/6 SDDM 主题背景软链 ==="
if [ -d "$THEME_DIR" ]; then
    install -d "$THEME_DIR/backgrounds"      # ← 旧版缺这一步, 于是 ln 失败并把脚本打断
    if [ -f "$WALL" ]; then
        ln -sf "$WALL" "$THEME_DIR/backgrounds/wall.png"
        ls -l "$THEME_DIR/backgrounds/wall.png"
    else
        echo "  ⚠ $WALL 不存在 —— 先把壁纸放进去再重跑本脚本 (README 第 7 步的第 2 条)"
    fi
else
    echo "  ⚠ $THEME_DIR 不存在 —— 先执行 README 第 7 步:"
    echo "      sudo cp -r sddm/user /usr/share/sddm/themes/"
fi

echo
echo "=== 6/6 SDDM 主题配置 (写 conf.d 片段, 不覆盖 /etc/sddm.conf) ==="
install -d /etc/sddm.conf.d
printf '[Theme]\nCurrent=user\n' > /etc/sddm.conf.d/20-niri-user-theme.conf
cat /etc/sddm.conf.d/20-niri-user-theme.conf

echo
echo "=== 全部完成 ==="
cat <<'EOF'
还剩两件需要你确认的事:
  1. Kali 默认桌面是 XFCE, 常自带 lightdm —— 两个显示管理器同时 enable 会互抢 VT:
         systemctl is-enabled lightdm 2>/dev/null && systemctl disable lightdm
         systemctl enable sddm && systemctl set-default graphical.target
  2. 中文输入法环境变量 (README 第 8 步, 必须用 tee -a, 不能用 sudo echo >>):
         sudo tee -a /etc/environment >/dev/null <<'EOT'

         GTK_IM_MODULE=fcitx
         QT_IM_MODULE=fcitx
         XMODIFIERS=@im=fcitx
         SDL_IM_MODULE=fcitx
         INPUT_METHOD=fcitx
         EOT
EOF
