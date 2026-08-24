[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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
$completionDir = if (-not [string]::IsNullOrWhiteSpace($env:CODEX_SWITCHER_COMPLETIONS_DIR)) {
    $env:CODEX_SWITCHER_COMPLETIONS_DIR
} else {
    Join-Path $env:LOCALAPPDATA 'codex-switcher\completions'
}

$removed = 0
$targets = @(
    (Join-Path $binDir 'codex-switcher-main.ps1'),
    (Join-Path $binDir 'codex-switcher.ps1'),
    (Join-Path $binDir 'codex-switcher.cmd'),
    (Join-Path $completionDir 'codex-switcher-completion.ps1'),
    (Join-Path $codexHome 'bin\codex-switcher-main.ps1'),
    (Join-Path $codexHome 'bin\codex-switcher.ps1'),
    (Join-Path $codexHome 'bin\codex-switcher.cmd'),
    (Join-Path $codexHome 'codex-switcher-package\bin\codex-switcher-main.ps1'),
    (Join-Path $codexHome 'codex-switcher-package\bin\codex-switcher.ps1'),
    (Join-Path $codexHome 'codex-switcher-package\bin\codex-switcher.cmd')
)
foreach ($target in $targets) {
    if (Test-Path -LiteralPath $target -PathType Leaf) {
        Remove-Item -LiteralPath $target -Force
        $removed = 1
        Write-Output "已删除：$target"
    }
}

$marker = Join-Path $env:LOCALAPPDATA 'codex-switcher\path-added.txt'
if (Test-Path -LiteralPath $marker -PathType Leaf) {
    $addedPath = (Get-Content -LiteralPath $marker -Raw -Encoding UTF8).Trim()
    if ($addedPath.TrimEnd('\') -ieq $binDir.TrimEnd('\')) {
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        $needle = $binDir.TrimEnd('\')
        $newPath = @($userPath -split ';' | Where-Object { $_.TrimEnd('\') -ine $needle }) -join ';'
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        Write-Output "已从用户 PATH 移除：$binDir"
        $removed = 1
    }
    Remove-Item -LiteralPath $marker -Force
}

$profilePath = if (-not [string]::IsNullOrWhiteSpace($env:CODEX_SWITCHER_PS_PROFILE)) {
    $env:CODEX_SWITCHER_PS_PROFILE
} else {
    $PROFILE.CurrentUserAllHosts
}
if (Test-Path -LiteralPath $profilePath -PathType Leaf) {
    $profileContent = Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8
    if ($profileContent -match 'codex-switcher (completions|menu-complete)') {
        $tmpPath = "$profilePath.tmp.$PID"
        $newContent = $profileContent -replace '(?m)^# codex-switcher (completions|menu-complete)\r?\n[^\r\n]*\r?\n', ''
        [System.IO.File]::WriteAllText($tmpPath, $newContent, (New-Object System.Text.UTF8Encoding($false)))
        Move-Item -LiteralPath $tmpPath -Destination $profilePath -Force
        $removed = 1
        Write-Output "已移除 $profilePath 中的 codex-switcher 补全配置"
    }
}

if ($removed -eq 0) {
    Write-Output '未发现已安装的 Windows 版 codex-switcher，无需卸载。'
    exit 0
}

Write-Output ''
Write-Output 'codex-switcher Windows 版卸载完成。'
Write-Output '保留：Profile TOML、auth.json、config.toml、deepseek-models.json、Codex CLI。'
