# HP LaserJet M1005 macOS XQX 驱动

这是一个给 **HP LaserJet M1005 MFP** 使用的 macOS/CUPS 实验打印驱动。

已在 Apple Silicon Mac + USB 连接的 HP LaserJet M1005 上测试可打印。目标是解决这台老打印机在新版 macOS 上没有官方可用驱动的问题。

> 说明：这是社区/个人整理的非官方驱动，不是 HP 官方驱动。当前重点解决“能打印”的问题，不包含扫描功能。

## 适合谁使用

如果你遇到下面这类情况，可以尝试本项目：

- 使用的是 HP LaserJet M1005 MFP。
- Mac 上找不到可用的官方 M1005 驱动。
- 打印机通过 USB 连接 Mac。
- 主要打印 A4 黑白文档。
- 系统是 Apple Silicon Mac，例如 M1/M2/M3/M4 系列。

如果你需要扫描、网络打印、双面打印或其它纸张尺寸，这个项目目前不一定适合。

## 工作原理

传统 Linux 驱动常见流程是 PDF/PostScript 经过 Ghostscript 转成 PBM，再由 `foo2xqx` 转成打印机能识别的 XQX/PJL 数据。但在新版 macOS 里，CUPS 的 filter/backend 沙盒会限制 Ghostscript、Homebrew 动态库、管道输出和临时文件访问，容易出现“队列完成但不出纸”“Filter 失败”“打印机使用中”等问题。

本项目采用更适合 macOS 的流程：

```text
任意 App
-> CUPS
-> macOS 自带 cgpdftoraster
-> rastertoxqx-filter
-> m1005-raster2pbm
-> foo2xqx
-> m1005usb root backend
-> macOS USB backend
-> HP LaserJet M1005
```

核心思路：

- 用 macOS 原生 `cgpdftoraster` 完成 PDF/文档渲染。
- 自写 `m1005-raster2pbm`，把 CUPS raster 转成 PBM 位图。
- 使用 `foo2xqx` 把 PBM 打包成 M1005 支持的 XQX/PJL 数据。
- 用 `m1005usb` CUPS backend 以 root 身份接收最终数据并交给 USB backend 发送。

## 支持情况

当前支持：

- HP LaserJet M1005 MFP
- USB 连接
- A4
- 黑白打印
- 600 DPI
- Apple Silicon macOS（arm64）

当前不保证：

- Intel Mac
- 扫描功能
- 网络打印
- Letter/Legal 等其他纸张尺寸
- 双面打印

## 依赖环境

正常情况下，不需要额外安装下面这些工具：

- 不需要 Homebrew
- 不需要 Ghostscript
- 不需要 Node.js
- 不需要 Python
- 不需要手动安装 Xcode

需要具备的是：

- Apple Silicon Mac（M1/M2/M3/M4 等 arm64 机型）
- macOS 自带的 CUPS 打印系统
- 可以使用 `sudo` 的管理员账号
- USB 连接并已开机的 HP LaserJet M1005 MFP

项目已经附带 Apple Silicon 预编译程序：

```text
bin/darwin-arm64/m1005-raster2pbm
bin/darwin-arm64/foo2xqx
```

安装脚本会先检查系统里有没有 `clang`。如果有，会优先尝试从源码编译；如果没有，Apple Silicon Mac 会直接使用上面这两个内置二进制文件。

因此，对普通用户来说，通常只需要解压项目、连接打印机，然后运行：

```sh
./install.sh
```

## 安装

### 1. 下载项目

可以从 GitHub 下载 ZIP，或者使用 Git 克隆：

```sh
git clone https://github.com/pandastone9-eng/HP-M1005-macOS-XQX-Driver.git
cd HP-M1005-macOS-XQX-Driver
```

如果是下载 ZIP，请先解压，然后在终端进入解压后的目录。

### 2. 连接打印机

先把打印机接到 Mac，打开电源，并确保 USB 已连接。

可以用下面命令检查系统是否能看到打印机：

```sh
lpinfo -v | grep -i M1005
```

如果没有输出，通常说明 USB 没连接好、打印机没开机，或者 macOS 还没有识别到设备。

### 3. 运行安装脚本

在项目目录里运行：

```sh
./install.sh
```

脚本需要写入系统打印机目录，因此会自动请求 `sudo` 管理员权限。

安装脚本会自动：

