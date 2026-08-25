# merge-zh-lng.ps1 - Build merged memreduct.lng = fork lng + [Chinese (Simplified)] section
# ASCII-only script; Chinese text comes from reading the i18n ini at runtime.
param(
    [Parameter(Mandatory = $true)][string]$Root
)
$ErrorActionPreference = "Stop"
$resH = Join-Path $Root "..\src\resource.h"
$zhIni = Join-Path $Root "i18n\Chinese (Simplified).ini"
$forkLng = Join-Path $Root "memreduct.lng"
$outLng = "C:\mr-dev\memreduct-merged.lng"

# 1. parse resource.h: IDS_NAME -> number
$map = @{}
Get-Content $resH | ForEach-Object {
    if ($_ -match '^#define\s+(IDS_[A-Z0-9_]+)\s+(\d+)') {
        $map[$matches[1]] = [int]$matches[2]
    }
}
Write-Output ("resource.h mappings: " + $map.Count)

# 2. parse Chinese ini (UTF-8): IDS_NAME -> translation
$zhLines = [System.IO.File]::ReadAllLines($zhIni, [System.Text.Encoding]::UTF8)
$entries = @()  # ordered list of PSCustomObject(Number, Text)
foreach ($line in $zhLines) {
    if ($line -match '^IDS_[A-Z0-9_]+=') {
        $eq = $line.IndexOf('=')
        $name = $line.Substring(0, $eq)
        $text = $line.Substring($eq + 1)
        if ($map.ContainsKey($name)) {
            $entries += [pscustomobject]@{ Number = $map[$name]; Text = $text }
        } else {
            Write-Output ("skip (no numeric id in this fork): " + $name)
        }
    }
}
Write-Output ("Chinese entries mapped: " + $entries.Count)

# 3. read fork lng as UTF-16
$forkText = [System.IO.File]::ReadAllText($forkLng, [System.Text.Encoding]::Unicode)
$hasZh = $forkText -match '\[Chinese \(Simplified\)\]'
Write-Output ("fork lng already has [Chinese (Simplified)]: " + $hasZh)

# 4. build the new section
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("")
[void]$sb.AppendLine("; Chinese (Simplified)")
[void]$sb.AppendLine("; EricChen, Initial-heart (via fork i18n source)")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("[Chinese (Simplified)]")
foreach ($e in ($entries | Sort-Object Number)) {
    $num = ("{0:D3}" -f $e.Number)
    [void]$sb.AppendLine("$num=$($e.Text)")
}

# 4b. inject the two new English defaults into the [English] section (quotes OK in INI)
$enDefaults = @(
    '089=Allow "Standby lists" and "Modified page list" cleanup on autoreduct',
    '090=Log cleaning results into a debug log'
)
$forkText = $forkText.TrimEnd("`r", "`n") + "`r`n"
if ($forkText -match '(?m)\r?\n\[English\]\r?\n') {
    $idx = $forkText.IndexOf("[English]")
    $endIdx = $forkText.IndexOf("`r`n[", $idx + 9)
    if ($endIdx -lt 0) { $endIdx = $forkText.Length }
    $ins = "`r`n" + ($enDefaults -join "`r`n")
    $forkText = $forkText.Substring(0, $endIdx) + $ins + $forkText.Substring($endIdx)
    Write-Output ("[English] injected: " + $enDefaults.Count + " lines")
} else {
    Write-Output "[English] section not found - appending defaults at end"
    $forkText = $forkText + "`r`n[English]`r`n" + ($enDefaults -join "`r`n") + "`r`n"
}

# 5. append section to fork text (order does not matter for parsing)
$merged = $forkText.TrimEnd("`r", "`n") + "`r`n" + $sb.ToString()

# 6. write UTF-16LE with BOM
[System.IO.File]::WriteAllText($outLng, $merged, [System.Text.Encoding]::Unicode)
Write-Output ("merged lng written: " + $outLng + " (" + (Get-Item $outLng).Length + " bytes)")

# 7. verify round-trip
$check = [System.IO.File]::ReadAllText($outLng, [System.Text.Encoding]::Unicode)
$m = [regex]::Match($check, '(?s)\[Chinese \(Simplified\)\](.*?)(?=\r?\n\[|\z)')
if ($m.Success) {
    $sec = $m.Groups[1].Value
    $n = ([regex]::Matches($sec, '(?m)^\d{3}=')).Count
    Write-Output ("verify [Chinese (Simplified)] entries: " + $n)
    ($sec -split "`r?`n") | Where-Object { $_ -match '^00[1-9]=|^01[0-9]=|^08[0-8]=' } | Select-Object -First 8
    Write-Output "..."
    ($sec -split "`r?`n") | Where-Object { $_ -match '^088=' }
} else {
    Write-Output "VERIFY FAILED: section not found"
}
