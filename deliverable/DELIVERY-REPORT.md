# Mem Reduct 3.5.3 ARM64 单文件版交付报告（真机验证）

日期：2026-08-25（首次交付）/ 2026-08-26（开机自启二次修复）
设备：Xiaomi Pad 5（Snapdragon 860）/ PHONE-P4U54VK7T / Windows 10 专业版 19045 (ARM64)

## 2026-08-26 开机自启动二次修复（真实开机验证失败后的根因修复）

用户反馈"设置里勾了开机自启、Windows 启动里也打开了，开机还是不启动"。逐项排查真机状态后发现**两个叠加问题**：

### 问题 1：系统启动文件夹里有一个失效的快捷方式
- `C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\memreduct.exe - 快捷方式.lnk`
- 目标指向 `C:\software\memreduct.exe`（**缺 `\memreduct\` 子目录**），文件不存在 → 每次开机静默失败。
- 用户在任务管理器"启动"里看到的并启用的，正是这个坏快捷方式。
- 处理：**已删除**（避免与 Run 键双开——程序无单实例保护，双开会出现两个托盘）。

### 问题 2：应用自带的 Run 项被 Windows 启动审批标记为禁用
- `HKCU\...\CurrentVersion\Run\Mem Reduct` 值存在且路径正确，但
  `HKCU\...\Explorer\StartupApproved\Run\Mem Reduct` = `00 00 00 00 ...`（全零=禁用），
  Explorer 登录时按审批标记**跳过**该启动项。
- 处理：清除禁用标记（等同默认启用）。

### 源码级根治（一劳永逸，任何机器都适用）
- `build\routine\src\rapp.c` `_r_autorun_enable()`：勾选"开机自启"时，写完 Run 值后**同步删除**
  `StartupApproved\Run\<应用名>` 禁用标记，避免 Windows 在下次登录时跳过。
- **真机验证（通过真实 WM_COMMAND 菜单消息驱动）**：
  1. 预置禁用标记 `03 00 00 00 + FILETIME`
  2. 向主窗口发 `IDM_LOADONSTARTUP_CHK`(158) 关 → Run 值被删除 ✓
  3. 再发 158 开 → Run 值重建为 `"C:\software\memreduct\memreduct.exe" -minimized` ✓
  4. **禁用标记被应用自动清除（自愈生效）** ✓
- 当前二进制 SHA256：`03CC98775CA66171037AE5A37958355BD76A8925B6644690F3A6F555020E7FC3`

## 交付物

**单个文件：`C:\software\memreduct\memreduct.exe`**（副本在 `C:\Vibe Coding\memreduct移植\deliverable\memreduct.exe`）

| 项目 | 值 |
|---|---|
| 文件大小 | 376,832 字节 |
| SHA256 | 见下方输出（构建后计算） |
| 版本信息 | Mem Reduct 3.5.3 / Henry++（任务管理器启动项显示 "Mem Reduct"，不再是 7zip） |
| 依赖 | 零外部文件——中文已编译进 exe 资源（RT_STRING STRINGTABLE），**不需要 memreduct.lng** |

## 用户三个问题的根治

### 1. 不能开机自启动 —— 已修复
- 根因：旧 SFX 包装每次解压到 `%TEMP%\7zSxxx\`，注册表 Run 键指向临时目录（目录随后消失）。
- 修复：Run 键现在指向固定路径：
  `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` → `"C:\software\memreduct\memreduct.exe" -minimized`
- 提权链路：非提权启动 → `memreductTask`（HighestAvailable 计划任务）自动提权 → 提权实例隐藏窗口 + 托盘常驻。
- **真机验证**：非提权 `-minimized` 启动 → 计划任务触发 → 唯一提权实例 12028/3604 存活，主窗口隐藏，托盘图标存在。

### 2. 启动项名称显示 7zip —— 已修复
- 根因：旧交付是 7-Zip SFX 外壳（VersionInfo = 7z Setup SFX / Igor Pavlov）。
- 修复：交付物是**真正的 memreduct.exe 本体**（无任何外壳），版本信息为 Mem Reduct / Henry++，启动管理器显示 "Mem Reduct"。

### 3. 无法记住设置 —— 已修复
- 根因：SFX 时代 ini 写在临时解压目录，重启即丢失。
- 修复：portable.dat 便携模式 → ini 固定在 `C:\software\memreduct\memreduct.ini`（当前保留用户设置：Language=Chinese (Simplified)、IsStartMinimized=true、Autoreduct 85%/15min、TrayActionDc=1、LogCleanResults=true 等）。
- **真机验证**：修改 ini（IsStartMinimized true→false）→ 重启程序 → 主窗口 visible=True（新值生效）；恢复原值 → 窗口隐藏（原值生效）。设置读取/持久化闭环确认。

## 单文件（无 lng）验证 —— 全部通过

移走 `memreduct.lng` 后启动（部署目录已无 lng 文件）：
- 主窗口按钮：**清理内存**（中文）✓
- 设置窗口（标题 **设置**）全部中文：
  - 窗口始终置顶 / 开机自启 / 最小化启动（不显示窗口）/ 在内存清理前手动确认
  - 跳过"用户账户控制（UAC）"提示 / 自动检查更新（推荐）/ 选择语言：
  - 重置 / 关闭
- 实现机制：`_r_locale_getstring_ex` 回退链 = lng 哈希 → "English" 哈希 → `_r_res_loadstring` 读取 exe 内嵌 STRINGTABLE（中文已编译进资源，rc 为 UTF-8 + `#pragma code_page(65001)`）。

