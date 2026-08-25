# Mem Reduct 3.5.3 ARM64 移植 — 交付报告（真机验证）

**设备**: Xiaomi Pad 5 · Snapdragon 860 · Windows 10 Pro 22H2 (10.0.19045) ARM64
**交付物**: `C:\software\memreduct\memreduct.exe`（3.5.3，378,880 字节，SHA256 `C47605DC6FBF09D5...`）
**状态**: 应用当前以提权状态运行、窗口隐藏、托盘图标显示、**界面全中文**。开机自启已启用。

---

## 四项需求 — 全部真机验证通过（16/16 自动化测试 + 最终冒烟 + 开机链路）

| 需求 | 测试 | 结果 |
|---|---|---|
| 最小化按钮隐藏窗口、进程驻留托盘 | T04/T04b | ✅ 窗口隐藏、进程存活 |
| 关闭按钮隐藏窗口、进程驻留托盘 | T06/T06b | ✅ 窗口隐藏、进程存活 |
| 开机自启、启动后驻留托盘 | T12/T13/T14 + 开机链路实测 | ✅ Run 键 + skipuac 提权任务 + 隐藏启动 + 图标显示 |
| 清理内存按钮可点击且真实清理 | T08（点击 IDC_CLEAN=103） | ✅ 每次点击均执行真实清理（释放 148–846 MB，写入 debug log） |

**16 项测试全绿**（`test/final-report/uitest-report.json`）：
T01 窗口显示 · T02 进程存活 · **T03 托盘图标添加（Shell_NotifyIconGetRect S_OK，图标在屏）** · T04 最小化隐藏 · T05 托盘恢复 · T06 关闭隐藏 · T07 再次恢复 · **T08 清理按钮真实清理** · T09 托盘菜单弹出 · T10 托盘菜单清理 · T11 托盘退出 · T12 自启注册 · T13 自启开关清理 · **T14 最小化启动(隐藏+托盘)**。

## 根因与修复（本次工作的核心）

**用户反馈"没法在托盘显示"的真正原因**: 这台设备的 shell **拒绝 `NIF_GUID` 方式的托盘图标**。
用原生 ARM64 探测程序（`test/final-report/trayprobe*.c`，本机工具链编译）实测：
- `Shell_NotifyIconW(NIM_ADD, NIF_GUID)` → **E_FAIL (0x80004005)**（官方 3.5.2 同样失败）
- `Shell_NotifyIconW(NIM_ADD, 经典 uID)` → **成功**，`Shell_NotifyIconGetRect` 返回 S_OK，图标真实显示在屏

**修复**（`build/routine/src/routine.c`）: 在 `_r_tray_create` 内加 GUID→uID **兼容回退**——
GUID 注册失败时自动改用经典 uID 重新注册，并维护 per-hwnd 模式表，使 `_r_tray_destroy/setinfo/popup/toggle`
全部使用同一标识。正常系统仍走 GUID 路径，不受影响。

## 其他工作

- 测试脚本 `test/memreduct-uitest.ps1` 修复多项自动化问题（NIN_KEYSELECT=0x401、UTF-16 日志读取、
  托盘按钮计数改用 EnumChildWindows、路径含中文/空格时的参数引用、部署顺序等），现可稳定全绿。
- 本机构建: VS Build Tools 2022 (v143) 编译 ARM64 Release，`memreduct.vcxproj` 本地 v145→v143
  （仅本地构建用，远端源码保持 v145）。
- 部署: `C:\software\memreduct`（备份: `C:\software\memreduct-backup-3.5.2`，含官方 3.5.2 exe + 用户 ini）；
  保留用户 `memreduct.ini`（IsStartMinimized=true、Autoreduct 85%/15min、TrayActionDc=1）与 `.lng/Readme/portable.dat`。

## 开机链路（实测）

HKCU Run `"C:\software\memreduct\memreduct.exe" -minimized` → 非提权启动 →
`memreductTask`（RunLevel=Highest，指向同一路径）提权重启 → 非提权实例退出 →
**提权实例窗口隐藏、托盘图标显示（S_OK）、保留完整清理权限**。✅

## 界面全中文化（本次追加）

- 根因：系统区域语言英文名是 `Chinese (Simplified, China)`，与 lng 中的 `[Chinese (Simplified)]` 段名不匹配 → 回退英文。
- 修复：`memreduct.ini` 增加 `Language=Chinese (Simplified)` 强制中文。
- 配套：`build\memreduct\bin\i18n\Chinese (Simplified).ini`（fork 源码自带 92 条简体翻译）→
  由 `build\memreduct\bin\merge-zh-lng.ps1` 按 `resource.h` 编号映射合并进 `memreduct.lng`
  （UTF-16LE，84 条中文 + `[English]` 段补充 089/090 英文默认）→ 部署为 `memreduct.lng`（123,802 字节）。
- 源码修复：fork 的 `main.c` 硬编码了两条英文（高级页复选框）→ 改用 `_r_locale_getstring`，
  `resource.h` 新增 `IDS_ALLOWSTANDBYLISTCLEANUP_CHK=89` / `IDS_LOGRESULTS_CHK=90`，
  `resource.rc` 补充默认英文 → 重建。
- 真机验证（读取实际窗口文本）：主菜单 `文件/视图/设置/帮助` 及全部子项、清理按钮 `清理内存`、
  设置窗口 `重置/关闭/选项:`、高级页 `允许在自动清理时清理"备用列表"和"已修改页面列表"`、
  `将清理结果记录到调试日志中` 均为中文。
- 新 exe 全量回归：**16/16 通过**（`uitest-report-localized-exe.json`）。

## 遗留说明

- 官方 3.5.2 在本机同样无托盘图标（GUID 被 shell 拒绝）；本 fork 是**唯一**能在这台设备显示
  托盘图标的版本。
- 图标落位由 shell 决定（系统区工具栏或折叠溢出区），两种状态 `Shell_NotifyIconGetRect` 均非错误
  （S_OK=可见 / S_FALSE=已注册在折叠区），托盘图标始终存在。
- 未做真实重启验证（需重启设备）；开机链路各环节（Run 键、skipuac 任务、提权重启、隐藏启动、图标注册）
  均已单独实测通过。
