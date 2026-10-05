#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  Noctalia v5 源码构建 + 安装 (安装到 ~/.local, 无需 root)
#
#  背景: Noctalia 官方 APT 源的包在 Kali(trixie) 上依赖无法满足
#        (libxml2 / libstdc++6 / libwebp7 版本对不上), 因此只能源码编译。
#
#  用法:
#      ./install_noctalia.sh          # 首次会提示你执行一条 sudo apt 命令
#      装完依赖后再次运行本脚本即可完成构建与安装。
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

SRC="${NOCTALIA_SRC:-$HOME/.cache/noctalia-src}"
PREFIX="${PREFIX:-$HOME/.local}"
REPO="https://github.com/noctalia-dev/noctalia.git"

# 上游 BUILDING.md 的 "Debian / Ubuntu" 依赖清单, 但有一处必须改动:
#
#   libcurl4-openssl-dev → libcurl4-gnutls-dev
#
#   上游写的是 openssl 版, 但 libqalculate-dev (Noctalia 计算器需要) 依赖
#   libcurl4-gnutls-dev, 而这两个包互斥 (Conflicts), 直接照抄会得到:
#       libcurl4-gnutls-dev 冲突 libcurl4-openssl-dev
#       Unable to satisfy dependencies
#   Noctalia 的 meson 只用 pkg-config 找 libcurl, 两种 flavor 都提供 libcurl.pc,
#   因此换用 gnutls 版没有任何副作用。
DEPS=(
  meson g++ just
  libwayland-dev wayland-protocols
  libegl-dev libgles-dev
  libfreetype-dev libfontconfig-dev
  libcairo2-dev libpango1.0-dev libharfbuzz-dev
  libxkbcommon-dev libglib2.0-dev
  libsecret-1-dev libsodium-dev
  libsdbus-c++-dev libpipewire-0.3-dev libwireplumber-0.5-dev
  libpam0g-dev libpolkit-agent-1-dev libpolkit-gobject-1-dev
  libcurl4-gnutls-dev libwebp-dev libjxl-dev libsndfile1-dev librsvg2-dev
  libqalculate-dev libxml2-dev
  libmd4c-dev libtomlplusplus-dev libical-dev
  nlohmann-json3-dev libstb-dev
  libjemalloc-dev
)

echo "═══ 1/5  检查构建依赖 ═══"
missing=()
for p in "${DEPS[@]}"; do
    dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p")
done
if (( ${#missing[@]} > 0 )); then
    echo
    echo "缺少 ${#missing[@]} 个依赖。请先复制执行下面这条命令 (需要 sudo 密码):"
    echo
    echo "    sudo apt install -y ${missing[*]}"
    echo
    echo "装完后重新运行: ./install_noctalia.sh"
    exit 1
fi
echo "✓ 依赖齐全"

echo
echo "═══ 2/5  获取源码 ═══"
if [[ -d "$SRC/.git" ]]; then
    echo "已存在 $SRC, 尝试更新…"
    git -C "$SRC" pull --ff-only || echo "(更新失败, 继续使用现有源码)"
else
    git clone --depth 1 "$REPO" "$SRC"
fi
echo "版本: $(cat "$SRC/VERSION" 2>/dev/null || echo '未知')"

echo
echo "═══ 3/5  配置 (release + LTO) ═══"
cd "$SRC"
just configure release "$PREFIX"

echo
echo "═══ 4/5  编译 (耗时较长, 请耐心等待) ═══"
just build release

echo
echo "═══ 5/5  安装到 $PREFIX ═══"
just install release

echo
echo "验证:"
"$PREFIX/bin/noctalia" --version || true
echo
echo "✓ 完成。文件位于 $PREFIX/bin/noctalia"
echo "  niri 启动时会执行 spawn-sh-at-startup \"noctalia\" (PATH 已含 ~/.local/bin)"
