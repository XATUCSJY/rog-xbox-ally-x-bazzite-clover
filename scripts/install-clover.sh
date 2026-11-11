#!/usr/bin/env bash
# ============================================================================
# install-clover.sh -- 手动安装 Clover + Xbox 手柄驱动到 Bazzite 的 ESP
#
# 用途:绕过 Handheld-Clover-dualboot 原项目的"设备白名单检测"(它没认出
#       ROG Xbox Ally X),直接复用该项目里的 Clover 本体 + 手柄 UEFI 驱动
#       + 主题,手动装进 ESP 并注册启动项。
#
# 用法(在 Bazzite 里,把 U 盘项目 + 本目录都准备好):
#   1) 把 U 盘的 "Handheld-Clover-dualboot-main" 项目拷到 Bazzite,例如
#        ~/Handheld-Clover-dualboot-main
#   2) 把本目录(含本脚本)拷到 Bazzite,例如 ~/ally-switcher
#   3) 设变量后运行:
#        SRC=~/Handheld-Clover-dualboot-main bash install-clover.sh
#      (SRC 指向 U 盘项目目录;若不在家目录,给绝对路径)
#
# 安全:只在 ESP 新增 /EFI/clover/、/EFI/Xbox360/ 和一个 NVRAM 启动项,
#       不修改 Windows BCD、不修改 Bazzite 的 GRUB/shim,随时可回退。
# ============================================================================
set -euo pipefail

# ---- 0) 参数与前置检查 ------------------------------------------------------
SRC="${SRC:-$HOME/Handheld-Clover-dualboot-main}"
[ -d "$SRC" ] || { echo "找不到 U 盘项目目录: $SRC"; echo "用 SRC=路径 bash $0 指定。"; exit 1; }

# 关键资源(来自 U 盘项目)
CLOVER_SRC="$SRC/custom/efi/custom_clover_5157.efi"   # Clover 本体(1.5MB)
XPAD_SRC="$SRC/custom/UsbXbox360Dxe.efi"              # Xbox 手柄 UEFI 驱动
XPAD_INI_SRC="$SRC/custom/xbox360-clover.ini"         # 手柄按键映射
THEME_SRC="$SRC/custom/themes"                        # 主题
CONFIG_SRC="$SRC/custom/config.plist"                 # 模板 config(仅参考)

for f in "$CLOVER_SRC" "$XPAD_SRC" "$XPAD_INI_SRC"; do
  [ -s "$f" ] || { echo "缺少关键文件: $f"; exit 1; }
done
[ -d "$THEME_SRC" ] || { echo "缺少主题目录: $THEME_SRC"; exit 1; }

if [ "$(id -u)" != "0" ]; then
  echo "请用 root 运行: sudo SRC=$SRC bash $0"
  exit 1
fi
for t in efibootmgr mount umount partx blkid lsblk; do
  command -v "$t" >/dev/null 2>&1 || { echo "缺少工具: $t (sudo dnf install $t)"; exit 1; }
done

WORK="$(mktemp -d)"
MNT="$WORK/esp"
trap 'umount "$MNT" 2>/dev/null; rm -rf "$WORK"' EXIT

# ---- 1) 定位并挂载 ESP ------------------------------------------------------
# 策略(按可靠性排序):
#   A) /boot/efi 已挂载(Bazzite 常态)→ 直接用,从挂载信息反推磁盘/分区号
#   B) 否则按 GPT ESP 分区标志探测设备并自挂
#   C) 兜底:找任意已挂载的 vfat
echo "==> 定位 ESP ..."
ESP=""
SELF_MOUNTED=0
ESP_DEV=""
DISK=""
PARTNUM=""

# A) 已挂载的 /boot/efi
if mountpoint -q /boot/efi 2>/dev/null; then
  ESP="/boot/efi"
  ESP_DEV="$(awk '$2=="/boot/efi"{print $1}' /proc/mounts | head -1)"
  echo "    使用已挂载的 /boot/efi (设备: ${ESP_DEV:-未知})"