- 查找 USB 上的 HP LaserJet M1005
- 编译或安装 `m1005-raster2pbm`
- 编译或安装 `foo2xqx`
- 安装 CUPS filter
- 安装 CUPS backend
- 安装 PPD
- 创建打印队列 `HP_LaserJet_M1005_XQX`

安装完成后，在 macOS 打印窗口选择这个打印机：

```text
HP LaserJet M1005 MFP XQX Direct (USB)
```

## 测试打印

可以先用 PDF 测试：

```sh
lp -d HP_LaserJet_M1005_XQX /path/to/test.pdf
```

也可以直接在预览、WPS、Word 等应用里选择上面的打印机队列打印。

查看当前打印队列：

```sh
lpstat -p HP_LaserJet_M1005_XQX -l
```

## 卸载

如果不想继续使用，可以在项目目录中运行：

```sh
cd HP-M1005-macOS-XQX-Driver
./uninstall.sh
```

卸载脚本会删除：

- 打印队列 `HP_LaserJet_M1005_XQX`
- CUPS backend
- CUPS filter
- PPD 文件
- 安装到 `/Library/Printers/hp-m1005-xqx` 下的辅助程序

## 日志

如果打印失败，可以查看：

```sh
sudo cat /private/var/spool/cups/tmp/rastertoxqx-filter.log
sudo cat /private/var/spool/cups/tmp/m1005usb-backend.log
```

CUPS 系统日志：

```sh
sudo tail -100 /private/var/log/cups/error_log
```

## 常见问题

### 安装时提示找不到打印机

确认以下几点：

- 打印机已开机。
- USB 线已连接到 Mac。
- 运行 `lpinfo -v | grep -i M1005` 能看到设备。

如果系统能看到设备，但脚本没有自动识别，可以手动传入真实 USB URI：

```sh
sudo REAL_URI='usb://Hewlett-Packard/HP%20LaserJet%20M1005?serial=...' ./install.sh
```

其中 `REAL_URI` 可以从 `lpinfo -v` 的输出中复制。

### 打印队列完成了，但机器不出纸

可以先看日志：

```sh
sudo cat /private/var/spool/cups/tmp/rastertoxqx-filter.log
sudo cat /private/var/spool/cups/tmp/m1005usb-backend.log
```

然后尝试：

```sh
cupsenable HP_LaserJet_M1005_XQX
cupsaccept HP_LaserJet_M1005_XQX
```

必要时重新插拔 USB、重启打印机，再重新安装一次。

### 提示权限或安全限制

安装脚本需要管理员权限，因为它要写入 CUPS 系统目录。运行 `./install.sh` 时会自动通过 `sudo` 重新执行。

如果 macOS 阻止执行脚本，可以先确认脚本权限：

```sh
chmod +x install.sh uninstall.sh
```

### Intel Mac 可以用吗？

目前没有保证。项目里附带的预编译二进制是 Apple Silicon `arm64` 版本。如果 Intel Mac 上安装了 Xcode Command Line Tools，脚本会尝试从源码编译，但还没有做充分测试。

### 支持扫描吗？

不支持。这个项目只处理打印。

### 支持彩色、双面、网络打印吗？

不支持。HP LaserJet M1005 本身是黑白激光设备；本项目当前只面向 USB、A4、黑白、600 DPI 打印。

## 文件结构

```text
install.sh
uninstall.sh
README.md
README.zh-CN.md
src/
  m1005-raster2pbm.c
  foo2xqx/
bin/
  darwin-arm64/
scripts/
  foo2zjs-pstops
```

## 项目安装到哪里

安装后主要文件会放在：

```text
/Library/Printers/hp-m1005-xqx
/usr/libexec/cups/backend/m1005usb
/Library/Printers/PPDs/Contents/Resources/HP-LaserJet_M1005_MFP-XQX-Raster.ppd
```

卸载脚本会清理这些文件。

## 许可证

`foo2xqx` 相关源码来自开源 foo2zjs 项目，遵循 GPL，许可证见：

```text
src/foo2xqx/COPYING
```

本项目新增的 macOS CUPS glue/filter/backend 脚本和 `m1005-raster2pbm.c` 建议同样按 GPL 发布，方便和 `foo2xqx` 一起分发。

## 免责声明

这是实验性驱动，使用前请自行判断风险。安装脚本会修改本机 CUPS 打印系统配置；如果安装后不符合预期，可以运行 `./uninstall.sh` 卸载。
