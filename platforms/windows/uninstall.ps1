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

$removed = 0
$targets = @(
    (Join-Path $binDir 'codex-switcher-main.ps1'),
    (Join-Path $binDir 'codex-switcher.ps1'),
    (Join-Path $binDir 'codex-switcher.cmd'),
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

if ($removed -eq 0) {
    Write-Output '未发现已安装的 Windows 版 codex-switcher，无需卸载。'
    exit 0
}

Write-Output ''
Write-Output 'codex-switcher Windows 版卸载完成。'
Write-Output '保留：Profile TOML、auth.json、config.toml、deepseek-models.json、Codex CLI。'
