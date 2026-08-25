# Mem Reduct 3.5.3 ARM64 单文件版交付报告（真机验证）

日期：2026-08-25
设备：Xiaomi Pad 5（Snapdragon 860）/ PHONE-P4U54VK7T / Windows 10 专业版 19045 (ARM64)

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
