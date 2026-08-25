# Mem Reduct 3.5.3 — Windows ARM64 移植版（全中文界面）

针对 Windows on ARM64（Snapdragon 设备）的 Mem Reduct 移植，已在本机（小米平板 5 · Snapdragon 860 · Windows 10 Pro 22H2 ARM64）完整验证。

## 修复内容

- **清理内存按钮可用**：点击后实际执行清理（调试日志记录 `Cleanup (Manual)`）
- **最小化/关闭 → 隐藏到托盘**：进程常驻，窗口不销毁
- **开机自启**：注册表 Run 键 + 任务计划程序提权（跳过 UAC 静默提权）
- **托盘图标**：routine 实现 NIF_GUID 优先、自动回退 uID（本机拒绝 GUID 图标时托盘仍显示）
- **界面全中文**：语言检测根因修复（区域英文名 `Chinese (Simplified, China)` 与语言包段名不匹配）→ 强制 `Language=Chinese (Simplified)`；合并 84 条简体中文翻译进语言包；修复 fork 硬编码的两条英文设置项

## 真机验证结果

- 全量 UI 自动化测试 **16/16 通过**（窗口显示/隐藏、托盘、清理、自启、退出）
- 中文界面逐项读取验证：主菜单、清理按钮、设置窗口、高级页复选框
- 单文件便携版实测：解压启动、中文界面、托盘图标、清理按钮实际生效

## 文件说明

| 文件 | 说明 |
|---|---|
| `src-memreduct/` | memreduct 源码（含中文修复：resource.h / resource.rc / main.c） |
| `src-routine/` | routine 库源码（托盘 GUID+uID 回退实现） |
| `i18n/` | 简体中文翻译源文件 |
| `memreduct.lng` | 合并后的语言包（84 条中文） |
| `merge-zh-lng.ps1` | 语言包合并脚本（按 resource.h 编号映射） |
| `sfx-config.txt` | 单文件自解压配置 |

## 单文件便携版

发布附件 `MemReduct-3.5.3-arm64-single.exe` 为单文件自解压版（7zSD.sfx 打包）：

- 双击运行 → 自动解压到 `%LOCALAPPDATA%\MemReduct\` → 启动
- 内含：memreduct.exe + 中文语言包 + 便携配置（启动即隐藏到托盘）+ 文档
- 配置保存在解压目录，重复运行保留设置
- 卸载：删除 `%LOCALAPPDATA%\MemReduct\` 目录

## 构建

ARM64 交叉编译（x86 MSBuild + v143 工具集），详见 `FINAL-REPORT.md`。
