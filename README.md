<h1 align="center">Mem Reduct — Windows ARM64 单文件版（全中文界面）</h1>

<p align="center">
	<b>基于 <a href="https://github.com/henrypp/memreduct">henrypp/memreduct</a> 3.5.3 的 Windows on ARM64 移植</b><br>
	已在小米平板 5（Snapdragon 860 · Windows 10 Pro 19045 ARM64）真机完整验证
</p>

## 特点

- **真正的单文件**：`deliverable/memreduct.exe` 即完整程序，**不含任何 7-Zip SFX 外壳**
- **中文内嵌**：简体中文翻译已编译进 exe 资源（STRINGTABLE），**无需 memreduct.lng 或任何外部文件**
- **清理内存按钮真实工作**：日志记录 `Cleanup (Manual)`，单次释放 400–800 MB
- **最小化/关闭 → 隐藏到托盘**，进程常驻
- **开机自启**：注册表 Run 键（固定路径）+ 计划任务静默提权（HighestAvailable）
- **托盘图标**：NIF_GUID 失败自动回退 uID（Shell_NotifyIconGetRect hr=0）
- **设置持久化**：ini 固定保存在程序目录，重启后生效

## 快速开始

```powershell
# 直接运行单文件版（需管理员权限执行清理）
C:\path\to\memreduct.exe
```

## 构建（Release | ARM64）

要求：Visual Studio 2022 Build Tools（含 ARM64 工具集，PlatformToolset v143）

```powershell
MSBuild.exe memreduct.sln /p:Configuration=Release /p:Platform=ARM64
# 产物：build\bin\ARM64\memreduct.exe
```

源码位置：
- `src-memreduct/` — 主程序（main.c、resource.rc 等）
- `src-routine/` — 运行库（routine.c、rapp.c 等）

### 中文是如何内嵌的
1. `resource.rc` 的 STRINGTABLE 全部替换为简体中文（IDS 1–91），文件为 UTF-8 + `#pragma code_page(65001)`
2. `main.h` 的 `TITLE_*` 宏中文化（内存区域列表）
3. 运行时 `_r_locale_getstring_ex` 回退链：lng 文件 → "English" 哈希 → **exe 内嵌 STRINGTABLE**，因此无 lng 文件时界面仍为中文
4. `memreduct.vcxproj` 全部配置启用 `/utf-8`

## 真机验证结果

| 项目 | 结果 |
|---|---|
| 清理按钮 | ✅ Cleanup (Manual) 日志确认，真实释放内存 |
| 托盘图标 | ✅ uid=1 回退生效，Shell_NotifyIconGetRect hr=0 |
| 最小化/关闭 | ✅ 隐藏到托盘，进程存活 |
| 开机自启 | ✅ Run 键固定路径 + 计划任务提权，重启自动进入托盘 |
| 设置保存 | ✅ ini 固定路径持久化，修改后重启生效 |
| 中文界面 | ✅ 主窗口/设置窗口全部中文（无 lng 文件时） |
| 无 lng 单文件 | ✅ 已实测（lng 移走仍为中文） |

详见 `deliverable/DELIVERY-REPORT.md`。

## 发布

一键发布（源码推 GitHub + Release 更新 + exe 上传）：

```powershell
.\publish.ps1                       # 自动递增版本号
.\publish.ps1 -VersionTag v3.5.4-arm64-zh   # 指定版本
```

## 下载

- Release 资产：https://github.com/SeanWang114514/memreduct/releases
  （真单文件版 `memreduct.exe`，SHA256 见 Release 说明）