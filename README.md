# odin-kernel-bakasu

> 小米 MIX 4（odin / SM8350-AC）5.4 非 GKI 内核，内置 [BakaSU](https://github.com/Baka-SU/BakaSU)。
>
> 本仓库由 [cvbyisme/venus-kernel-finaisu](https://github.com/cvbyisme/venus-kernel-finaisu)（小米 11 / venus，FinaSU 方案）移植而来，
> 内核源使用 [Inkypen79/kernel_xiaomi_odin](https://github.com/Inkypen79/kernel_xiaomi_odin) 的 `resukisu` 分支，
> 机型配置参考 [Inkypen79/device_xiaomi_odin](https://github.com/Inkypen79/device_xiaomi_odin)。
>
> ⚠️ **本移植尚未在 MIX 4 实机上验证**。只做了静态/离线验证（见文末），刷机风险自负。

---

## 目标设备

| 项 | 值 |
|---|---|
| 机型 | Xiaomi MIX 4（odin / 2106118C） |
| SoC | Snapdragon 888+ / SM8350-AC（lahaina 平台） |
| 内核基线 | Linux 5.4.302（`Inkypen79/kernel_xiaomi_odin`，默认 `resukisu` 分支） |
| 设备树基线 | `Inkypen79/device_xiaomi_odin`（LineageOS 23.2 分支） |
| 内核配置 | `arch/arm64/configs/odin_defconfig` |
| 分区 | A/B，`boot` + 独立 `dtbo` + `vendor_boot`；boot header v3 |
| 根方案 | BakaSU `v4.2.0-rc3`（KernelSU 系，SUSFS inline hook） |
| 工具链 | ZyCromerZ Clang 14.0.6 |
| 内核类型 | **非 GKI**，vendor 树（`TARGET_KERNEL_SOURCE := kernel/xiaomi/odin`） |

### 为什么是 BakaSU，而不是 ReSukiSU / FinaSU

- ReSukiSU 已经改名并转入 [Baka-SU/BakaSU](https://github.com/Baka-SU/BakaSU) 继续维护，发布 APK 仍以 `ReSukiSU_v4.2.0-*` 命名。
- Inkypen79 的 `resukisu` 分支，其 `KernelSU` 子模块 commit `2c68261` 实际就指向 `Baka-SU/BakaSU`；
  这个分支本质上是 **BakaSU + SUSFS 的 5.4 内核树**，不是已经停止维护的旧代码。
- BakaSU 自带非 GKI 兼容层（`kernel/compat`、`tools/kernel_compat.mk`）和 5.4 的 inline SUSFS 检查，
  因此**不再需要** venus 仓库里那套 FinaSU 专用的 5.4 兼容层（`preflight.sh` / `susfs-setup.sh` / `ksu54-compat.h`）。
- 本仓库保留 `resukisu` 分支作为内核基线，只把 `KernelSU/` 目录替换成 BakaSU 源码；
  `drivers/kernelsu -> ../KernelSU/kernel` 符号链接沿用内核树里的定义。

---

## 快速开始

1. 到 **Actions** 手动运行 `Build odin kernel with BakaSU`（即 `build-bakasu.yml`）
2. 下载 artifact `odin-bakasu-kernel`，或取 Release 里的 `odin-BakaSU-*.zip`
3. 进 **TWRP** 刷入（或支持 AnyKernel3 的内核刷写 App）
4. 重启，打开 **BakaSU / ReSukiSU v4.2.0-rc3** 管理器 —— 首屏显示已获取 root 即完成

> 建议在**用同一棵 `kernel_xiaomi_odin` 源码编译的 ROM** 上使用；跨 ROM 刷 boot 时
> `vendor_boot` / `vendor_dlkm` 里的内核模块可能因 vermagic 不匹配而加载失败（见「风险与限制」）。

**管理器版本要对上**：AK3 内嵌的 ksud 从 BakaSU v4.2.0-rc3 的 APK 中提取；
管理器 APK 与内核不匹配时会表现为「不识别 / 只读」。

**确认刷的是自编内核**：`uname -r` 形如 `5.4.302-Baka-CL-<日期>-<随机>`；
若仍是原厂 `5.4.x-qgki-...`，说明 boot 没刷进去。

### 刷机前

- 备份原厂 `boot.img`（有 TWRP 就备份 `boot_a`；A/B 机型注意当前 slot）
- 本包只写 **boot**，不改 `dtbo` / `vendor_boot`
- 首次刷建议准备好可进入的 TWRP 或原厂 boot，方便回滚

---

## 相对 venus（FinaSU）仓库改了什么

| 项 | venus / FinaSU | odin / BakaSU（本仓库） |
|---|---|---|
| 内核仓库 | `cvbyisme/..._miyume` @ `main` | `Inkypen79/kernel_xiaomi_odin` @ `resukisu` |
| 根方案 | FinaSU v1.5.0（KernelSU fork） | BakaSU v4.2.0-rc3（KernelSU 系） |
| defconfig | `venus_defconfig` | `odin_defconfig` |
| hook 方式 | FinaSU tracepoint + `ksu54-compat` 兼容层 | BakaSU **SUSFS inline**（`CONFIG_KSU_SUSFS=y`） |
| SUSFS 来源 | 内核树 v2.1.0 + 脚本对齐 v2.3.0 | 内核树自带 v2.1.0，BakaSU 直接读取/展示 |
| 兼容脚本 | `preflight.sh` / `susfs-setup.sh` / `ksu54-*` | **不需要**（BakaSU 自带 `kernel/compat`） |
| 签名参数 | `KSU_SECOND_SIGNATURE_RELEASE` / `KSU_EXPECTED_*2` | **不需要**（BakaSU 内置 ReSukiSU 签名默认值） |
| AnyKernel3 设备名 | `venus` | `odin` |
| 分区 | boot | boot（A/B，`IS_SLOT_DEVICE=1`） |
| 产物 | `venus-*` | `odin-*` / `odin-bakasu-*` |

### 关于 5.4 的 hook 选择

BakaSU 的 Kconfig 默认是 `KSU_TRACEPOINT_HOOK`，但注释明确写它只支持 GKI 2.0（5.10+）。
5.4 上必须选 **`KSU_SUSFS`（SUSFS inline hook）** 或 `KSU_MANUAL_HOOK`。
本仓库沿用内核树 `resukisu` 的现成 inline 调用点：

```text
CONFIG_KSU=y
CONFIG_KSU_SUSFS=y          # 同时是 hook 方式与 SUSFS 功能开关
CONFIG_KSU_SUSFS_SUS_PATH=y
...
# CONFIG_KSU_TRACEPOINT_HOOK is not set
```

workflow 会显式 `--disable KSU_TRACEPOINT_HOOK`，并在配置门禁里检查它没有落回 `=y`，
否则 BakaSU 的 Kbuild 会在编译期直接报错（TP hooks incompatible with Non-GKI）。

### 构建流程

```text
clone kernel (resukisu) → sched-tune
→ 克隆 BakaSU（完整 git 历史，tag v4.2.0-rc3）覆盖 KernelSU/
→ susfs-bakasu-compat（v2.1.0 helper 兼容函数）
→ 预生成 init/version.o（compile.h）与 security/selinux
→ clang 14.0.6 构建 odin_defconfig（KSU_SUSFS inline）
→ 配置门禁（KSU / KSU_SUSFS / sub-options / KPROBES / 非 TRACEPOINT）
→ Image + Image.gz
→ AnyKernel3（device=odin, BLOCK=/dev/block/bootdevice/by-name/boot）
```

> BakaSU 4.2 使用 `susfs_*_no_su` / `zygote_next` 新 helper 名，而 odin 树的 SUSFS v2.1.0
> 只有 `*_umounted` 名字；`scripts/susfs-bakasu-compat.sh` 会在构建前补真实函数，
> 否则 vmlinux 链接会报 `undefined symbol: susfs_set_current_proc_no_su`。
>
> BakaSU 的 `core/init.c` 会 `include <generated/compile.h>`，该头由 `make init/version.o` 生成
> （不是 `make prepare`），workflow 已显式预生成，避免 “No such file” 报错。
>
> BakaSU 的 Kbuild 会用 `git describe` / `git rev-list --count` 计算版本，
> 并要求 `KernelSU` 是真正的 git 仓库，所以 workflow 对 BakaSU 使用**完整 clone**，不能用 `--depth 1`。

---

## 构建

所有 workflow 都是 `workflow_dispatch` 手动触发。

| 文件 | 作用 |
|---|---|
| `build-bakasu.yml` | **主线**：BakaSU v4.2.0-rc3 + `root_mode`（inline/manual）+ 功耗调优 + ksud 内嵌；发布 `odin-bakasu-<n>` |
| `pure.yml` | 不含 root/SUSFS 的纯内核，用于排查基线 / 工具链 / 模块 vermagic |
| `pack.yml` / `pack-pure.yml` | 对已有 run 的 artifact 重新打 AnyKernel3 包 |

### 常用输入

- `kernel_repo` / `kernel_ref`：默认 `Inkypen79/kernel_xiaomi_odin` / `resukisu`
- `bakasu_ref`：BakaSU ref，默认 `v4.2.0-rc3`
- `root_mode`：`susfs_inline`（默认，SUSFS）/ `manual`（5.4 更稳，仅 root，无 SUSFS）
- `ksud_apk_url`：用于抽 `libksud.so` 的管理器 APK，默认对应 v4.2.0-rc3 的 arm64 APK
- `embed_ksud`：是否在 AK3 内嵌匹配版本的 ksud（默认 true）

### 脚本

| 文件 | 作用 |
|---|---|
| `scripts/susfs-bakasu-compat.sh` | inline 模式：在 fs/susfs.c 补齐 BakaSU 4.2 需要的 SUSFS helper 函数 |
| `scripts/ksu-manual-hooks.sh` | manual 模式：给 odin 树补 `CONFIG_KSU_MANUAL_HOOK` 调用点 |
| `scripts/power-tune.sh` | 默认 governor 改 `schedutil` |
| `scripts/sched-tune.sh` | 应用 `sched-patches/*.patch`（幂等 + `git apply --check` 门禁） |
| `scripts/sched-patches/pelt-force.patch` | schedutil 强制 PELT util 路径（按 odin 源码生成） |
| `scripts/sched-patches/s1-input-boost-off.patch` | `cpu-boost` 输入提升默认关 |
| `scripts/sched-patches/s2-io-is-busy-off.patch` | WALT `io_is_busy` 默认 0 |
| `scripts/ak3-ksud.sh` | AK3 内嵌 / 清理 ksud |
| `scripts/odin-selftest.sh` | 刷完自检（PASS/WARN/FAIL 表） |
| `scripts/collect-logs.sh` | 一键收集日志打包 zip |

> CI 里 `actions/checkout` 使用 `path: ci`，所以脚本路径是 `ci/scripts/*`。

---

## 刷完自检

```sh
curl -sL -o /sdcard/Download/odin-selftest.sh \
  https://raw.githubusercontent.com/<你的账号>/odin-kernel-bakasu/main/scripts/odin-selftest.sh
su -c 'sh /sdcard/Download/odin-selftest.sh'
```

检查项：内核身份（`/proc/version` 含 `Baka-CL`）、BakaSU feature、SELinux 域、
三簇 governor、input_boost / io_is_busy、zram、电池、安全补丁、模块、dmesg 异常、boot 备份。
报告落在 `/sdcard/Download/odin-selftest-<时间>.txt`。

收集日志：

```sh
su -c 'sh /sdcard/Download/collect-logs.sh'
# 产物 /sdcard/Download/odin-logs-<时间>.zip
```

---

## 风险与限制

- **未在 MIX 4 实机验证**：只做了静态验证（补丁可应用、BakaSU 与内核符号互相匹配、YAML/脚本语法）。
- **ROM / 内核模块依赖（MIX 4 尤其重要）**：
  设备树把 `msm_drm.ko`、`fts_touch_spi.ko`、`hwid.ko`、`xiaomi_touch.ko` 列为
  `BOOT_KERNEL_MODULES`（至少 recovery ramdisk 会加载；正式系统里它们可能在
  `vendor_boot` 或 `vendor_dlkm`，取决于 ROM 的打包方式），这些模块是**按 ROM 自己的
  内核版本 / vermagic 编译**的。本仓库的 AK3 只替换 `boot` 里的 kernel，不会更新这些模块；
  如果 ROM 内核版本与本内核（5.4.302 + `Baka-CL` 后缀）不一致，模块可能因 vermagic 不匹配
  而加载失败，表现为黑屏 / 无触摸。推荐在用同一棵 `kernel_xiaomi_odin` 编译的 ROM 上刷入，
  或自行把匹配的 .ko 重新打进 `vendor_boot` / `vendor_dlkm`。
- **SUSFS 版本**：内核树自带 SUSFS v2.1.0，BakaSU v4.2.0-rc3 的管理器能读取并展示版本；
  如果管理器要求更新的 SUSFS 命令集，部分 SUSFS 功能可能不可用，但 root 不受影响。
- **工具链与 defconfig 的落差**：`odin_defconfig` 由 Android clang r574158（21）生成，
  且开启了 `CONFIG_LTO_CLANG` / `CONFIG_CFI_CLANG`；本仓库沿用 ZyC clang 14.0.6。
  clang 14 支持 5.4 的 ThinLTO/CFI，但若 CI 在 LTO/CFI 阶段报错，优先换匹配的 clang 21，
  不要直接关 CFI——ROM 侧的 `msm_drm.ko` 等模块可能是按 CFI 编译的。
- **AVB / Bootloader**：需要解锁 Bootloader。原厂 AVB 校验可能拒绝未签名的 boot；
  Lineage 等自编译 ROM 通常已处理 vbmeta，本包不修改 `vbmeta`。
- **BakaSU 不是 FinaSU**：管理器、ksud、签名都换了。不要用 FinaSU 管理器配这个内核，
  也不要把本内核和 FinaSU 的 `KSU_SECOND_SIGNATURE_RELEASE` 参数混用。

---

## 验证状态（迁移时做过什么）

对 `Inkypen79/kernel_xiaomi_odin@resukisu` + `Baka-SU/BakaSU@v4.2.0-rc3` 做了离线验证：

| 项 | 结果 |
|---|---|
| BakaSU 引用的 `susfs_*` 符号 | 全部能在内核 SUSFS 或 BakaSU 自身（`selinux.c` / `sucompat.h`）找到 |
| 内核引用的 `ksu_handle_*` 符号 | BakaSU 全部提供（`execveat` / `faccessat` / `stat` / `sys_read` / `sys_reboot` / `setresuid` / `input`） |
| BakaSU inline hook 检查所需调用点 | `fs/{exec,open,stat,read_write}.c`、`kernel/{sys,reboot}.c`、`drivers/input/input.c` 均存在 |
| `s1` / `s2` / `pelt-force` 补丁 | 两棵 odin 树 `git apply --check` 通过 |
| `odin_defconfig` | `KSU=y`、`KSU_SUSFS*`、`KPROBES`、`THREAD_INFO_IN_TASK`、`EXT4_FS`、`OVERLAY_FS`、`MODULES` 均存在；`KSU_TRACEPOINT_HOOK` 未启用 |
| workflow YAML | `yaml.safe_load` 通过 |
| shell 脚本 | `bash -n` 通过 |

**没有做**：完整内核编译（本机无 Linux 工具链）与 MIX 4 实机刷入。

---

## 参考

- [cvbyisme/venus-kernel-finaisu](https://github.com/cvbyisme/venus-kernel-finaisu) —— 方案来源
- [Baka-SU/BakaSU](https://github.com/Baka-SU/BakaSU) —— 根方案（原 ReSukiSU）
- [Inkypen79/kernel_xiaomi_odin](https://github.com/Inkypen79/kernel_xiaomi_odin) —— 内核源（5.4.302）
- [Inkypen79/device_xiaomi_odin](https://github.com/Inkypen79/device_xiaomi_odin) —— MIX 4 设备树
- [simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu) —— SUSFS
- [osm0sis/AnyKernel3](https://github.com/osm0sis/AnyKernel3) —— 刷机包模板

## License

见 [LICENSE](LICENSE)。
