# ROG Xbox Ally X · Bazzite · Clover 双系统切换

> 让 ROG Xbox Ally X(Windows 11 + Bazzite 双系统)开机出现 **Clover 图形菜单**,
> 用 **Xbox 手柄十字键 + A 键** 在两个系统间切换。解决「GRUB 界面手柄选不了」的痛点。
>
> 已实测:手柄在 Clover 菜单里**可用**(十字键选择 + A 确认)。

---

## 一、为什么用 Clover

- GRUB 的 boot 菜单**不识别 Xbox 手柄**,只能键盘。
- **Clover** 是成熟的多系统 EFI 引导器,菜单支持手柄/鼠标/键盘导航,
  且能自动发现 ESP 里的 Windows / Bazzite 引导器。
- 关键:借助 **`UsbXbox360Dxe.efi`**(Xbox 手柄的 UEFI 驱动),让 Ally 的内置手柄
  在 UEFI 阶段被 Clover 识别。

> ⚠️ 手柄能否在 UEFI 阶段用,取决于**华硕固件是否把手柄暴露成 HID 设备**。
> Ally 的**内置手柄**走 USB,实测可用。若用**蓝牙外接手柄**,很多固件不在 UEFI
> 阶段支持蓝牙,手柄可能不灵——此时键盘(方向键+回车)永远可用,不会锁死。

---

## 二、方案来源

U 盘里已有的 **`Handheld-Clover-dualboot-main`** 项目(作者 ryanrudolf / Hooandee)
专为手持设备做,含 Clover 本体 + Xbox 手柄驱动 + 主题,但它的**自动安装脚本有设备
白名单**,没认出 `RC73XA`(本机的 `product_name` 是 `RC73XA_RC73XA`)而中止。

本项目 = **绕过白名单的手动安装**,复用该项目里的现成资源:

| 资源 | 来源 |
|------|------|
| Clover 本体 | `Handheld-Clover-dualboot-main/custom/efi/custom_clover_5157.efi` |
| Xbox 手柄 UEFI 驱动 | `.../custom/UsbXbox360Dxe.efi` |
| 手柄按键映射 | `.../custom/xbox360-clover.ini` |
| 主题(可选) | 本仓库 `themes/SwitchDeck`(选定) / `themes/ZionDeck`(备选) |

**主题说明**:不自己画,用的是社区现成主题 `adaorobles` 的
**SwitchDeck**(Nintendo Switch OLED 风格,带 Bazzite 专用图标)和 **ZionDeck**
(Steam Deck 风格)。预览图见 `assets/`。

---

## 三、目录结构

```
rog-xbox-ally-x-bazzite-clover/
├── README.md                     # 本说明
├── scripts/
│   ├── diag.sh                   # ① 只读诊断:ESP/引导器/NVRAM/SKU
│   └── install-clover.sh         # ② 装 Clover + 手柄驱动 + 1920x1080 配置 + 注册启动项
├── remote/
│   ├── install-clover-base.sh    # ② 的「绝对路径」变体(sudo 下 $HOME 会变 /root,用这个更稳)
│   └── install-switchdeck-theme.sh  # ④ 装 SwitchDeck 主题 + 改写 config 为 2 项友好菜单
├── themes/
│   ├── SwitchDeck/               # 选定主题(解压态,直接 cp 到 ESP)
│   ├── SwitchDeck-Clover-Theme.zip
│   ├── ZionDeck/                 # 备选主题
│   └── ZionDeck-Clover-Theme.zip
└── assets/
    ├── preview-SwitchDeck.png    # SwitchDeck 预览
    └── preview-ZionDeck.png      # ZionDeck 预览
```

---

## 四、完整操作步骤(在 Bazzite 终端执行)

### 前置:把 U 盘项目拷到家目录
```bash
cp -R /run/media/<用户>/系统/Handheld-Clover-dualboot-main ~/
```

### ① 诊断(只读,确认布局)
```bash
bash scripts/diag.sh
```
关注:**第 2 节**两个引导器路径、**第 3 节** NVRAM 项、**第 5 节** SKU。
本机确认结果(供参考,你的设备以 `diag.sh` 实际输出为准):
- Windows:`\EFI\Microsoft\Boot\bootmgfw.efi`
- Bazzite:`\EFI\fedora\shimx64.efi`
- ESP:`/dev/nvme0n1p1`(分区号 1;UUID 用 `blkid` 查,此处省略)
- SKU:`RC73XA_RC73XA`(ROG Xbox Ally X;所以原项目白名单没匹配上)

