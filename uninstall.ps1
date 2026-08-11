$implementation = Join-Path $PSScriptRoot 'platforms\windows\uninstall.ps1'
& $implementation
if ($null -ne $LASTEXITCODE) {
    exit $LASTEXITCODE
}
