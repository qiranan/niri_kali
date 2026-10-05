# 本次修订说明（相对旧版 README）

目标：让"照着 README 走"真能装完，并把"必须手动编译/获取"的部分标清楚。

**验证环境**：Kali GNU/Linux Rolling 2026.3（`kali-rolling` 源，x86_64）。
包状态用 `apt-cache policy` 查；命令行为用 `bash` 实跑；二进制依赖通过解析 deb 内
ELF 的 `DT_NEEDED` 得到。逐条证据见文末「验证方式」。

---

## 一、Kali 仓库里没有、必须手动补齐的组件

| 包 | `apt-cache policy` 实测 | 修订后的做法 |
|---|---|---|
| `niri` / `niri-session` | **NOT-FOUND**（Debian 全系也只有 `librust-niri-ipc-dev`、`niri-companion`） | 用 `bin/` 里的预编译 deb（**必须写 `apt install ./xxx.deb`**），或按官方文档 `cargo build --release` 自行编译 |
| `swww` | **NOT-FOUND**（上游已改名 `awww` 并搬到 Codeberg） | 用 `bin/` 里那两个二进制（近乎静态链接，只需 `liblz4-1`），或自行编译 |
| `noctalia` | **NOT-FOUND** | 只能源码编译：`install_noctalia.sh` |
| `satty` | **NOT-FOUND**（上游只有 flatpak + 二进制 tar.gz） | 从上游下载 tar.gz，装到 `/usr/local/bin` |

## 二、不必再自己编译的（旧版信息已过时）

| 组件 | 旧版说法 | 实测 |
|---|---|---|
| `swaync` | "Kali 仓库暂无 swaync, 需从源码编译" | kali-rolling 有 **`sway-notification-center 0.12.6-1`** —— 正是旧版让你编译的那个版本。`apt install` + 两个软链即可，配置文件零改动 |
| `hyprlock` | 直接列在 apt 清单里 | kali-rolling 有 `0.9.6-1+b1`（Debian 13 trixie 没有，只在 trixie-backports / forky 里） |

## 三、逐条修订

1. **`sudo apt install niri_26.4.0-1_amd64.deb` 必失败**：实测
   `E: Unable to locate package niri_26.4.0-1_amd64.deb`。apt 需要显式路径 →
   改为 `sudo apt install ./niri_26.4.0-1_amd64.deb`。
2. **§1 清单里的 `satty` 不存在**：apt 是"全有或全无"，一个包名错会让**整条命令失败**
   （前面已列出的包也不会装）→ 从清单移出，改为 §1.2 单独安装，并提醒"以后加包先
   `apt-cache policy` 确认"。
3. **§1 漏装的依赖**：`playerctl`（媒体键）、`brightnessctl`（亮度键）、`libnotify-bin`
   与 `mousepad`（`scripts/ocr.sh`）、`zsh`（`Mod+S` 的绑定）、`imagemagick`
   （`morandi-gen.py` 的 `magick`）、`pipewire` + `wireplumber`（基础版音量键的 `wpctl`）、
   `fcitx5-frontend-*`、`xdg-desktop-portal-*`、`gnome-keyring`、`upower`
   → 新增 §1.1，并逐项注明"谁在用"。
4. **§2 方法 B 的 `cargo deb` 走不通**：`cargo-deb` 在 Debian 没有包（只有
   `cargo-debstatus`），niri 官方文档也从不用它、上游 release 只发源码
   → 改为官方步骤：rustup 装最新 stable + 官方依赖清单（比旧版多 7 个包）+
   `cargo build --release` + 官方推荐的 6 个落盘位置。
5. **预编译 deb 不声明库依赖**：`Depends` 只有 `alacritty, fuzzel`；实测该二进制需要
   17 个 `.so`，最高引用 `GLIBC_2.39`。已加 `ldd` 自检步骤与包名对照表 ——
   `libseat1` 在 Kali 默认**没装**；`libdisplay-info.so.3` 只在 forky/sid/当前 rolling
   上有（trixie 是 `.so.2`）→ 在 trixie 系系统上这份 deb 装上也起不来。
6. **§6 的 `sed 's|/home/zz|...|'` 是死代码**：仓库里已无 `/home/zz`，占位符叫
   `/home/YOUR_USERNAME`。实测跑完那三行 sed，`config/waybar/config.jsonc` 里仍是
   `/home/YOUR_USERNAME/...` → waybar 电源按钮弹不出菜单。已改为正确的 sed，
   并补上 `swaync` / `fastfetch` 的备份、`chmod +x`、截图与壁纸目录。
7. **§7 SDDM 三处**：
   - 仓库里 `sddm/user/backgrounds/wall.png` 是**指向 `/usr/share/backgrounds/user/__Main__.png`
     的绝对软链**，从 Windows 拷过来会整个丢失（本目录实测已丢）→ 补
     `mkdir -p .../backgrounds` + `ln -sf`；
   - `... | sudo tee /etc/sddm.conf` 会**覆盖**整个文件 → 改写
     `/etc/sddm.conf.d/20-niri-user-theme.conf`；
   - 补 lightdm 同时 enable 的冲突提醒，以及"把 Maple 字体也装到
     `/usr/local/share/fonts`"（SDDM 以 sddm 用户运行，看不到 `~/.local/share/fonts`）。
8. **§8 的 `sudo echo "..." >> /etc/environment` 必然失败**：重定向由**当前用户**的 shell
   执行，实测该文件是 `-rw-r--r-- root root` → 改 `sudo tee -a`，并写成可重复执行。
