# Mem Reduct 协作记录（供其他 Agent 接手）

生成时间：2026-08-22
工作区：D:\VibeCoding\memreduct

## 全局规则（所有 Agent 必须遵守）

- **回复语言**：与用户的交流一律使用**中文**；仅在特殊情况（如代码标识符、编译输出、命令行、移植/工程术语等）中保留英文原文。
- 本规则适用于所有后续接手本任务的 Agent，包括本文件底部"给其他 Agent 的可直接使用提示词"。

## 用户目标

用户希望将 Mem Reduct 改为适用于 Windows ARM64（Snapdragon 860）的版本，并满足：

- 点击右上角最小化按钮：隐藏窗口，进程继续驻留系统托盘。
- 点击右上角关闭按钮：隐藏窗口，进程继续驻留系统托盘。
- 开机启动后自动运行，并保持在系统托盘。
- 清理内存按钮必须可以点击并执行清理。
- 用户要求：必须在本地测试完成后再提供版本，不接受只通过 GitHub Actions 编译验证的 release。

## 用户最近反馈

- “还是直接卡死 不显示 在本地测试完后再给我！！！！！！！！！ ”
- “怎么还是没法点击清理 清理内存的按钮 而且没法在托盘显示 你改了个啥啊”
- 最新请求：把所有聊天记录打包，发给其他 agent。

## 关键环境限制

当前工作机是 Windows x64：

- 系统：Windows 10 Pro for Workstations
- CsSystemType：x64-based PC
- ARM64 可执行文件检测为 PE32+ ARM64。
- 尝试启动 ARM64 exe 时 Windows 报错：
  “The specified executable is not a valid application for this OS platform.”
- 因此当前机器无法对 ARM64 GUI 程序做真实启动、托盘、按钮点击测试。
- 不能声称 ARM64 本地运行测试已通过。

## 仓库与远程

- 工作区：D:\VibeCoding\memreduct
- GitHub 个人 remote：SeanWang114514/memreduct
- upstream remote：henrypp/memreduct
- 当前主要分支：main

## 最近提交

- fdc0543 Fix startup freeze from early tray setup
- 8b72269 Use supported tray API version
- 8799c55 Use classic Windows tray registration
- e575785 Rewrite tray integration from startup
- 782d362 Harden tray behavior for ARM64
- b2d0064 Fix ARM64 tray icon persistence
- b8d3524 Fix final ARM64 font API call
- c07f210 Make ARM64 source compatible with routine APIs
- 5fc6d05 Fix minimize and close to tray handling

## 重要文件

- src/main.c：主窗口、清理、托盘、消息处理
- src/main.h：GUID_TrayIcon、RM/UID/TIMER 等定义
- memreduct.vcxproj：Visual Studio 工程
- .github/workflows/build-arm64.yml：ARM64 GitHub Actions 构建
- ../routine/src/routine.c：routine 托盘实现
- ../routine/src/routine.h：routine API 声明

## 当前源码关键状态

当前 src/main.c 已恢复到提交 HEAD（fdc0543）的基础状态，并在最近一轮产生了未提交修改：

### 托盘

已撤回手写 Shell_NotifyIconW 数字 APP_TRAY_ID 实现，改回 routine GUID API：

- 创建：
  _r_tray_create(hwnd, &GUID_TrayIcon, RM_TRAYICON, _app_iconcreate(0), _r_app_getname(), FALSE)
- 销毁：
  _r_tray_destroy(hwnd, &GUID_TrayIcon)
- 更新图标：
  _r_tray_setinfo(hwnd, &GUID_TrayIcon, hicon, NULL)

routine 实现内部使用 NIF_GUID、Shell_NotifyIconW、NOTIFYICON_VERSION_4。

### 窗口隐藏

当前 DlgProc 对以下消息执行 ShowWindow(hwnd, SW_HIDE)：

- WM_NCLBUTTONDOWN：HTCLOSE / HTMINBUTTON
- WM_SYSCOMMAND：SC_MINIMIZE / SC_CLOSE
- WM_SIZE：SIZE_MINIMIZED
- WM_CLOSE

WM_DESTROY 负责 KillTimer、删除托盘图标、PostQuitMessage。

### 清理按钮

原先逻辑是：

- 已提权：调用 _app_memoryclean(hwnd, SOURCE_MANUAL, 0)
- 未提权：调用 _r_app_runasadmin()，然后 DestroyWindow(hwnd)，否则显示无权限提示

最近为了避免“点击清理没反应/窗口消失”，已将 IDC_CLEAN、IDOK、IDM_TRAY_CLEAN 分支改为直接：

_app_memoryclean(hwnd, SOURCE_MANUAL, 0);

这部分尚未在 ARM64 设备上验证，需重点检查 _app_memoryclean 内部的权限行为。

## 已确认的问题

1. GitHub Actions ARM64 构建通过，并不能证明运行正常。
2. ARM64 exe 在当前 x64 机器不能启动，无法本地 GUI 验证。
3. 之前手写 Shell_NotifyIconW 的数字 ID 实现导致托盘不可见/启动卡死风险，已撤回。
4. 之前将托盘初始化提前到 WM_INITDIALOG 曾导致用户报告启动卡死，后来已移除提前初始化。
5. 当前必须避免再次发布未经 ARM64 真机验证的 release。

