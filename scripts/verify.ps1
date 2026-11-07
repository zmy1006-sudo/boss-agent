<#
.SYNOPSIS
  校验 boss-agent 目录是否处于「可发布 + 可安装」状态。

.DESCRIPTION
  只做静态检查，不安装、不改 DSH 配置。检查项：
    1) patch 里的技能路径是否指向本目录（唯一必须硬编码的一行）
    2) 是否残留本机绝对路径（D:\ 或 C:\Users）
    3) 技能 frontmatter 是否合法
    4) patch 结构是否被破坏（缩进 / 键 / tab / 行尾空白）
    5) 文本文件是否统一 LF
  任一项失败则退出码为 1。

  注意：Windows PowerShell 5.1 默认执行策略会拦截未签名脚本，
  请用 powershell -ExecutionPolicy Bypass -File scripts\verify.ps1 运行。

.PARAMETER Fix
  自动把 patch 里的技能路径改成本机当前路径。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\verify.ps1
  powershell -ExecutionPolicy Bypass -File scripts\verify.ps1 -Fix
#>
[CmdletBinding()]
param([switch]$Fix)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$patchPath = Join-Path $repo 'preset\cordis.patch.yml'
$skillDir = Join-Path $repo 'preset\skills'
$utf8 = New-Object System.Text.UTF8Encoding($false)

$script:failed = 0
function Check([string]$name, [scriptblock]$body) {
    try {
        $detail = & $body
        if ($detail -eq $true -or $null -eq $detail) { Write-Host "  PASS  $name" -ForegroundColor Green; return }
        Write-Host "  FAIL  $name" -ForegroundColor Red
        if ($detail) { Write-Host "        $detail" -ForegroundColor DarkGray }
        $script:failed++
    } catch {
        Write-Host "  FAIL  $name" -ForegroundColor Red
        Write-Host "        $($_.Exception.Message)" -ForegroundColor DarkGray
        $script:failed++
    }
}

function Read-Utf8([string]$path) {
    [System.IO.File]::ReadAllText($path, [System.Text.UTF8Encoding]::new($false))
}

function Get-SourceFiles {
    Get-ChildItem -Path $repo -Recurse -File |
        Where-Object { $_.Extension -in '.md', '.yml', '.yaml', '.json', '.ps1' } |
        Where-Object { $_.FullName -notmatch '\\node_modules\\|\\\.git\\' }
}

Write-Host "boss-agent 发布前自检" -ForegroundColor Cyan
Write-Host "仓库: $repo"
Write-Host ""

if (-not (Test-Path $patchPath)) { throw "找不到 $patchPath" }
$text = Read-Utf8 $patchPath
$lines = $text -split "`n"

# 1) 技能路径
Check '技能路径指向本目录' {
    $want = ($skillDir -replace '\\', '/')
    $idx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*-\s*\S.*preset/skills') { $idx = $i; break }
    }
    if ($idx -lt 0) { return 'patch 里找不到 skills 路径行' }
    $actual = $lines[$idx].Trim()
    $actual = $actual -replace '^-\s*', ''
    $actual = $actual.Trim([char[]]"'`"")
    if ($actual -eq $want) { return $true }
    if ($Fix) {
        $indent = ([regex]::Match($lines[$idx], '^\s*')).Value
        $lines[$idx] = $indent + "- '" + $want + "'"
        [System.IO.File]::WriteAllText($patchPath, ($lines -join "`n"), $utf8)
        Write-Host "        已自动修正为: $want" -ForegroundColor DarkGray
        return $true
    }
    return "实际: $actual`n        应为: $want`n        用 -Fix 自动修正"
}

# 2) 残留本机绝对路径（patch 里那一行是唯一例外）
Check '无残留本机绝对路径' {
    $allow = ($skillDir -replace '\\', '/')
    $bad = @()
    foreach ($f in (Get-SourceFiles | Where-Object { $_.Extension -ne '.ps1' })) {
        $rel = $f.FullName.Substring($repo.Length + 1)
        $i = 0
        foreach ($l in ((Read-Utf8 $f.FullName) -split "`n")) {
            $i++
            if ($l -match '[A-Za-z]:[\\/]' -or $l -match 'C:\\Users') {
                if ($l.Contains($allow)) { continue }
                $bad += ($rel + ':' + $i + '  ' + $l.Trim())
            }
        }
    }
    if ($bad.Count -eq 0) { return $true }
    return ("共 " + $bad.Count + " 处:`n        " + ($bad -join "`n        "))
}