### ② 安装 Clover + 手柄驱动
```bash
sudo bash remote/install-clover-base.sh
```
> 用 `remote/install-clover-base.sh` 而不是 `scripts/install-clover.sh`,因为后者
> 用 `$HOME` 定位源码,`sudo` 下 `$HOME` 会变成 `/root` 导致找不到文件;
> base 版把路径写死成 `/home/<用户>/Handheld-Clover-dualboot-main`。
> (若你的用户名不同,先改脚本顶部 `SRC=` 那一行。)

成功标志:输出 `wrote_clover / wrote_xpad / wrote_config / FILES_DONE`。

### ③ 注册 NVRAM 启动项
> `-d` 填 ESP 所在**磁盘**(`lsblk -ndo PKNAME <ESP分区>` 查,本机是 `/dev/nvme0n1`),
> `-p` 填 ESP 的**分区号**(本机是 1)。以 `diag.sh` 第 4 节输出为准。
```bash
sudo efibootmgr -c -d <ESP所在磁盘> -p <分区号> \
  -L "Clover - Ally Switcher" -l "\EFI\clover\cloverx64.efi"
sudo efibootmgr -v | grep -i clover
```
本机结果:`Boot0001* Clover - Ally Switcher`,`BootOrder: 0001,0000,0002`
(Clover 已是第一启动项,重启自动进 Clover,原 Windows/Bazzite 项不受影响)。

### ④ 装 SwitchDeck 主题 + 友好菜单(可选,推荐)
```bash
# 先把主题传到 Bazzite(或在 Mac 侧 scp 过去)
# 然后:
sudo bash remote/install-switchdeck-theme.sh
```
作用:
- 把 `themes/SwitchDeck` 装进 `/boot/efi/EFI/clover/themes/SwitchDeck/`
- 改写 `config.plist`:`Theme=SwitchDeck`、**关闭 Scan**、用 `Custom>Entries`
  显式只列 **Windows 11** 和 **Bazzite** 两项(名字友好、带 Bazzite 图标)。

成功标志:输出 `theme_installed / config_updated / ALL_DONE`。

> 想换 ZionDeck:把 `install-switchdeck-theme.sh` 里的 `SwitchDeck` 全替换成
> `ZionDeck` 即可。

### ⑤ 重启测试
1. 重启 → 自动进 Clover(SwitchDeck 主题)
2. 菜单显示 **Windows 11** 和 **Bazzite** 两项
3. **手柄十字键**上下选,**A** 确认进系统

---

## 五、手柄按键(UsbXbox360Dxe + xbox360-clover.ini)

| 按键 | 作用 |
|------|------|
| 十字键 | 上/下/左/右(切换菜单项) |
| A | 确认(进系统) |
| B | 返回 |
| 左/右摇杆 | 移动鼠标指针 |
| 左扳机 | 鼠标右键 |
| 右扳机 | 鼠标左键 |

### ⚠️ 已知问题:摇杆 Y 轴方向相反

**现象**:左/右摇杆被映射为鼠标指针时,**上下方向是反的**(摇杆往上推,指针反而往下走)。

**原因**:`UsbXbox360Dxe.efi` 驱动对摇杆 Y 轴的默认方向处理,且本项目使用的
`xbox360-clover.ini` 映射文件**只提供** `LeftStickMode` / `RightStickMode`
(值 `Mouse`)这类字段,**没有**单独的 Y 轴翻转开关,故无法通过改 ini 修正。

**影响范围**:仅影响"用摇杆移动鼠标指针"的场景。Clover 列表菜单的**上下选择
请直接用十字键**(方向正常),不受影响;选系统无需摇杆。

**现状**:未修(保持现状,零风险)。若要根治需更换/重编译 UEFI 驱动以支持
Y 轴翻转,但更换驱动可能影响手柄识别,故暂不处理。

> 记录于:ROG Xbox Ally X (RC73XA) + Bazzite 实测,2026-11-11。

---

## 六、排错记录(实战踩过的坑)