## routine 托盘 API

来自 ../routine/src/routine.h：

- _r_tray_create(HWND, LPCGUID, UINT, HICON, LPCWSTR, BOOLEAN)
- _r_tray_destroy(HWND, LPCGUID)
- _r_tray_setinfo(HWND, LPCGUID, HICON, LPCWSTR)
- _r_tray_toggle(HWND, LPCGUID, BOOLEAN)

来自 ../routine/src/routine.c：

- _r_tray_create 会先 NIM_DELETE，再 NIM_ADD，然后 NIM_SETVERSION。
- 使用 NIF_GUID 和 GUID_TrayIcon。

## 本轮工作记录

- 检查了 src/main.c 的 WM_COMMAND、IDC_CLEAN、RM_TRAYICON、WM_CLOSE、WM_DESTROY、RM_INITIALIZE。
- 发现清理按钮原权限分支可能导致非管理员状态下点击后窗口销毁/无明显反馈。
- 将清理按钮统一走 _app_memoryclean(hwnd, SOURCE_MANUAL, 0)。
- 将手写数字 ID 托盘替换回 routine GUID 托盘。
- 未创建新 release，未上传新包。
- 当前工作区还有历史未跟踪目录：
  - .dsh-vision-toolkit/
  - dist/memreduct-3.5.2-arm64/
  - dist/retry/
  - dist/test-arm64/

## 交接建议

下一位 Agent 应：

1. 先读取当前 src/main.c 和 git diff，确认未提交改动没有破坏 CRLF/编码。
2. 不要直接发布 release。
3. 在 ARM64 Windows 设备/虚拟机中构建并运行。
4. 用 UI 自动化确认：清理按钮、托盘图标、最小化、关闭、托盘菜单、托盘退出。
5. 如果 ARM64 环境不可用，明确告诉用户只能完成静态/编译验证，不能宣称运行通过。
6. 如果要继续修复，优先保持 routine GUID 托盘实现，不要再次切换到数字 APP_TRAY_ID，除非有 ARM64 真机日志证明 routine 实现确实失败。

## 已知 release 标签（均不能视为 ARM64 真机验证）

- v.3.5.2-arm64
- v.3.5.2-arm64-tray-fix
- v.3.5.2-arm64-tray-rewrite
- v.3.5.2-arm64-tray-classic
- v.3.5.2-arm64-startup-fix

## 诚实结论

当前没有已确认“ARM64 真机可启动、可显示托盘、可清理内存”的版本。任何后续 agent 都必须先完成 ARM64 运行验证，再向用户提供新包。

## 新增交接说明（DeepSeek Harness 页面问题）

用户后来提供了 DeepSeek Harness 截图，并说明页面右上角最小化/关闭无法点击。该截图显示的是浏览器窗口原生标题栏按钮，不是 Mem Reduct 窗口，也不是 DeepSeek Harness 页面 DOM 控件。当前 DSH 是浏览器 Web 服务：http://127.0.0.1:3080，由 Node 启动；页面代码不能接管 Chrome/Edge 原生窗口的最小化、最大化、关闭按钮。

浏览器窗口快捷键：
- 最小化：Win + ↓
- 最大化：Win + ↑
- 关闭：Alt + F4
- 刷新：Ctrl + R

不要为了这个浏览器标题栏问题修改 Mem Reduct 源码。

## 给其他 Agent 的可直接使用提示词

```text
你是接手 Mem Reduct ARM64 修复任务的工程 Agent。请先读取并遵守以下交接文件：D:\VibeCoding\memreduct\agent-handoff.md。

工作区：D:\VibeCoding\memreduct
目标：为 Windows ARM64（Snapdragon 860）修复 Mem Reduct，使清理内存按钮可用，窗口右上角最小化/关闭后隐藏到系统托盘，开机启动后驻留托盘。

必须遵守：
1. 先检查 git status、git diff、当前提交和实际源码，不要盲目重写。
2. 不要把 Mem Reduct 问题和 DeepSeek Harness 浏览器窗口问题混为一谈。DeepSeek Harness 当前访问地址是 http://127.0.0.1:3080；截图中的右上角最小化/关闭是 Chrome/浏览器原生窗口按钮，不属于页面 DOM，不能通过 Mem Reduct 代码修复。
3. 托盘优先保持 routine 的 GUID 实现：_r_tray_create、_r_tray_destroy、_r_tray_setinfo、GUID_TrayIcon。不要再次随意改成数字 APP_TRAY_ID 的手写 Shell_NotifyIconW 实现。
4. 清理按钮需要检查 IDC_CLEAN、IDOK、IDM_TRAY_CLEAN 和 _app_memoryclean 的权限/UAC行为，确保非管理员点击时有明确反馈，不能无声销毁窗口。
5. 当前测试主机是 Windows x64，不能运行 ARM64 GUI exe；绝不能声称 ARM64 真机运行通过。
6. 不要创建或上传新的 release，除非在 Windows ARM64 设备或 ARM64 虚拟机中实际验证启动、清理按钮、托盘显示、最小化、关闭、托盘菜单和退出。
7. 修改后先编译，再在可用环境中测试；记录真实结果和限制。

接手后请输出：问题根因、修改文件、构建结果、实际运行测试结果、仍需 ARM64 真机验证的项目。
```