9. **`finish_sudo_setup.sh` 会中途死掉**（且旧版 README 从未提到这个脚本）：
   - 第 3 步 `install -m755 /tmp/satty /usr/bin/satty`：`/tmp/satty` 通常不存在 →
     `set -e` 直接中断，后面的步骤全不执行；
   - 第 5 步 `ln -sf .../backgrounds/wall.png`：父目录不存在同样中断。
   已改为：包逐个装（一个装不上不影响其他）、satty 按需从上游下载、ln 前 `mkdir -p`、
   并补 swaync / pipewire 等；README 新增「收尾脚本」一节。
10. **`deploy_cachyos_config.sh` 补强**：新增 `~/.config/fcitx5` 的备份与部署（旧版不铺
    输入法配置，而 CachyOS 版又没有 `spawn fcitx5` 那一行 → 登录后切不出中文）、
    新增 Noctalia 壁纸目录的准备与提示、没装 niri 时不再因 `niri validate` 报错退出。
11. **`morandi-gen.py` 的健壮性**（"换壁纸后配色只变了一半"的根因）：
    - `apply_system_changes()` 里的 `sudo magick … /boot/efi/limine_bg.png` 与
      `subprocess.Popen(["fcitx5"])` 原本**没有保护**：缺 imagemagick、缺 `/boot/efi`、
      sudo 要密码、没装 fcitx5 都会抛异常并中断整个脚本；
    - 它还在 `main()` 里被**调用两次**（两次 sudo 提示、fcitx5 重启两次）；
    - 所有 `write_*` 都是裸调用，任何一个抛异常都会让后面的软件拿不到配色。
    现已加 `ENABLE_LIMINE` 开关（默认开，缺失条件只提示跳过）、`safe()` 包装、
    并把 `apply_system_changes()` 收敛为只调用一次。
12. **CachyOS 段**：`cd ~/下载/niri_for_kali-main` 改为"换成你自己的路径"；手动部署补上
    **占位符替换**这一步（漏掉它，niri 的 `environment { PATH }` 会留着
    `/home/YOUR_USERNAME/.local/bin`，登录后找不到 noctalia，状态栏/壁纸/锁屏全不出现）；
    补壁纸目录说明、`Mod+B`/`Mod+E` 需要 firefox / nautilus、验证清单加 `ldd` 与
    `pgrep fcitx5`。
13. **`bin/README.md` 更正两处事实**：那个 niri deb **不是官方 release**（上游只发源码，
    deb 是作者用 `cargo deb` 打的，元数据取自上游 `Cargo.toml`），且**不声明库依赖**、
    绑定 glibc 2.39；而 `swww` 那两个二进制其实**近乎静态链接**。
14. **新增 `install_all.sh`**：把上述流程串成一条命令（`basic` / `cachyos` 两种模式）：
    CRLF 修正 → 必需包/可选包分开装 → niri（含 `ldd` 自检）→ swaync（apt 优先）→
    swww / Noctalia → 字体 → 壁纸 → 部署配置 → SDDM → `/etc/environment` → 自检清单。

## 四、仍然只能人工处理的三件事

1. **Windows 专有字体**：CachyOS 版的界面字体 `Segoe UI` + `微软雅黑 UI` 仓库不能分发，
   必须自己从 Windows 的 `C:\Windows\Fonts\` 拷 16 个文件（README「9. Windows 字体」）。
2. **壁纸**：`wallpapers/` 被 gitignore；桌面 / 锁屏 / SDDM / Noctalia 都指向固定路径，
   需自己放一张图。
3. **`bin/` 里的三个大文件**（字体包 153M、niri deb 22M、swww 8M）：从 GitHub 克隆拿不到，
   需向作者索取，或按各步骤自行下载 / 编译。

## 五、验证方式（可复现）

| 验证项 | 方法 | 结果 |
|---|---|---|
| 包是否存在 | `apt-cache policy niri niri-session noctalia swww satty sway-notification-center hyprlock rustc just libdisplay-info3` | 前五个 NOT-FOUND；swaync 0.12.6-1；hyprlock 0.9.6-1+b1；rustc 1.95；just 1.58 |
| apt 的路径要求 | `apt-get install -s niri_26.4.0-1_amd64.deb` vs `-s ./bin/niri_26.4.0-1_amd64.deb` | 前者 `Unable to locate package`；后者会装 niri 26.4.0-1 并带出 alacritty + fuzzel |
| `/etc/environment` 权限 | `ls -l /etc/environment` + 非 root 追加 | `-rw-r--r-- root root`，追加失败 |
| 占位符是否被旧 sed 处理 | 假 `$HOME` 下跑旧 sed 后 `grep YOUR_USERNAME` | 仍有残留 → 电源菜单坏 |
| 部署脚本 | 假 `$HOME` 下跑 `deploy_cachyos_config.sh` | 备份/部署/占位符替换/壁纸目录/跳过校验均正常，退出码 0 |
| 配色脚本 | 假 `$HOME` 下跑 `morandi-gen.py`（含 `--wallpaper`，无 `/boot/efi`、无 fcitx5） | 退出码 0、无 Traceback、打印"跳过 Limine 引导图"，niri/kitty 配色正常生成 |
| 二进制依赖 | 解析 `usr/bin/niri`、`bin/swww`、`bin/swww-daemon` 的 ELF `DT_NEEDED` | niri：17 个 `.so`，最高 `GLIBC_2.39`；swww：4 个（`libc/libgcc_s/liblz4/libm`） |
| 语法检查 | `bash -n` 全部 `.sh`、`python3 -m py_compile morandi-gen.py` | 全部通过 |

**未做**：在真机上完整装一遍桌面。本机可用的 Kali 是 WSL 发行版（无 `/dev/dri`），
niri 在其中无法启动，因此只验证到"包状态 / 命令行为 / 脚本逻辑"这一层。
