#!/usr/bin/env bash
# ============================================================================
# diag.sh -- 在 Bazzite (Linux) 里只读诊断,输出手动安装 Clover 所需的全部信息
# 只读,不改任何东西。把全部输出贴回。
# ============================================================================
set -u

echo "=========================================================="
echo " 0) 系统识别(确认是 Bazzite)"
echo "=========================================================="
grep -iE 'PRETTY_NAME|bazzite|ublue' /etc/os-release 2>/dev/null || echo "  (读不到 os-release)"
echo

echo "=========================================================="
echo " 1) ESP 挂载点 + 磁盘/分区"
echo "=========================================================="
if mountpoint -q /boot/efi 2>/dev/null; then
  echo "  ESP 已挂载: /boot/efi"
else
  echo "  /boot/efi 未挂载,尝试找 ESP:"
  mount | grep -iE 'vfat|efi' | sed 's/^/    /'
fi
echo "  --- 磁盘分区总览 ---"
lsblk -o NAME,SIZE,FSTYPE,PARTLABEL,PARTTYPENAME 2>/dev/null | grep -iE 'EFI|vfat|Name' | sed 's/^/    /'
echo

echo "=========================================================="
echo " 2) ESP 里已有的 /EFI 结构(谁占了哪些目录)"
echo "=========================================================="
ESP="/boot/efi"
[ -d "$ESP/EFI" ] || ESP="/efi"
[ -d "$ESP/EFI" ] || ESP="/esp/efi"
echo "  使用 ESP 路径: $ESP"
( cd "$ESP" 2>/dev/null && find EFI -maxdepth 2 2>/dev/null | sort ) | sed 's/^/    /'
echo
echo "  --- 关键引导器是否存在 ---"
for f in \
  "EFI/Microsoft/Boot/bootmgfw.efi" \
  "EFI/microsoft/bootmgfw.efi" \
  "EFI/fedora/shimx64.efi" \
  "EFI/fedora/grubx64.efi" \
  "EFI/Bazzite/grubx64.efi" \
  "EFI/BOOT/BOOTX64.EFI" \
  "EFI/boot/bootx64.efi" \
  "EFI/clover/cloverx64.efi" \
  "EFI/steamos/steamcl.efi"; do
  if [ -f "$ESP/$f" ]; then echo "    [有] $f"; else echo "    [无] $f"; fi
done
echo

echo "=========================================================="
echo " 3) 当前 NVRAM 启动项"
echo "=========================================================="
command -v efibootmgr >/dev/null 2>&1 && efibootmgr -v 2>/dev/null | sed 's/^/    /' \
  || echo "    efibootmgr 未安装 (sudo dnf install efibootmgr)"
echo

echo "=========================================================="
echo " 4) 磁盘布局(确认 ESP 是哪个分区)"
echo "=========================================================="
lsblk -o NAME,SIZE,FSTYPE,PARTLABEL,MOUNTPOINT 2>/dev/null | sed 's/^/    /'
echo "  --- ESP 的 GPT 分区号/UUID ---"
for d in /dev/nvme* /dev/sd*; do
  [ -b "$d" ] || continue
  for p in "$d"p*; do
    [ -b "$p" ] || continue
    pt=$(blkid -s PARTTYPE -o value "$p" 2>/dev/null || true)
    if [ "$pt" = "c12a7328-f81f-11d2-ba4b-00a0c93ec93b" ]; then
      nro=$(partx -n -o NR "$p" 2>/dev/null | tr -d ' ')
      echo "    ESP = $p  分区号=$nro  UUID=$(blkid -s UUID -o value "$p" 2>/dev/null)"
    fi
  done
done
echo

echo "=========================================================="
echo " 5) 设备型号(确认 Ally X 的 SKU,看为什么原项目没认出)"
echo "=========================================================="
cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null | sed 's/^/    product_name: /'
cat /sys/devices/virtual/dmi/id/product_sku  2>/dev/null | sed 's/^/    product_sku:  /'
cat /sys/devices/virtual/dmi/id/sys_vendor   2>/dev/null | sed 's/^/    sys_vendor:   /'
echo
echo "=========================================================="
echo " 完成。把以上全部输出贴回给我。"
echo "=========================================================="
