# bin/ —— 预编译二进制与安装包

**这个目录里的文件不进 git 仓库**（见根目录 `.gitignore`）。

原因：`MapleMonoNormal-NF-CN.zip` 单个就有 **153 MB**，超过 GitHub 单文件
100 MB 的硬限制，推不上去。其余两个加起来也有 30 MB。

需要的话按主 README 的安装步骤自行获取，放到这里即可 —— 主 README 里
写的是相对路径 `bin/...`，放对位置就能照着敲。

| 文件 | 大小 | 用途 | 怎么获取 |
|---|---|---|---|
| `MapleMonoNormal-NF-CN.zip` | 153 MB | Maple Mono NF CN 字体（**基础版**的 kitty / 锁屏 / SDDM 用） | README「3. 安装字体」方法 B 的 wget（压缩包实测完好：16 个 `.ttf`） |
| `niri_26.4.0-1_amd64.deb` | 22 MB | niri 安装包 | 见下方「这个 deb 的来历与前提」 |
| `swww`, `swww-daemon` | 8 MB | 壁纸程序（**基础版**用；CachyOS 版由 Noctalia 接管壁纸） | README「4. 安装 Swww」方法 B 自行编译 |

## 这个 deb 的来历与前提（重要）

它**不是**从 niri 官方 release 下载的：上游 release **只发布源码**
（`niri-26.04-vendored-dependencies.tar.xz` + source zip/tar.gz），从不发 `.deb`；
Debian / Kali 仓库里也没有 niri 二进制包（只有 `librust-niri-ipc-dev`、`niri-companion`）。
这个 deb 是在作者机器上用 `cargo deb` 打出来的 —— 包里的 `Maintainer`、`Homepage`、
`Description` 都直接取自上游 `Cargo.toml`，所以看起来像官方包。

由此有两个必须知道的后果：

1. **它不声明任何库依赖**：`Depends` 只有 `alacritty, fuzzel`。缺 `.so` 时 apt 不报错，
   niri 却在启动瞬间崩。安装后请自检：

   ```bash
   ldd "$(command -v niri)" | grep 'not found'
   ```

   实测该二进制需要 17 个 `.so`，其中三个容易缺：

   | 缺的库 | 提供它的包 | 备注 |
   |---|---|---|
   | `libdisplay-info.so.3` | `libdisplay-info3` | **Debian 13 trixie 只有 `.so.2`** → 那种系统上这份 deb 用不了；当前 kali-rolling 是 0.3.0，没问题 |
   | `libseat.so.1` | `libseat1` | Kali 基础系统默认**没装** |
   | `libpipewire-0.3.so.0` | `libpipewire-0.3-0t64` | 同上，注意 t64 后缀 |

2. **它绑定了较新的 glibc**（最高引用 `GLIBC_2.39`）—— Debian 12 "bookworm" 或
   2024 年的 Kali（glibc 2.36）上跑不起来。

想稳一点就用 rustup 的工具链自己 `cargo build --release`（niri 官方文档也只认这条，
它从不提 `cargo deb`），落盘位置见主 README「2. 安装 Niri」方法 B。

> `swww` 那两个二进制反而是**几乎静态链接**的：实测 `DT_NEEDED` 只有
> `libc` / `libgcc_s` / `liblz4` / `libm`，目标机只要有 `liblz4-1` 就能直接拷过去用。
> （旧版这里写的是"动态链接的二进制直接拷到别的机器不一定能跑"，实测不成立。）