# 3) 技能 frontmatter
Check '技能 frontmatter 合法' {
    $skills = Get-ChildItem -Path $skillDir -Directory -ErrorAction SilentlyContinue
    if (-not $skills) { return '技能目录为空' }
    $bad = @()
    foreach ($d in $skills) {
        $f = Join-Path $d.FullName 'SKILL.md'
        if (-not (Test-Path $f)) { $bad += ($d.Name + ': 缺 SKILL.md'); continue }
        $l = (Read-Utf8 $f) -split "`n"
        if ($l[0].Trim() -ne '---') { $bad += ($d.Name + ': 首行不是 ---'); continue }
        $end = -1
        for ($i = 1; $i -lt $l.Count; $i++) { if ($l[$i].Trim() -eq '---') { $end = $i; break } }
        if ($end -lt 0) { $bad += ($d.Name + ': frontmatter 未闭合'); continue }
        $fm = $l[1..($end - 1)] -join "`n"
        if ($fm -notmatch '(?m)^name:\s*\S') { $bad += ($d.Name + ': 缺 name') }
        if ($fm -notmatch '(?m)^description:\s*\S') { $bad += ($d.Name + ': 缺 description') }
        $m = [regex]::Match($fm, '(?m)^name:\s*(\S+)')
        if ($m.Success) {
            $n = $m.Groups[1].Value
            if ($n -ne $d.Name) { $bad += ($d.Name + ': name 与目录名不一致 (' + $n + ')') }
            if ($n -notmatch '^[a-z0-9-]+$') { $bad += ($d.Name + ': name 只允许小写字母、数字、连字符') }
        }
    }
    if ($bad.Count -eq 0) { return $true }
    return ($bad -join "`n        ")
}

# 4) patch 结构
Check 'patch 结构完整' {
    $bad = @()
    $first = ($lines | Where-Object { $_.Trim() -ne '' -and -not $_.Trim().StartsWith('#') } | Select-Object -First 1)
    if ($first -notmatch '^-\s*insert:\s*$') { $bad += ("首行应为 '- insert:'，实际为 '" + $first + "'") }
    if ($text -notmatch '(?m)^\s*-\s*id:\s*preset-boss\s*$') { $bad += '缺 preset-boss 条目' }
    foreach ($k in 'id', 'name', 'description', 'order', 'plugins') {
        if ($text -notmatch ('(?m)^\s+' + $k + ':')) { $bad += ('config 缺 ' + $k) }
    }
    if ($text -match '(?m)\t') { $bad += '含 tab 字符' }
    $n = 0
    foreach ($l in $lines) {
        $n++
        if ($l -match '\s+$') { $bad += ("第 " + $n + " 行有行尾空白"); break }
        if ($l.Trim() -ne '' -and (([regex]::Match($l, '^\s*')).Value.Length % 2) -ne 0) { $bad += ("第 " + $n + " 行缩进非偶数"); break }
    }
    $plugins = ([regex]::Matches($text, '(?m)^\s{10}-\s*id:\s*(\S+)\s*$')).Count
    if ($plugins -lt 10) { $bad += ('plugins 顶层项只有 ' + $plugins + ' 个，疑似缩进被破坏') }
    if ($bad.Count -eq 0) { return $true }
    return ($bad -join "`n        ")
}

# 5) 行尾
Check '文本文件统一 LF' {
    $bad = @()
    foreach ($f in Get-SourceFiles) {
        if ((Read-Utf8 $f.FullName).Contains("`r")) { $bad += $f.FullName.Substring($repo.Length + 1) }
    }
    if ($bad.Count -eq 0) { return $true }
    return ('含 CRLF: ' + ($bad -join ', '))
}

Write-Host ""
if ($script:failed -eq 0) {
    Write-Host "结论: PASS —— 可以发布" -ForegroundColor Green
    Write-Host "提示: 静态检查通过不等于装得上，装完请按 README 的「安装后自检」跑一次 BOSS 会话。"
    exit 0
}
Write-Host ("结论: FAIL —— " + $script:failed + " 项未通过") -ForegroundColor Red
exit 1
