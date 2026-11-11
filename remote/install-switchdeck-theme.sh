#!/usr/bin/env bash
set -euo pipefail
# 1) 解压主题到 themes 目录
mkdir -p /boot/efi/EFI/clover/themes
tar -xf /tmp/switchdeck.tar -C /tmp/ 2>/dev/null || true
# 清理 macOS 的 ._ 文件
find /tmp/SwitchDeck -name '._*' -delete 2>/dev/null || true
# 拷进 themes(用 SwitchDeck 作为主题名)
rm -rf /boot/efi/EFI/clover/themes/SwitchDeck
cp -r /tmp/SwitchDeck /boot/efi/EFI/clover/themes/SwitchDeck
echo "theme_installed"
ls /boot/efi/EFI/clover/themes/
# 2) 重写 config.plist:SwitchDeck 主题 + 只列 Windows/Bazzite 两项
cat > /boot/efi/EFI/clover/config.plist <<'PLIST'
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
    <key>Scan</key><false/>
    <key>ScreenResolution</key><string>1920x1080</string>
    <key>Theme</key><string>SwitchDeck</string>
    <key>Mouse</key><dict><key>Enabled</key><true/><key>Speed</key><integer>5</integer></dict>
    <key>PlayAsync</key><true/>
    <key>TextMode</key><false/>
    <key>Custom</key>
    <dict>
      <key>Entries</key>
      <array>
        <dict>
          <key>Title</key><string>Windows 11</string>
          <key>FullTitle</key><string>Windows 11</string>
          <key>Type</key><string>Windows</string>
          <key>Path</key><string>\EFI\Microsoft\Boot\bootmgfw.efi</string>
          <key>Image</key><string>os_win</string>
          <key>VolumeType</key><string>Internal</string>
        </dict>
        <dict>
          <key>Title</key><string>Bazzite</string>
          <key>FullTitle</key><string>Bazzite (SteamOS 风格)</string>
          <key>Type</key><string>Linux</string>
          <key>Path</key><string>\EFI\fedora\shimx64.efi</string>
          <key>Image</key><string>os_bazzite</string>
          <key>VolumeType</key><string>Internal</string>
        </dict>
      </array>
    </dict>
  </dict>
</dict>
</plist>
PLIST
echo "config_updated"
sync
echo "===VERIFY==="
ls -la /boot/efi/EFI/clover/themes/SwitchDeck/theme.plist
echo "--- config 主题行 ---"
grep -i 'Theme\|SwitchDeck' /boot/efi/EFI/clover/config.plist
echo "ALL_DONE"
