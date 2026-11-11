#!/usr/bin/env bash
# 用法:把 U 盘项目拷到家目录后,修改下面 SRC 为你的实际路径,再 sudo bash 本脚本。
#   SRC 必须是 Handheld-Clover-dualboot-main 项目的绝对路径(不能含 $HOME,
#   因为 sudo 下 $HOME 会变成 /root)。
set -euo pipefail
SRC="/home/<你的用户名>/Handheld-Clover-dualboot-main"
CLOVER="$SRC/custom/efi/custom_clover_5157.efi"
XPAD="$SRC/custom/UsbXbox360Dxe.efi"
INI="$SRC/custom/xbox360-clover.ini"
THEME="$SRC/custom/themes/Eclipse"
for f in "$CLOVER" "$XPAD" "$INI"; do
  [ -s "$f" ] || { echo "MISSING: $f"; exit 1; }
done
echo "all source files found"
DEST=/boot/efi/EFI/clover
if [ -d "$DEST" ]; then mv "$DEST" "$DEST.bak.$(date +%s)"; echo "backed_up_old"; fi
mkdir -p "$DEST"
cp "$CLOVER" "$DEST/cloverx64.efi"; echo "wrote_clover"
if [ -d "$THEME" ]; then mkdir -p "$DEST/themes"; cp -r "$THEME" "$DEST/themes/"; echo "wrote_theme"; fi
mkdir -p "$DEST/drivers/uefi"
cp "$XPAD" "$DEST/drivers/uefi/UsbXbox360Dxe.efi"; echo "wrote_xpad"
mkdir -p /boot/efi/EFI/Xbox360
cp "$INI" /boot/efi/EFI/Xbox360/config.ini; echo "wrote_ini"
cat > "$DEST/config.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Boot</key>
  <dict>
    <key>Timeout</key><integer>0</integer>
    <key>DefaultLoader</key><string>\EFI\fedora\shimx64.efi</string>
    <key>DefaultVolume</key><string>esp</string>
  </dict>
  <key>GUI</key>
  <dict>
    <key>Scan</key><true/>
    <key>ScreenResolution</key><string>1920x1080</string>
    <key>Theme</key><string>Eclipse</string>
    <key>EmbeddedThemeType</key><string>Daytime</string>
    <key>Mouse</key><dict><key>Enabled</key><true/><key>Speed</key><integer>5</integer></dict>
    <key>PlayAsync</key><true/>
  </dict>
</dict>
</plist>
PLIST
echo "wrote_config"
sync
echo "===VERIFY==="
ls -la "$DEST/"
echo "--- drivers ---"
ls -la "$DEST/drivers/uefi/"
echo "--- Xbox360 ---"
ls -la /boot/efi/EFI/Xbox360/
echo "FILES_DONE"
