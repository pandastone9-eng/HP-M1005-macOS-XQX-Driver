#!/bin/sh
set -eu

QUEUE="${QUEUE:-HP_LaserJet_M1005_XQX}"
ROOT="/Library/Printers/hp-m1005-xqx"
BACKEND="/usr/libexec/cups/backend/m1005usb"
FILTER="$ROOT/filter/rastertoxqx-filter"
PPD="/Library/Printers/PPDs/Contents/Resources/HP-LaserJet_M1005_MFP-XQX-Raster.ppd"

if [ "$(id -u)" -ne 0 ]; then
  exec sudo /bin/sh "$0" "$@"
fi

cd "$(dirname "$0")"

REAL_URI="${REAL_URI:-}"
if [ -z "$REAL_URI" ]; then
  REAL_URI="$(lpinfo -v 2>/dev/null | awk '/usb:\/\/Hewlett-Packard\/HP%20LaserJet%20M1005/ { print $2; exit }')"
fi

if [ -z "$REAL_URI" ]; then
  echo "ERROR: HP LaserJet M1005 USB printer was not found."
  echo "Connect and power on the printer, then run this installer again."
  echo "You can also pass REAL_URI manually, for example:"
  echo "  sudo REAL_URI='usb://Hewlett-Packard/HP%20LaserJet%20M1005?serial=...' ./install.sh"
  exit 1
fi

ARCH="$(uname -m)"
BUILD_DIR="/tmp/hp-m1005-xqx-build.$$"
mkdir -p "$BUILD_DIR" "$ROOT/bin" "$ROOT/filter" "$(dirname "$PPD")"
trap 'rm -rf "$BUILD_DIR"' EXIT INT HUP TERM

if command -v clang >/dev/null 2>&1; then
  clang src/m1005-raster2pbm.c -lcups -o "$BUILD_DIR/m1005-raster2pbm" || true
  clang src/foo2xqx/foo2xqx.c src/foo2xqx/jbig.c src/foo2xqx/jbig_ar.c -o "$BUILD_DIR/foo2xqx" || true
fi

if [ -x "$BUILD_DIR/m1005-raster2pbm" ]; then
  install -o root -g wheel -m 555 "$BUILD_DIR/m1005-raster2pbm" "$ROOT/bin/m1005-raster2pbm"
elif [ "$ARCH" = "arm64" ] && [ -x bin/darwin-arm64/m1005-raster2pbm ]; then
  install -o root -g wheel -m 555 bin/darwin-arm64/m1005-raster2pbm "$ROOT/bin/m1005-raster2pbm"
else
  echo "ERROR: Could not build m1005-raster2pbm, and no compatible binary is bundled."
  exit 1
fi

if [ -x "$BUILD_DIR/foo2xqx" ]; then
  install -o root -g wheel -m 555 "$BUILD_DIR/foo2xqx" "$ROOT/bin/foo2xqx"
elif [ "$ARCH" = "arm64" ] && [ -x bin/darwin-arm64/foo2xqx ]; then
  install -o root -g wheel -m 555 bin/darwin-arm64/foo2xqx "$ROOT/bin/foo2xqx"
else
  echo "ERROR: Could not build foo2xqx, and no compatible binary is bundled."
  exit 1
fi

install -o root -g wheel -m 555 scripts/foo2zjs-pstops "$ROOT/bin/foo2zjs-pstops"

cat > "$FILTER" <<'FILTER'
#!/bin/sh
set -eu

ROOT="/Library/Printers/hp-m1005-xqx"
RASTER2PBM="$ROOT/bin/m1005-raster2pbm"
FOO2XQX="$ROOT/bin/foo2xqx"
LOG="/private/var/spool/cups/tmp/rastertoxqx-filter.log"

log() {
  printf "%s %s\n" "$(date +%Y-%m-%dT%H:%M:%S)" "$*" >> "$LOG" 2>/dev/null || true
}

