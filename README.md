# 魅族 Note 16（M521Q）引导分区备份归档

> 从一台真实设备通过 BootROM（`spd_dump r`）导出的引导 / 系统关键分区镜像，用于解锁与 Root 之后**救砖、回滚与对照研究**。

![Device](https://img.shields.io/badge/Device-MEIZU%20Note%2016%20(M521Q)-blue)
![SoC](https://img.shields.io/badge/SoC-UNISOC%20UMS9621S-orange)
![Archive](https://img.shields.io/badge/Archive-51.52%20MB%20%2F%202%20volumes-yellow)
![Files](https://img.shields.io/badge/Partitions-24-brightgreen)

配套的完整图文流程见主仓库：**[meizu-note16-unlock](https://github.com/Dingjinjin-chihiro/meizu-note16-unlock)**

---

## 一、为什么是分卷

| 考量 | 说明 |
|---|---|
| GitHub 单文件硬上限 | 100 MB |
| GitHub 单文件警告阈值 | 50 MB |
| 本归档压缩后 | **51.52 MB** —— 正好压线 |
| 处理方式 | 切成 **2 卷 × ≤26 MB**，彻底避开警告 |

分卷用 `cat` 级顺序拼接即可还原，卷内不含校验冗余，校验全部集中在 `manifest.json` 与 `rebuild.ps1` 里完成。

```
parts/
├─ boot-images.tar.gz.part-01   26.00 MB   sha256 0fad748a…
└─ boot-images.tar.gz.part-02   25.52 MB   sha256 8b46cc57…
```

完整归档 `boot-images.tar.gz` 的 SHA256：

```
1f6f53de1d86a80362d5568e8c73dba2501e6a2ea0709386f4216d8b73dbe21c
```

原始 24 个分区合计 177.2 MB，gzip 后 51.52 MB（压缩率 29%）。

---

## 二、怎么还原

Windows PowerShell 一条命令（会自动合并 → 校验 → 解包 → 逐文件验哈希）：

```powershell
.\rebuild.ps1
```

解包到 `.\out\`。也可以指定目录：

```powershell
.\rebuild.ps1 -OutDir D:\note16-fw
```

手动做的话等价于：

```bash
cat parts/boot-images.tar.gz.part-* > boot-images.tar.gz
sha256sum boot-images.tar.gz     # 应为 1f6f53de…
tar -xzf boot-images.tar.gz -C out
```

---

## 三、归档内容（24 个分区，177.2 MB）

| 分区 | 大小 | 作用 |
|---|---|---|
| `splloader` | 0.25 MB | 一级引导，DHTB 签名头 |
| `uboot_a` / `uboot_b` | 3 MB ×2 | 二级引导 / fastboot |
| `trustos_a` / `trustos_b` | 6 MB ×2 | TEE 可信执行环境 |
| `sml_a` / `sml_b` | 1 MB ×2 | 安全监控器 |
| `boot_a` / `boot_b` | 64 MB ×2 | 内核 + ramdisk |
| `init_boot_a` / `init_boot_b` | 8 MB ×2 | 通用 ramdisk（KernelSU 目标） |
| `vbmeta_a` / `vbmeta_b` | 1 MB ×2 | AVB 校验元数据 |
| `vbmeta_system_a/b` | 1 MB ×2 | 子分区 AVB |
| `vbmeta_vendor_a/b` | 1 MB ×2 | 子分区 AVB |
| `vbmeta_product_a/b` | 1 MB ×2 | 子分区 AVB |
| `vbmeta_odm_a/b` | 1 MB ×2 | 子分区 AVB |
| `misc` | 1 MB | 开机模式 / 擦除标记 |
| `miscdata` | 1 MB | 解锁记录（偏移 0x2000） |
| `proinfo` | 1 MB | 产品信息 |

每个文件的 SHA256 都在 [`manifest.json`](manifest.json) 的 `files` 数组中。

---

## 四、明确排除的内容

| 排除项 | 原因 |
|---|---|
| `super`（10 GiB） | 体积超限，且系统镜像可从官方固件包获取 |
| `userdata` / `cache` / `blackbox` | 用户数据与缓存 |
| `prodnv` / `persist` / `nr_*` / `calinv` / `mzkv` / `rstinfo` | **含 IMEI、序列号、射频与传感器校准等设备私有数据，不公开** |

> 若你需要完整 11.68 GiB 备份：保留在本地加密存储或移动硬盘，不要上传到公共 Git 仓库。

---

## 五、写回设备（示例）

需要 `spd_dump` + 对应芯片的 `fdl1-dl.bin` / `fdl2-dl.bin`（见主仓库）。设备进入 BROM 后：

```powershell
# 还原二级引导（黑屏救援）
.\spd_dump.exe --wait 120 --reconnect exec_addr2 0x65017f08 `
  fdl fdl1-dl.bin 0x65000800 fdl fdl2-dl.bin 0xbefffe00 `
  exec w uboot_a out\uboot_a.bin reset

# 还原一级引导
.\spd_dump.exe --wait 120 --reconnect exec_addr2 0x65017f08 `
  fdl fdl1-dl.bin 0x65000800 fdl fdl2-dl.bin 0xbefffe00 `
  exec w splloader out\splloader.bin reset
```

⚠️ `0x65017f08` 是 **UMS9621** 的地址。别的芯片用别的地址，写错会变砖。

---

## 六、免责声明

- 这些镜像是**单台零售设备**的导出件，用于本人设备的恢复，不保证适用于其他批次或固件版本。
- 固件版权归 **魅族 / 紫光展锐** 所有，此处仅作个人备份与研究用途，**不得用于商业分发**。
- 刷写引导分区有变砖风险，操作者自行承担后果。

---

## License

归档脚本与元数据采用 MIT；固件镜像版权归原厂所有，不在 MIT 覆盖范围内。
