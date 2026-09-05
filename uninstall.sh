#!/bin/sh
set -eu

QUEUE="${QUEUE:-HP_LaserJet_M1005_XQX}"
ROOT="/Library/Printers/hp-m1005-xqx"
BACKEND="/usr/libexec/cups/backend/m1005usb"
PPD="/Library/Printers/PPDs/Contents/Resources/HP-LaserJet_M1005_MFP-XQX-Raster.ppd"

if [ "$(id -u)" -ne 0 ]; then
  exec sudo /bin/sh "$0" "$@"
fi

lpadmin -x "$QUEUE" 2>/dev/null || true
rm -f "$BACKEND" "$PPD"
rm -f "$ROOT/filter/rastertoxqx-filter"
rm -f "$ROOT/bin/m1005-raster2pbm" "$ROOT/bin/foo2xqx" "$ROOT/bin/foo2zjs-pstops"
rm -f /private/var/spool/cups/tmp/m1005usb-backend.log /private/var/spool/cups/tmp/rastertoxqx-filter.log 2>/dev/null || true
launchctl kickstart -k system/org.cups.cupsd 2>/dev/null || true

echo "Removed $QUEUE and installed HP M1005 XQX files."