| 问题 | 原因 | 解决 |
|------|------|------|
| 原项目「不支持我的设备」 | 设备白名单没匹配 `RC73XA_RC73XA` | 手动安装,绕开白名单 |
| `install-clover.sh` 报 MISSING | `sudo` 下 `$HOME`=`/root` | 用 `remote/install-clover-base.sh`(绝对路径) |
| `partx -n -o NR` 报错 | 该 Bazzite 的 partx 不认此写法 | 改用 `lsblk`/已知分区号(本机=1) |
| 菜单出现 5 项、名字是 fedora | `Scan=true` 扫出所有加载器 | 关 Scan + `Custom>Entries` 显式 2 项 |
| 远程 sudo 反复卡 | `sudo -S` 的 stdin 被 base64 管道占用 / 中文密码提示匹配 | 改在 Bazzite 本地终端跑 `sudo bash ...` |
| SSH 间歇连不上 | 设备休眠 / 多次失败触发 PAM 锁定 | 唤醒设备;等 90s 让锁定过期 |
| `tar` 报 LIBARCHIVE 警告 | macOS 打包带 `._*` 扩展头 | 无害,忽略;或 `find -name '._*' -delete` |
| 摇杆移动指针上下相反 | 驱动 Y 轴默认方向,ini 无翻转开关 | 未修;选菜单用十字键(方向正常) |

---

## 七、安全与回退

- `diag.sh` **纯只读**。
- 安装**不修改** Windows BCD、**不修改** Bazzite 的 GRUB/shim、**不改**任何系统分区;
  只在 ESP **新增** `/EFI/clover/`、`/EFI/Xbox360/` 和一个 NVRAM 启动项;装前自动备份旧 `/EFI/clover`。

**回退**(不用 Clover 时,原有系统从未被动过,随时可撤):
```bash
# 方法 A:进 UEFI 把原 Bazzite/Windows 启动项调回第一
# 方法 B:删 Clover 启动项
sudo efibootmgr -v                    # 找 "Clover - Ally Switcher" 的编号
sudo efibootmgr -B -n <编号>
# 方法 C:彻底移除 Clover 文件(可选)
sudo rm -rf /boot/efi/EFI/clover
```

---

## 八、SSH 连 Bazzite(可选,便于远程操作)

```bash
ssh <你的用户名>@<Bazzite 局域网 IP>      # 输入你的登录密码(需同局域网)
# 查看 Bazzite IP:  ip a  或  hostname -I
```
免密码:在常用电脑上
```bash
ssh-copy-id <用户名>@<IP>                 # 输一次密码
# 配 ~/.ssh/config 别名:
#   Host ally
#       HostName <IP>
#       User <用户名>
# 以后直接:  ssh ally
```

---

## 九、感谢与来源

本项目复用并基于以下开源项目/作品完成,特此致谢:

| 组件 | 来源 | 说明 |
|------|------|------|
| **Clover 双系统方案(主参考)** | [Hooandee/Handheld-Clover-dualboot](https://github.com/Hooandee/Handheld-Clover-dualboot) | H 开头仓库。面向手持设备(Steam Deck / ROG Ally / Legion Go 等)的 Clover 双系统项目,含定制 Clover EFI(隐藏 OPTIONS 按钮)、Xbox 手柄驱动、主题与安装脚本。本项目的手动安装流程、`RC73XA` 支持表、手柄映射均源自此仓库 |
| **原始上游** | [ryanrudolfoba/SteamDeck-Clover-dualboot](https://github.com/ryanrudolfoba/SteamDeck-Clover-dualboot) | Hooandee 项目 fork 自这里,感谢 ryanrudolf 的原始工作 |
| **Clover 引导器本体** | [CloverHackyColor/CloverBootloader](https://github.com/CloverHackyColor/CloverBootloader) | 本方案使用的 `custom_clover_5157.efi`(r5157 定制,隐藏 OPTIONS 按钮) |
| **Xbox 手柄 UEFI 驱动** | [SkorionOS/UsbXbox360Dxe](https://github.com/SkorionOS/UsbXbox360Dxe) · [chenx-dust/UsbXbox360Dxe](https://github.com/chenx-dust/UsbXbox360Dxe) · [jlobue10/UsbXbox360Dxe](https://github.com/jlobue10/UsbXbox360Dxe) | `UsbXbox360Dxe.efi`,让 Ally 内置 Xbox 手柄在 UEFI 阶段被 Clover 识别(十字键/A/B/摇杆/扳机映射) |
| **Eclipse 主题** | [chris1111](https://github.com/chris1111) | 备选主题之一 |
| **SwitchDeck 主题(选定)** | [adaorobles/SwitchDeck-Clover-Theme](https://github.com/adaorobles/SwitchDeck-Clover-Theme) | Nintendo Switch OLED 风格,带 Bazzite 专用图标 |
| **ZionDeck 主题(备选)** | [adaorobles/ZionDeck-Clover-Theme](https://github.com/adaorobles/ZionDeck-Clover-Theme) | Steam Deck 风格 |

> 上述作品均为开源,保留原作者署名。本项目仅做**手动安装整合 + 文档 + 排错记录**,
> 未修改任何上游二进制。
