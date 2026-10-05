#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  部署 CachyOS 版配置 (niri-new + noctalia-new) 到 ~/.config
#
#  · 会先把已有的 ~/.config/niri 与 ~/.config/noctalia 改名备份 (带时间戳)
#  · 不会删除任何备份
#  · 部署后自动校验 niri 配置语法与两个 TOML
#
#  回滚方法在脚本末尾会打印出来。
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="$HOME/.config"
STAMP="$(date +%F-%H%M%S)"

echo "═══ 1/4  备份现有配置 ═══"
# fcitx5 也要备份: 中文输入法的 profile 会被下面的部署覆盖 (旧版漏了它)
DIRS="niri noctalia kitty fastfetch fcitx5"
for d in $DIRS; do
    if [[ -e "$CFG/$d" ]]; then
        mv "$CFG/$d" "$CFG/$d.bak-$STAMP"
        echo "  ~/.config/$d  →  $d.bak-$STAMP"
    else
        echo "  ~/.config/$d 不存在, 无需备份"
    fi
done

echo
echo "═══ 2/4  部署 ═══"
mkdir -p "$CFG"
cp -r "$HERE/config/niri-new" "$CFG/niri"
echo "  niri     → ~/.config/niri"

mkdir -p "$CFG/noctalia"
cp -r "$HERE/config/noctalia-new/." "$CFG/noctalia/"
# 清掉 v4 遗留文件: v5 只读 *.toml, 这些不会被读取, 放在 ~/.config 里只会造成误解
rm -rf "$CFG/noctalia/settings.json" "$CFG/noctalia/plugins.json" "$CFG/noctalia/plugins"
echo "  noctalia → ~/.config/noctalia  (已剔除 v4 遗留的 settings.json / plugins.json / plugins/)"

mkdir -p "$CFG/kitty"
# 用 src/. 形式合并而不是整体替换: morandi.conf 由 morandi-gen.py 生成,
# 不能因为部署配置就把它删掉
cp -r "$HERE/config/kitty-new/." "$CFG/kitty/"
echo "  kitty    → ~/.config/kitty   (配色 morandi.conf 由 morandi-gen.py 生成)"
if [[ ! -f "$CFG/kitty/morandi.conf" ]]; then
    echo "  ⚠ ~/.config/kitty/morandi.conf 不存在, 正在生成…"
    python3 "$CFG/noctalia/morandi-gen.py" >/dev/null 2>&1 \
        && echo "    已生成" \
        || echo "    生成失败, kitty 会退回默认配色 (稍后手动跑 morandi-gen.py 即可)"
fi

mkdir -p "$CFG/fastfetch"
# 同 kitty 用 src/. 合并。注意这个文件是 morandi-gen.py 的「引导文件」:
# 它的 write_fastfetch 第一行就是 `if not FASTFETCH_CONFIG.exists(): return`,
# 也就是说文件必须先存在, 脚本才会接管并在每次换壁纸时重写配色。
cp -r "$HERE/config/fastfetch/." "$CFG/fastfetch/"
echo "  fastfetch → ~/.config/fastfetch  (配色由 morandi-gen.py 随壁纸重写)"

# 中文输入法: CachyOS 版没有 spawn fcitx5 那一行(靠 xdg-autostart 拉起), 但
# profile(简体拼音) 等配置仍要铺, 否则登录后切不出中文 —— 旧版部署漏了这一步
mkdir -p "$CFG/fcitx5"
cp -r "$HERE/config/fcitx5/." "$CFG/fcitx5/"
echo "  fcitx5   → ~/.config/fcitx5   (输入法 profile / 简体拼音)"

chmod +x "$CFG/noctalia/apply-morandi.sh" 2>/dev/null || true

echo
echo "═══ 2.5/4  替换路径占位符 ═══"
# 仓库里写的是 /home/YOUR_USERNAME 而不是某个真实用户名, 因为下面这几处
# **无法用变量表达**, 只能写死绝对路径 (原因见各自文件里的注释):
#   · niri 的 environment 块   — 字面量赋值, 不展开 $HOME
#   · noctalia 的壁纸目录/默认图 — 源码里没走 expandUserPath(), 不展开 ~
#   · fastfetch 的 logo.source  — 不展开 $HOME
#   · waybar 的 menu-file       — 是路径不是命令, 不经过 shell
# 其余的路径 (spawn-sh / hook / waybar 的 exec 等) 都已经写成 $HOME, 不需要替换。
subst_placeholder() {
    local f
    for f in "$@"; do
        [[ -f "$f" ]] || continue
        if grep -q 'YOUR_USERNAME' "$f"; then
            sed -i "s|/home/YOUR_USERNAME|$HOME|g" "$f"
            echo "  ${f/#$HOME/~}"
        fi
    done
}
subst_placeholder "$CFG/niri/config.kdl" "$CFG/niri/cfg/"*.kdl \
                  "$CFG/noctalia/config.toml" "$CFG/fastfetch/config.jsonc"

echo
echo "═══ 3/4  校验 ═══"
if command -v niri >/dev/null 2>&1; then
    niri validate -c "$CFG/niri/config.kdl"
else
    echo "  ⚠ 没装 niri, 跳过语法校验 (先按 README「2. 安装 Niri」装好再重跑本脚本)"
fi
for f in "$CFG/noctalia/config.toml" "$CFG/noctalia/settings.toml"; do
    python3 -c "import tomllib,sys;tomllib.load(open(sys.argv[1],'rb'));print('  TOML OK  ' + sys.argv[1])" "$f"
done

echo
echo "═══ 3.5/4  准备 Noctalia 的壁纸目录 ═══"
# Noctalia 的壁纸模块不展开 ~ 也不展开 $HOME, config.toml 里是绝对路径
# (占位符已在 2.5 步替换成 $HOME)。目录和默认图要自己准备, 否则登录后是纯色桌面。
mkdir -p "$HOME/Pictures/wallpapers"
if [[ -f "$HOME/Pictures/wallpapers/__Main__.png" ]]; then
    echo "  ✓ ~/Pictures/wallpapers/__Main__.png 已存在"
else
    echo "  ⚠ ~/Pictures/wallpapers/__Main__.png 不存在 (仓库不含壁纸, 见 .gitignore)"
    echo "    放一张进去, 或登录后在控制中心 → 壁纸里重新选一张"
fi

echo
echo "═══ 4/4  完成 ═══"
echo "从 niri 会话重新登录后生效 (Noctalia 由 niri 的 spawn-sh-at-startup 拉起)。"
echo
echo "如需回滚:"
echo "    rm -rf $CFG/niri $CFG/noctalia"
for d in $DIRS; do
    [[ -e "$CFG/$d.bak-$STAMP" ]] && echo "    mv $CFG/$d.bak-$STAMP $CFG/$d"
done
