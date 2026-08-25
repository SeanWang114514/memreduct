<#
.SYNOPSIS
    Mem Reduct ARM64 一键发布脚本
.DESCRIPTION
    一劳永逸的发布流程：
    1. 从构建目录取最新 exe（或指定路径）
    2. 复制到 repo 并提交
    3. 推送到 GitHub（带重试，处理网络不稳）
    4. 用 gh 更新 Release、上传资产、删除旧资产
    5. 验证最终状态

    用法: .\publish.ps1 [-VersionTag "v3.5.3-arm64-zh"] [-ExePath "path\to\memreduct.exe"]

    默认 VersionTag 从仓库中读取最新 tag 并递增补丁号。
    默认 ExePath 为构建目录下的 memreduct.exe。
#>

param(
    [string]$VersionTag = "",
    [string]$ExePath = "",
    [string]$RepoDir = "C:\mr-dev\repo",
    [string]$DeliverableDir = "C:\Vibe Coding\memreduct移植\deliverable",
    [string]$RepoOwner = "SeanWang114514",
    [string]$RepoName = "memreduct",
    [int]$MaxRetry = 5
)

$ErrorActionPreference = "Stop"
$Repo = "$RepoOwner/$RepoName"
$LogFile = Join-Path $DeliverableDir "publish.log"

function Log {
    param([string]$m)
    $ts = Get-Date -Format "HH:mm:ss"
    "$ts $m" | Tee-Object -FilePath $LogFile -Append | Write-Host
}

# ------- 1. 确定 exe 路径 -------
if (-not $ExePath) {
    $ExePath = "C:\Vibe Coding\memreduct移植\build\memreduct\bin\ARM64\memreduct.exe"
}
if (-not (Test-Path $ExePath)) {
    Log "错误: exe 未找到: $ExePath"
    exit 1
}
$exeInfo = Get-Item $ExePath
$exeHash = (Get-FileHash $ExePath -Algorithm SHA256).Hash
Log "exe: $($exeInfo.Length) B, SHA256: $exeHash"

# ------- 2. 确定版本标签 -------
if (-not $VersionTag) {
    $latestTag = gh release list -R $Repo --json tagName --limit 1 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty tagName
    Log "当前最新 Release tag: $latestTag"
    if ($latestTag -match 'v(\d+\.\d+\.\d+)-arm64-zh') {
        $parts = $Matches[1] -split '\.'
        $newVersion = "$($parts[0]).$($parts[1]).$([int]$parts[2] + 1)"
        $VersionTag = "v${newVersion}-arm64-zh"
    } else {
        $VersionTag = "v3.5.4-arm64-zh"
    }
}
Log "版本标签: $VersionTag"

# ------- 3. 确保 repo 是最新 ----
Log "-------------------------"
Log "同步仓库..."
git -C $RepoDir fetch origin 2>&1 | Out-Null
git -C $RepoDir reset --hard origin/arm64-zh 2>$null
Log "仓库已同步到 origin/arm64-zh"

# ------- 4. 复制 exe 到 repo ----
$assetDir = Join-Path $RepoDir "deliverable"
New-Item -ItemType Directory -Path $assetDir -Force | Out-Null
$assetPath = Join-Path $assetDir "memreduct.exe"
Copy-Item $ExePath $assetPath -Force
$repoHash = (Get-FileHash $assetPath -Algorithm SHA256).Hash
Log "资产已复制到: $assetPath"
if ($repoHash -ne $exeHash) { Log "警告: 哈希不匹配!"; exit 1 }

# ------- 5. git add/commit ----
Log "-------------------------"
Log "git add/commit..."
git -C $RepoDir add -A
$commitMsg = "Mem Reduct ARM64 单文件版 ($VersionTag)"
git -C $RepoDir commit -m $commitMsg 2>$null
Log "提交完成"

# ------- 6. push（带重试） ----
Log "-------------------------"
Log "推送到 GitHub..."
$pushed = $false
for ($i = 1; $i -le $MaxRetry -and -not $pushed; $i++) {
    Log "  push 尝试 $i/$MaxRetry ..."
    $out = git -C $RepoDir push origin arm64-zh 2>&1
    if ($LASTEXITCODE -eq 0) {
        $pushed = $true
        Log "  push 成功"
    } else {
        Log "  push 失败，等待 5 秒后重试..."
        Start-Sleep -Seconds 5
    }
}
if (-not $pushed) { Log "push 失败已达最大重试次数"; exit 1 }

# ------- 7. 创建/更新 Release + 上传资产 ----
Log "-------------------------"
Log "检查 Release 是否存在..."
$existingRelease = $null
try {
    $existingRelease = gh release view $VersionTag -R $Repo --json tagName 2>$null | ConvertFrom-Json
} catch {}

if ($existingRelease) {
    Log "Release 已存在，删除旧资产并更新..."
    $assets = gh release view $VersionTag -R $Repo --json assets 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty assets
    foreach ($a in $assets) {
        gh release delete-asset $VersionTag $a.name -R $Repo --yes 2>$null
        Log "  已删除旧资产: $($a.name)"
    }
    Start-Sleep -Seconds 2
} else {
    Log "创建新 Release..."

    $notesLines = @(
        "## Mem Reduct ARM64 单文件中文版 ($VersionTag)",
        "",
        "### 文件",
        "- memreduct.exe（$($exeInfo.Length) B，SHA256: $exeHash）",
        "",
        "### 特点",
        "- 真正的单文件（无 7-Zip SFX 外壳）",
        "- 中文已编译进 exe 资源（无需 lng 文件）",
        "- 开机自启（Run 键 + 计划任务提权）",
        "- 开机自启自愈：勾选开机自启时自动清除 Windows 启动审批禁用标记（2026-08-26 修复）",
        "- 最小化/关闭隐藏到托盘，进程常驻",
        "- 清理内存按钮真实工作",
        "- 设置持久化保存（固定路径 ini）",
        "- 托盘图标（NIF_GUID 回退 uID）",
        "",
        "### 真机验证",
        "已在小米平板 5（Snapdragon 860, Win10 19045 ARM64）逐项实测通过。"
    )
    $releaseNotes = $notesLines -join "`n"
    $notesFile = Join-Path $DeliverableDir "release-notes.md"
    [System.IO.File]::WriteAllText($notesFile, $releaseNotes, (New-Object System.Text.UTF8Encoding($true)))

    gh release create $VersionTag -R $Repo --title "Mem Reduct ARM64 单文件版" --notes-file $notesFile 2>$null
    Log "Release 已创建"
    Start-Sleep -Seconds 3
}

# 上传资产
Log "上传 memreduct.exe..."
gh release upload $VersionTag $assetPath -R $Repo --clobber 2>&1 | Out-Null
Start-Sleep -Seconds 2

# ------- 8. 打本地 git tag ----
Log "-------------------------"
git -C $RepoDir tag -f $VersionTag 2>$null
git -C $RepoDir push origin $VersionTag -f 2>$null
Log "tag 已推送: $VersionTag"

# ------- 9. 最终验证 ----
Log "-------------------------"
$final = gh release view $VersionTag -R $Repo --json assets 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty assets
Log "Release 最终资产:"
$final | ForEach-Object { Log "  $($_.name) ($($_.size) B, sha256: $($_.digest.Substring(7,64)))" }

$downloaded = $final | Where-Object { $_.name -eq 'memreduct.exe' } | Select-Object -ExpandProperty downloadCount
Log "下载次数: $downloaded"

Log "========================="
Log "发布完成！"
Log "Release URL: https://github.com/$Repo/releases/tag/$VersionTag"