else
  # B) 按 GPT 分区标志探测
  for d in /dev/nvme* /dev/sd*; do
    [ -b "$d" ] || continue
    for p in "$d"p*; do
      [ -b "$p" ] || continue
      pt=$(blkid -s PARTTYPE -o value "$p" 2>/dev/null || true)
      fs=$(blkid -s TYPE -o value "$p" 2>/dev/null || true)
      if [ "$fs" = "vfat" ] && { [ "$pt" = "c12a7328-f81f-11d2-ba4b-00a0c93ec93b" ] || [ "$pt" = "ebd0a0a2-b9e5-4433-87c0-68b6b72699c7" ]; }; then
        ESP_DEV="$p"; break 2
      fi
    done
  done
  if [ -n "$ESP_DEV" ]; then
    mkdir -p "$MNT"
    mount -o nosuid,nodev,rw "$ESP_DEV" "$MNT" || { echo "挂载 $ESP_DEV 失败"; exit 1; }
    ESP="$MNT"; SELF_MOUNTED=1
    echo "    已挂载 $ESP_DEV -> $MNT"
  else
    # C) 兜底:任意已挂载 vfat
    ESP_DEV="$(findmnt -n -o SOURCE -T /boot 2>/dev/null | head -1)"
    if [ -n "$ESP_DEV" ]; then
      mkdir -p "$MNT"; mount -o nosuid,nodev,rw "$ESP_DEV" "$MNT"
      ESP="$MNT"; SELF_MOUNTED=1
      echo "    兜底挂载 $ESP_DEV"
    else
      echo "  找不到 ESP 分区。请手动指定: sudo ESP_DEV=/dev/<你的ESP分区,如 nvme0n1p1> SRC=... bash $0"
      exit 1
    fi
  fi
fi

# 反推磁盘与分区号(注册 NVRAM 用)
if [ -n "$ESP_DEV" ]; then
  PARTNUM="$(partx -n -o NR "$ESP_DEV" 2>/dev/null | tr -d ' ')"
  DISK="$(lsblk -ndo PKNAME "$ESP_DEV" 2>/dev/null || true)"
else
  # ESP_DEV 未知时,从 /boot/efi 挂载点反查
  ESP_DEV="$(findmnt -n -o SOURCE -T /boot/efi 2>/dev/null | head -1)"
  PARTNUM="$(partx -n -o NR "$ESP_DEV" 2>/dev/null | tr -d ' ')"
  DISK="$(lsblk -ndo PKNAME "$ESP_DEV" 2>/dev/null || true)"
fi
[ -n "$PARTNUM" ] || PARTNUM=1
echo "    ESP 挂载点: $ESP   设备: ${ESP_DEV:-?}   磁盘: ${DISK:-?}   分区号: $PARTNUM"

# ---- 2) 写入 Clover ---------------------------------------------------------
DEST="$ESP/EFI/clover"
if [ -d "$DEST" ]; then
  BAK="$ESP/EFI/clover.bak.$(date +%s)"
  echo "    发现旧 Clover,备份到 /EFI/clover.bak.<ts>"
  mv "$DEST" "$BAK"
fi
mkdir -p "$DEST"

# Clover 本体(放成 cloverx64.efi)
cp "$CLOVER_SRC" "$DEST/cloverx64.efi"
echo "    已写入 /EFI/clover/cloverx64.efi"

# 主题(只装 Eclipse,config 里指定的)
if [ -d "$THEME_SRC/Eclipse" ]; then
  mkdir -p "$DEST/themes"
  cp -R "$THEME_SRC/Eclipse" "$DEST/themes/"
  echo "    已安装主题 Eclipse"
fi

# 手柄驱动 + 映射
mkdir -p "$DEST/drivers/uefi"
cp "$XPAD_SRC" "$DEST/drivers/uefi/UsbXbox360Dxe.efi"
mkdir -p "$ESP/EFI/Xbox360"
cp "$XPAD_INI_SRC" "$ESP/EFI/Xbox360/config.ini"
echo "    已安装 Xbox 手柄驱动 + 按键映射"

