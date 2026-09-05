# HP LaserJet M1005 macOS XQX Driver

Experimental CUPS driver for HP LaserJet M1005 MFP on macOS.

This package was tested on macOS with an HP LaserJet M1005 connected over USB. It avoids the broken legacy Ghostscript-in-CUPS path by using macOS' native rasterizer, then converting the raster stream to the XQX/PJL format accepted by the printer.

## Pipeline

```text
Any app
-> CUPS
-> cgpdftoraster
-> rastertoxqx-filter
-> m1005-raster2pbm
-> foo2xqx
-> m1005usb root backend
-> macOS USB backend
-> HP LaserJet M1005
```

## Install

Connect and power on the printer first.

```sh
cd hp-laserjet-m1005-macos-xqx
./install.sh
```

The installer creates this queue:

```text
HP_LaserJet_M1005_XQX
```

In macOS print dialogs, choose:

```text
HP LaserJet M1005 MFP XQX Direct (USB)
```

## Test

```sh
lp -d HP_LaserJet_M1005_XQX /path/to/test.pdf
```

Useful logs:

```sh
sudo cat /private/var/spool/cups/tmp/rastertoxqx-filter.log
sudo cat /private/var/spool/cups/tmp/m1005usb-backend.log
```

## Uninstall

```sh
./uninstall.sh
```

## Notes

- The bundled binaries are for Apple Silicon (`arm64`).
- If Xcode Command Line Tools are installed, the installer will try to build the helper binaries from source first.
- The `foo2xqx` encoder source is derived from the open-source foo2zjs project and is distributed under the GPL; see `src/foo2xqx/COPYING`.
- This package currently targets A4, monochrome, 600 DPI printing.