JOB_ID="${1:-0}"
USER_NAME="${2:-unknown}"
TITLE="${3:-HP M1005 job}"
COPIES="${4:-1}"
OPTIONS="${5:-}"
INPUT_FILE="${6:-}"

TMPBASE="$(mktemp "${TMPDIR:-/private/var/spool/cups/tmp}/rastertoxqx.XXXXXX")"
RASTER="$TMPBASE.ras"
PBM="$TMPBASE.pbm"
ERR="$TMPBASE.err"
cleanup() {
  rm -f "$TMPBASE" "$RASTER" "$PBM" "$ERR"
}
trap cleanup EXIT INT HUP TERM

if [ -n "$INPUT_FILE" ]; then
  cp "$INPUT_FILE" "$RASTER"
else
  cat > "$RASTER"
fi

log "job=$JOB_ID title=$TITLE raster_size=$(wc -c < "$RASTER" 2>/dev/null || echo 0) options=$OPTIONS"
"$RASTER2PBM" "$RASTER" > "$PBM" 2>"$ERR"
[ -s "$ERR" ] && log "job=$JOB_ID raster2pbm=$(tr '\n' ' ' < "$ERR" | cut -c 1-1000)"
DIM="$(awk 'NR==2 { print $1 "x" $2; exit }' "$PBM")"
log "job=$JOB_ID pbm_size=$(wc -c < "$PBM" 2>/dev/null || echo 0) dim=$DIM"

"$FOO2XQX" -r600x600 -g"$DIM" -p9 -m1 -n"$COPIES" -d1 -s7 \
  -u 88x84 -l 88x84 -L 3 -T3 -J "$TITLE" -U "$USER_NAME" < "$PBM"
FILTER
chmod 555 "$FILTER"
chown root:wheel "$FILTER"

cat > "$BACKEND" <<BACKEND
#!/bin/sh
set -eu

USB_BACKEND="/usr/libexec/cups/backend/usb"
LOG="/private/var/spool/cups/tmp/m1005usb-backend.log"
REAL_URI="$REAL_URI"

log() {
  printf "%s %s\\n" "\$(date +%Y-%m-%dT%H:%M:%S)" "\$*" >> "\$LOG" 2>/dev/null || true
}

if [ "\$#" -eq 0 ]; then
  printf 'direct m1005usb://HP/LaserJet_M1005 "HP LaserJet M1005 MFP XQX Direct" "HP LaserJet M1005 MFP XQX Direct" "MFG:Hewlett-Packard;MDL:HP LaserJet M1005;CMD:ACL;CLS:PRINTER;DES:HP LaserJet M1005;" "USB"\\n'
  exit 0
fi

JOB_ID="\${1:-0}"
USER_NAME="\${2:-unknown}"
TITLE="\${3:-HP M1005 job}"
COPIES="\${4:-1}"
OPTIONS="\${5:-}"
INPUT_FILE="\${6:-}"

if [ -z "\$INPUT_FILE" ]; then
  TMPBASE="\$(mktemp "\${TMPDIR:-/private/var/spool/cups/tmp}/m1005usb.XXXXXX")"
  trap 'rm -f "\$TMPBASE"' EXIT INT HUP TERM
  cat > "\$TMPBASE"
  INPUT_FILE="\$TMPBASE"
fi

MAGIC_HEX="\$(LC_ALL=C od -An -tx1 -N3 "\$INPUT_FILE" 2>/dev/null | tr -d ' \\n')"
SIZE="\$(wc -c < "\$INPUT_FILE" 2>/dev/null || echo 0)"
log "job=\$JOB_ID title=\$TITLE size=\$SIZE hex=\$MAGIC_HEX options=\$OPTIONS"

if [ "\$MAGIC_HEX" != "1b252d" ]; then
  log "job=\$JOB_ID unsupported_input=not_xqx"
  exit 1
fi

DEVICE_URI="\$REAL_URI" PRINTER="\${PRINTER:-HP_LaserJet_M1005_XQX}" \
  "\$USB_BACKEND" "\$JOB_ID" "\$USER_NAME" "\$TITLE" "\$COPIES" "\$OPTIONS" "\$INPUT_FILE"