# ---- 3) 生成针对 Ally X 的 config.plist ------------------------------------
# 关键点:
#  - ScreenResolution = 1920x1080 (Ally X 原生)
#  - Scan = true  (自动扫描 ESP,发现 Windows/Bazzite 真实引导器)
#  - 默认进 Bazzite(shimx64.efi);Windows 由 Scan 自动列出
#  不硬编码 Custom>Entries 的假路径,交给 Scan 发现。
CFG="$DEST/config.plist"
cat > "$CFG" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Boot</key>
	<dict>
		<key>Timeout</key>
		<integer>0</integer>
		<key>DefaultLoader</key>
		<string>\EFI\fedora\shimx64.efi</string>
		<key>DefaultVolume</key>
		<string>esp</string>
	</dict>
	<key>GUI</key>
	<dict>
		<key>Scan</key>
		<true/>
		<key>ScreenResolution</key>
		<string>1920x1080</string>
		<key>Theme</key>
		<string>Eclipse</string>
		<key>EmbeddedThemeType</key>
		<string>Daytime</string>
		<key>Mouse</key>
		<dict>
			<key>Enabled</key>
			<true/>
			<key>Speed</key>
			<integer>5</integer>
		</dict>
		<key>PlayAsync</key>
		<true/>
	</dict>
</dict>
</plist>
PLIST
echo "    已生成 config.plist (1920x1080, 自动扫描, 默认 Bazzite)"

sync
[ "$SELF_MOUNTED" = "1" ] && umount "$MNT"
echo "==> 文件写入完成。"

# ---- 4) 注册 NVRAM 启动项 ---------------------------------------------------
echo "==> 注册 NVRAM 启动项 ..."
if [ -n "$DISK" ]; then
  efibootmgr -c -d "$DISK" -p "$PARTNUM" \
    -L "Clover - Ally Switcher" \
    -l "\EFI\clover\cloverx64.efi" 2>&1 \
  && echo "    已注册 'Clover - Ally Switcher'。" \
  || echo "    自动注册失败,稍后手动添加(见下)。"
else
  echo "    无法确定 ESP 所在磁盘,跳过自动注册。"
fi

echo
echo "=============================================================="
echo " 完成!当前 NVRAM 启动项:"
echo "=============================================================="
efibootmgr -v

cat <<EOF

--------------------------------------------------------------
 下一步
--------------------------------------------------------------
 1) 重启,进 UEFI,把 "Clover - Ally Switcher" 设为第一启动项。
 2) 进入 Clover 菜单,用 手柄十字键 上下选、A 确认:
      - 十字键 = 上/下/左/右
      - A = 确认(进系统)  B = 返回
      - 摇杆 = 鼠标  扳机 = 鼠标左/右键
 3) Clover 会自动扫描 ESP,列出 Windows 和 Bazzite。
    若某项没出现或路径不对,见下方"修路径"。

 若手柄没反应:
   - 用键盘(方向键+回车)选,永远可用
   - 进 Bazzite 后看日志: /boot/efi/EFI/clover/logs/
   - 确认 UEFI 里 USB 输入 / USB Boot 选项已开

 修路径(若 Windows/Bazzite 没被正确列出):
   进 Bazzite 后编辑 /boot/efi/EFI/clover/config.plist,
   在 <key>GUI</key> 下加 <key>Custom</key><key>Entries</key>
   显式写出两个系统的路径(路径见 diag.sh 的"关键引导器"输出)。

 回退(不用 Clover 时):
   - 进 UEFI 把原 Bazzite/Windows 启动项调回第一
   - 或: sudo efibootmgr -B -n <编号>  删除 "Clover - Ally Switcher"
   - 原有 GRUB/shim/Windows 从未被动过,随时可回退。
--------------------------------------------------------------
EOF
