<div align="center">

# GKI KernelSU SUSFS
### 专为 BakaSU (原 ReSukiSU) 打造的自动构建仓库

**自动化构建 GKI 内核 | 集成 BakaSU + SUSFS**

[![Release](https://img.shields.io/github/v/release/femmynuppu/GKI_KernelSU_SUSFS?label=Release&style=flat-square&logo=github&logoColor=white&color=2ea44f)](https://github.com/femmynuppu/GKI_KernelSU_SUSFS/releases)
[![BakaSU](https://img.shields.io/badge/BakaSU-Supported-5AA300?style=flat-square)](https://bakasu.org/)
[![SUSFS](https://img.shields.io/badge/SUSFS-Integrated-E67E22?style=flat-square)](https://gitlab.com/simonpunk/susfs4ksu)

---

</div>

## ⚠️ 仓库须知

① 本仓库专为 [Baka-SU/BakaSU](https://github.com/Baka-SU/BakaSU)（原 ReSukiSU）打造的自动化构建流，适配最新 BakaSU 内核驱动与管理端。

② 默认变体为 **BakaSU**，原生内置 SUSFS 支持、多管理器兼容（Multi-Manager）、NoMount VFS 与 TCP BBR 优化。

---

## ⚠️ 兼容性提醒

> **BakaSU：由原 ReSukiSU 更名而来（https://github.com/Baka-SU/BakaSU），文档见 https://bakasu.org**
>
> **默认变体已全面升级为 BakaSU**

> **Android 16：已支持 Android 16 - 6.12 内核版本**

> **多管理器支持（Multi-Manager）：内核驱动原生支持 BakaSU、KOWSU、SukiSU-Ultra 等多种管理器**

> **rekernel功能（测试）：已支持 rekernel 功能（目前处于测试阶段）**

---

## 🧪 Droidspaces 容器支持（实验性）

> **实验性功能：** 不保证所有 GKI 版本均能成功构建或启动，刷入前请务必备份 Boot 镜像。
>
> **TIPS：** 工作流使用的是 [Droidspaces](https://github.com/ravindu644/Droidspaces-OSS) 的 [官方补丁](https://github.com/ravindu644/Droidspaces-OSS/tree/main/Documentation/resources/kernel-patches/GKI) ，如有更好的补丁可以提个issues，此外由于存在三个补丁，或许需要反复试验以确保其中一个适配你的机型，请根据他人或实际经验来选择。

[Droidspaces](https://github.com/ravindu644/Droidspaces-OSS) 是一个轻量级的 Linux 容器工具，可以在 Android 上运行完整的 Linux 环境（支持 systemd、OpenRC 等），用于搭建开发环境、运行服务器等场景。

**支持范围：** 5.10 / 5.15 / 6.1 / 6.6 / 6.12

**使用方式：** 在手动触发构建时，选择 `Droidspaces 容器支持` 选项：

| 选项 | 说明 |
|:---:|:---|
| `off` | 关闭（默认） |
| `678` | 使用 6_7_8 槽位补丁（推荐） |
| `123` | 使用 1_2_3 槽位补丁（备用） |
| `345` | 使用 3_4_5 槽位补丁（备用） |

> **提示：** 6.12 内核仅有一个补丁，选择任意非关闭选项即可。

**如果构建失败或刷入后 bootloop：** 可尝试切换到其他槽位补丁（如 678 → 123 或 345），不同内核子版本可能适用不同的补丁。

---

## 🧪 伪装 `/proc/config.gz`（Stock Config）

这是一个进阶技巧，不需要在工作流里手动开关。  
构建时会自动检测 `config/stock_defconfig` 是否存在：存在则应用，不存在则跳过。

使用方法：
1. 确保设备当前是官方 ROM + 官方内核。
2. 获取设备上的 `/proc/config.gz`（可在手机端或电脑端操作）。
3. 解压后重命名为 `stock_defconfig`，上传到仓库 [`config/`](config/) 目录并提交（可直接在手机端完成）。

构建流程会自动：
- 复制到内核源码：`$KERNEL_ROOT/common/arch/arm64/configs/stock_defconfig`
- 在 `$KERNEL_ROOT/common/kernel/Makefile` 中将 `$(obj)/config_data` 规则从 `$(KCONFIG_CONFIG)` 切换为 `arch/arm64/configs/stock_defconfig`
- 使编译产物中的 `/proc/config.gz` 更贴近你的官方内核配置

---

<div align="center">

**更多内容持续更新中...**

⭐ 如果这个项目对你有帮助，请点个 Star 支持一下！

⭐ 新预构建发布通知/重大变更通知请关注我们的[Telegram频道](https://t.me/ReSukiSUKernelBuilds)

</div>
