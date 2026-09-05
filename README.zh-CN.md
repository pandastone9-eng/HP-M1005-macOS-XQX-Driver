# HP LaserJet M1005 macOS XQX 驱动

这是一个给 HP LaserJet M1005 MFP 使用的 macOS/CUPS 实验驱动。

已在 Apple Silicon Mac + USB 连接的 HP LaserJet M1005 上测试可打印。目标是解决这台老打印机在新版 macOS 上没有官方可用驱动的问题。

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
- Apple Silicon macOS

当前不保证：

- Intel Mac
- 扫描功能
- 网络打印
- Letter/Legal 等其他纸张尺寸
- 双面打印

## 安装

先把打印机接到 Mac，开机，确保 USB 已连接。

然后在终端运行：

```sh
cd HP-M1005-macOS-XQX-Driver
./install.sh
```

安装脚本会自动：

- 查找 USB 上的 HP LaserJet M1005
- 编译或安装 `m1005-raster2pbm`
- 编译或安装 `foo2xqx`
- 安装 CUPS filter
- 安装 CUPS backend
- 安装 PPD
- 创建打印队列 `HP_LaserJet_M1005_XQX`

安装完成后，在 macOS 打印窗口选择：

```text
HP LaserJet M1005 MFP XQX Direct (USB)
```

## 测试打印

```sh
lp -d HP_LaserJet_M1005_XQX /path/to/test.pdf
```

也可以直接在预览、WPS、Word 等应用里选择上面的打印机队列打印。

## 卸载

```sh
cd HP-M1005-macOS-XQX-Driver
./uninstall.sh
```

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

## 许可证

`foo2xqx` 相关源码来自开源 foo2zjs 项目，遵循 GPL，许可证见：

```text
src/foo2xqx/COPYING
```

本项目新增的 macOS CUPS glue/filter/backend 脚本和 `m1005-raster2pbm.c` 建议同样按 GPL 发布，方便和 `foo2xqx` 一起分发。