BACKEND
chmod 500 "$BACKEND"
chown root:wheel "$BACKEND"

cat > "$PPD" <<'PPD'
*PPD-Adobe: "4.3"
*FormatVersion: "4.3"
*FileVersion: "1.0"
*LanguageVersion: English
*LanguageEncoding: ISOLatin1
*PCFileName: "HPM1005R.PPD"
*Manufacturer: "HP"
*Product: "(HP LaserJet M1005 MFP)"
*ModelName: "HP LaserJet M1005 MFP XQX Raster"
*NickName: "HP LaserJet M1005 MFP XQX Raster"
*ShortNickName: "HP M1005 XQX"
*cupsVersion: 2.3
*cupsManualCopies: True
*cupsFilter: "application/vnd.cups-raster 0 /Library/Printers/hp-m1005-xqx/filter/rastertoxqx-filter"
*1284DeviceID: "MFG:Hewlett-Packard;MDL:HP LaserJet M1005;CMD:ACL;CLS:PRINTER;DES:HP LaserJet M1005;"
*ColorDevice: False
*DefaultColorSpace: Gray
*FileSystem: False
*LanguageLevel: "2"
*TTRasterizer: Type42
*DefaultResolution: 600dpi
*OpenUI *Resolution/Resolution: PickOne
*DefaultResolution: 600dpi
*Resolution 600dpi/600 DPI: "<</HWResolution[600 600]>>setpagedevice"
*CloseUI: *Resolution
*OpenUI *PageSize/Page Size: PickOne
*DefaultPageSize: A4
*PageSize A4/A4: "<</PageSize[595 842]/ImagingBBox null>>setpagedevice"
*CloseUI: *PageSize
*OpenUI *PageRegion/Page Region: PickOne
*DefaultPageRegion: A4
*PageRegion A4/A4: "<</PageSize[595 842]/ImagingBBox null>>setpagedevice"
*CloseUI: *PageRegion
*DefaultImageableArea: A4
*ImageableArea A4/A4: "0 0 595 842"
*DefaultPaperDimension: A4
*PaperDimension A4/A4: "595 842"
*OpenUI *InputSlot/Media Source: PickOne
*DefaultInputSlot: Auto
*InputSlot Auto/Auto: ""
*InputSlot Manual/Manual Feed: "<</ManualFeed true>>setpagedevice"
*CloseUI: *InputSlot
*OpenUI *Duplex/Two-Sided: PickOne
*DefaultDuplex: None
*Duplex None/Off: "<</Duplex false>>setpagedevice"
*CloseUI: *Duplex
*DefaultFont: Courier
*Font Courier: Standard "(001.007S)" Standard ROM
*Font Helvetica: Standard "(001.007S)" Standard ROM
*Font Times-Roman: Standard "(001.007S)" Standard ROM
*Font Symbol: Special "(001.007S)" Special ROM
*Font ZapfDingbats: Special "(001.005S)" Special ROM
*% End
PPD
chmod 644 "$PPD"
chown root:admin "$PPD" 2>/dev/null || chown root:wheel "$PPD"

lpadmin -x "$QUEUE" 2>/dev/null || true
lpadmin -p "$QUEUE" -E -v "m1005usb://HP/LaserJet_M1005" -P "$PPD" \
  -D "HP LaserJet M1005 MFP XQX Direct" -L "USB"
lpadmin -p "$QUEUE" -o PageSize=A4 -o Resolution=600dpi -o printer-error-policy=retry-job
cupsaccept "$QUEUE"
cupsenable "$QUEUE"
launchctl kickstart -k system/org.cups.cupsd 2>/dev/null || true

echo "Installed $QUEUE"
echo "Device: m1005usb://HP/LaserJet_M1005 -> $REAL_URI"
echo "Try: lp -d $QUEUE /path/to/file.pdf"