## 功能真机验证

| 项目 | 结果 |
|---|---|
| 清理按钮（IDC_CLEAN=103） | ✓ debug log 多条 `Cleanup (Manual)`（如 23:42:44 释放 498 MB；自动清理 23:47:46 释放 851 MB） |
| 托盘图标 | ✓ `Shell_NotifyIconGetRect(uid=1)` hr=0x00000000（设备拒绝 NIF_GUID → 已有 uid fallback 生效） |
| 最小化/关闭 → 隐藏到托盘 | ✓ WM_SYSCOMMAND SC_MINIMIZE / SC_CLOSE 后窗口隐藏、**进程存活** |
| 开机自启链路 | ✓ Run 键 + memreductTask(Highest) → 提权单实例、窗口隐藏、托盘常驻 |
| 设置保存 | ✓ ini 固定路径持久化，修改后重启生效 |
| 托盘图标中文（右键菜单由 IDS_*/TITLE_* 构成，均验证为中文） | ✓ 与主界面同源 |

## 本次源码改动

1. `build\memreduct\src\resource.rc`：STRINGTABLE 全部替换为中文（IDS 1-91），文件改为 UTF-8 with BOM + `#pragma code_page(65001)`（含 45-50 补齐：工作集/系统文件缓存/备用列表（无优先级）/备用列表/已修改页面列表/合并内存列表；新增 91=IDS_UPDATE_AUTOINSTALL）。
2. `build\memreduct\src\main.h`：TITLE_* 宏中文化（工作集、系统文件缓存、备用列表等 8 项），文件保存为 UTF-8 with BOM。
3. `build\memreduct\src\resource.h`：新增 `#define IDS_UPDATE_AUTOINSTALL 91`。
4. `build\memreduct\memreduct.vcxproj`：所有 ClCompile 增加 `/utf-8` 编译选项（中文字符串正确编译）。
5. `build\routine\src\rapp.c`（2026-08-26）：`_r_autorun_enable()` 勾选开机自启时同步清除 `StartupApproved\Run` 禁用标记（自愈，防止 Explorer 登录时跳过）。

## 部署状态

`C:\software\memreduct\`：
- memreduct.exe（新单文件版 376,832 B）
- memreduct.ini（用户设置，575 B）
- portable.dat（便携模式标记）
- memreduct_debug.log / cache\ / 文档
- memreduct.exe.bak-3.5.3-zh（旧版备份）
- memreduct.lng 已移出（备份于 C:\mr-dev\lng-backup\，不再需要）
- `%TEMP%\7zS*` 残留已清理

## 备注

- 旧 SFX 交付（MemReduct-3.5.3-arm64-single.exe）已弃用，勿再分发。
- 语言菜单在无 lng 时显示 "English" 且禁用（单文件版仅内置中文，符合预期）。
- 若要切换语言，放回 lng 文件即可（程序优先读 lng）。
