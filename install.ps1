[CmdletBinding()]
param(
    [switch]$InstallCodex,
    [switch]$SkipCodex
)

$implementation = Join-Path $PSScriptRoot 'platforms\windows\install.ps1'
& $implementation -InstallCodex:$InstallCodex -SkipCodex:$SkipCodex
if ($null -ne $LASTEXITCODE) {
    exit $LASTEXITCODE
}
