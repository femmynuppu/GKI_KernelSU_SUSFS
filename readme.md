<div align="center">

# GKI KernelSU SUSFS
### Automated GKI Kernel Builder for BakaSU & SUSFS

**Automated Android GKI Kernel Builds | Integrated BakaSU + SUSFS + NoMount VFS**

[![Release](https://img.shields.io/github/v/release/femmynuppu/GKI_KernelSU_SUSFS?label=Release&style=flat-square&logo=github&logoColor=white&color=2ea44f)](https://github.com/femmynuppu/GKI_KernelSU_SUSFS/releases)
[![BakaSU](https://img.shields.io/badge/BakaSU-Supported-5AA300?style=flat-square)](https://bakasu.org/)
[![SUSFS](https://img.shields.io/badge/SUSFS-Integrated-E67E22?style=flat-square)](https://gitlab.com/simonpunk/susfs4ksu)
[![License: GPL v3](https://img.shields.io/badge/License-GPL%20v3-blue.svg?style=flat-square)](LICENSE)

---

</div>

## 📖 Overview

This repository provides an automated CI/CD build pipeline for **Android Generic Kernel Images (GKI)** featuring **BakaSU** (formerly ReSukiSU) and **SUSFS**. It supports all Android GKI versions from **Linux 5.10 up to 6.12**, packaged into universal **AnyKernel3** flashable zip archives.

---

## ⚡ Core Features

* **BakaSU Root Solution**: Full integration of [Baka-SU/BakaSU](https://github.com/Baka-SU/BakaSU) (downstream KernelSU fork with native SUSFS support).
* **SUSFS Root Hiding**: Kernel-level inline hooks for stealth root hiding (`sus_path`, `sus_mount`, `sus_kstat`, `sus_map`, `open_redirect`, and uname spoofing).
* **NoMount VFS (v1.1.0)**: Mountless path redirection and virtual file injection without triggering Android VFS mountpoint inspection or peer group gap detection.
* **TCP BBR Default**: TCP congestion control configured to BBR by default with FQ pacing (`CONFIG_DEFAULT_BBR=y`).
* **ZRAM LZ4KD Compression**: High-efficiency, low-latency ZRAM decompression algorithm (`CONFIG_ZRAM_DEF_COMP_LZ4KD=y`) for optimized memory throughput.
* **Baseband Guard (BBG)**: Partition protection hooks preventing malicious scripts or rogue apps from wiping critical NVRAM/EFS/radio partitions.
* **Hardware & Camera Stability**: Includes backported `rt_mutex` fixes (CVE-2026-43499) preventing kernel panics on vendor camera ISP drivers.
* **Multi-Manager Support**: Built-in driver support allowing control via BakaSU Manager, KOWSU, or SukiSU-Ultra managers.
* **Uname & Timestamp Spoofing**: Complete camouflage of `uname -r`, `uname -v`, and build timestamps to match official stock factory kernels.

---

## 📱 Compatibility Matrix

| Android Version | Linux Kernel | Supported Sublevels | Build Engine |
|:---:|:---:|:---:|:---:|
| **Android 12** | 5.10 | 66 – 246, LTS | Classic Clang + `build.sh` |
| **Android 13** | 5.15 | 41 – 178, LTS | Classic Clang + `build.sh` |
| **Android 14** | 6.1 | 25 – 176, LTS | Google Bazel / Kleaf |
| **Android 15** | 6.6 | 17 – 107, LTS | Google Bazel / Kleaf |
| **Android 16** | 6.12 | 0 – 38, LTS | Google Bazel / Kleaf |

> **Universal GKI Notice:** These kernels conform to Google's official GKI specification and boot on any Android device with a matching major Linux kernel version.

---

## 🚀 How to Build

1. Go to the **[Actions](../../actions)** tab in this repository.
2. Select **`Android 内核构建-自定义` (Custom Kernel Build)** or individual kernel workflows.
3. Click **Run workflow**, configure your parameters:
   * **Android Version**: `android12`, `android13`, `android14`, `android15`, `android16`
   * **Kernel Version**: `5.10`, `5.15`, `6.1`, `6.6`, `6.12`
   * **Sublevel**: e.g., `236` (for 5.10) or `118` (for 6.1)
   * **Security Patch Level**: e.g., `2025-05`
   * **Custom Version / Spoofing**: (Optional) Provide stock release name and build date
   * **Feature Toggles**: Enable/disable NoMount, BBG, ZRAM, or SUSFS as desired.
4. When the build finishes, download the flashable `AnyKernel3.zip` artifact from the run summary page.

---

## 🧪 Advanced Features

### 1. Droidspaces Container Support (Experimental)
Supports running chroot/containerized Linux distributions (systemd, OpenRC) on Android via [Droidspaces](https://github.com/ravindu644/Droidspaces-OSS) patches:
* `off`: Disabled (default)
* `678`: Slot 6/7/8 patch (recommended for most devices)
* `123`: Slot 1/2/3 patch (alternative)
* `345`: Slot 3/4/5 patch (alternative)

### 2. Stock Config Camouflage (`/proc/config.gz`)
To match your device's exact factory kernel configuration:
1. Extract `/proc/config.gz` from your stock rom.
2. Decompress and rename it to `stock_defconfig`.
3. Place it in `config/stock_defconfig` in this repository.
4. The build pipeline will automatically detect it and use it as the config template.

---

## 🤝 Credits & Acknowledgments

* **[Baka-SU](https://github.com/Baka-SU/BakaSU)**: The next-generation KernelSU downstream root solution.
* **[simonpunk](https://gitlab.com/simonpunk/susfs4ksu)**: Author of SUSFS (Super User SUS FileSystem).
* **[osm0sis](https://github.com/osm0sis/AnyKernel3)**: AnyKernel3 template and core scripts.
* **[maxsteeel](https://github.com/maxsteeel/nomount)**: NoMount VFS implementation.
* **[vc-teahouse](https://github.com/vc-teahouse/Baseband-guard)**: Baseband Guard (BBG) protection.
* **[tiann](https://github.com/tiann/KernelSU)**: The original KernelSU creator.
* **[coolzyd9107](https://github.com/coolzyd9107)** & **[zzh20188](https://github.com/zzh20188)**: Original GKI builder workflow foundations.

---

<div align="center">

⭐ **If you find this project useful, please star the repository!**

</div>
