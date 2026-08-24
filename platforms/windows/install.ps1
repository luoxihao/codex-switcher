[CmdletBinding()]
param(
    [switch]$InstallCodex,
    [switch]$SkipCodex
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

$platformDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $platformDir)
$binDir = if (-not [string]::IsNullOrWhiteSpace($env:CODEX_SWITCHER_BIN_DIR)) {
    $env:CODEX_SWITCHER_BIN_DIR.TrimEnd('\')
} else {
    Join-Path $env:USERPROFILE '.local\bin'
}
$codexHome = if (-not [string]::IsNullOrWhiteSpace($env:CODEX_SWITCHER_CODEX_HOME)) {
    $env:CODEX_SWITCHER_CODEX_HOME.TrimEnd('\')
} else {
    Join-Path $env:USERPROFILE '.codex'
}

New-Item -ItemType Directory -Force -Path $binDir, $codexHome | Out-Null

$sourcePs1 = Join-Path $platformDir 'bin\codex-switcher-main.ps1'
$sourceCmd = Join-Path $platformDir 'bin\codex-switcher.cmd'
if (-not (Test-Path -LiteralPath $sourcePs1 -PathType Leaf) -or -not (Test-Path -LiteralPath $sourceCmd -PathType Leaf)) {
    throw "找不到 Windows 版文件：$sourcePs1 或 $sourceCmd"
}

$installedPs1 = Join-Path $binDir 'codex-switcher-main.ps1'
Copy-Item -LiteralPath $sourcePs1 -Destination $installedPs1 -Force
Copy-Item -LiteralPath $sourceCmd -Destination (Join-Path $binDir 'codex-switcher.cmd') -Force
$stalePs1 = Join-Path $binDir 'codex-switcher.ps1'
if (Test-Path -LiteralPath $stalePs1 -PathType Leaf) {
    Remove-Item -LiteralPath $stalePs1 -Force
    Write-Output "已移除旧版：$stalePs1"
}
Write-Output "已安装命令：$(Join-Path $binDir 'codex-switcher.cmd')"

foreach ($relativeDir in @('bin', 'codex-switcher-package\bin')) {
    $targetDir = Join-Path $codexHome $relativeDir
    if (Test-Path -LiteralPath $targetDir -PathType Container) {
        Copy-Item -LiteralPath $sourcePs1 -Destination (Join-Path $targetDir 'codex-switcher-main.ps1') -Force
        Copy-Item -LiteralPath $sourceCmd -Destination (Join-Path $targetDir 'codex-switcher.cmd') -Force
        $staleTarget = Join-Path $targetDir 'codex-switcher.ps1'
        if (Test-Path -LiteralPath $staleTarget -PathType Leaf) {
            Remove-Item -LiteralPath $staleTarget -Force
            Write-Output "已移除旧版：$staleTarget"
        }
        Write-Output "已同步 Codex 内部命令：$(Join-Path $targetDir 'codex-switcher.cmd')"
    }
}

$sourceAsset = Join-Path $repoRoot 'assets\deepseek-models.json'
if (Test-Path -LiteralPath $sourceAsset -PathType Leaf) {
    $targetAsset = Join-Path $codexHome 'deepseek-models.json'
    if (Test-Path -LiteralPath $targetAsset -PathType Leaf) {
        Write-Output "已存在 DeepSeek 模型来源目录，保留现有内容不覆盖：$targetAsset"
    } else {
        Copy-Item -LiteralPath $sourceAsset -Destination $targetAsset -Force
        Write-Output "已安装 DeepSeek 模型来源目录：$targetAsset"
    }
}

if ($env:CODEX_SWITCHER_NO_PATH -ne '1') {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $needle = $binDir.TrimEnd('\')
    $already = @($userPath -split ';' | Where-Object { $_.TrimEnd('\') -ieq $needle }).Count -gt 0
    if (-not $already) {
        $newPath = if ([string]::IsNullOrWhiteSpace($userPath)) { $binDir } else { "$binDir;$userPath" }
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        $env:Path = "$binDir;$env:Path"
        $markerDir = Join-Path $env:LOCALAPPDATA 'codex-switcher'
        New-Item -ItemType Directory -Force -Path $markerDir | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $markerDir 'path-added.txt'), $binDir, (New-Object System.Text.UTF8Encoding($false)))
        Write-Output "已将 $binDir 加入用户 PATH"
    } else {
        Write-Output "$binDir 已在用户 PATH 中"
    }
}

if ($env:CODEX_SWITCHER_NO_COMPLETION -ne '1') {
    $completionSource = Join-Path $platformDir 'completions\codex-switcher-completion.ps1'
    if (Test-Path -LiteralPath $completionSource -PathType Leaf) {
        $completionDir = if (-not [string]::IsNullOrWhiteSpace($env:CODEX_SWITCHER_COMPLETIONS_DIR)) {
            $env:CODEX_SWITCHER_COMPLETIONS_DIR
        } else {
            Join-Path $env:LOCALAPPDATA 'codex-switcher\completions'
        }
        New-Item -ItemType Directory -Force -Path $completionDir | Out-Null
        $completionTarget = Join-Path $completionDir 'codex-switcher-completion.ps1'
        Copy-Item -LiteralPath $completionSource -Destination $completionTarget -Force
        Write-Output "已安装补全文件：$completionTarget"

        $profilePath = if (-not [string]::IsNullOrWhiteSpace($env:CODEX_SWITCHER_PS_PROFILE)) {
            $env:CODEX_SWITCHER_PS_PROFILE
        } else {
            $PROFILE.CurrentUserAllHosts
        }
        if (-not (Test-Path -LiteralPath $profilePath -PathType Leaf)) {
            $profileDir = Split-Path -Parent $profilePath
            if (-not (Test-Path -LiteralPath $profileDir -PathType Container)) {
                New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
            }
            New-Item -ItemType File -Force -Path $profilePath | Out-Null
        }
        $profileContent = Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        $marker = '# codex-switcher completions'
        if ($null -eq $profileContent -or $profileContent -notmatch [regex]::Escape($marker)) {
            $sourceLine = '. "' + $completionTarget + '"'
            Add-Content -LiteralPath $profilePath -Value ("`n$marker`n$sourceLine`n") -Encoding UTF8
            Write-Output "已在 PowerShell Profile 启用补全：$profilePath"
        }
    }
}

$existingCodex = Get-Command codex -ErrorAction SilentlyContinue | Select-Object -First 1
if ($SkipCodex) {
    Write-Output '已跳过 Codex CLI 安装。'
} elseif (-not $InstallCodex -and $null -ne $existingCodex) {
    Write-Output "检测到现有 Codex CLI：$($existingCodex.Source)"
} else {
    Write-Output '正在下载官方 Codex CLI 安装器...'
    $installer = Join-Path $env:TEMP ("codex-install-" + [guid]::NewGuid().ToString('N') + '.ps1')
    Invoke-WebRequest -UseBasicParsing -Uri 'https://chatgpt.com/codex/install.ps1' -OutFile $installer
    $oldNonInteractive = $env:CODEX_NON_INTERACTIVE
    $oldCodexHome = $env:CODEX_HOME
    $env:CODEX_NON_INTERACTIVE = '1'
    $env:CODEX_HOME = $codexHome
    try {
        & $installer
        if ($LASTEXITCODE -ne 0) {
            throw "Codex CLI 安装失败（退出码 $LASTEXITCODE）"
        }
    } finally {
        if ($null -eq $oldNonInteractive) {
            Remove-Item Env:CODEX_NON_INTERACTIVE -ErrorAction SilentlyContinue
        } else {
            $env:CODEX_NON_INTERACTIVE = $oldNonInteractive
        }
        if ($null -eq $oldCodexHome) {
            Remove-Item Env:CODEX_HOME -ErrorAction SilentlyContinue
        } else {
            $env:CODEX_HOME = $oldCodexHome
        }
        Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue
    }
    Write-Output 'Codex CLI 安装完成。'
}

Write-Output 'codex-switcher Windows 版安装完成。'
Write-Output '新开一个 PowerShell 窗口，或执行：codex-switcher --help'
