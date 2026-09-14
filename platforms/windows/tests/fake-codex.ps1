param()

$record = [ordered]@{
    Args = ($args -join '|')
    CodexHome = $env:CODEX_HOME
    OPENAI_BASE_URL = $env:OPENAI_BASE_URL
    OPENAI_API_KEY = $env:OPENAI_API_KEY
    ANTHROPIC_BASE_URL = $env:ANTHROPIC_BASE_URL
    ANTHROPIC_AUTH_TOKEN = $env:ANTHROPIC_AUTH_TOKEN
}

if (-not [string]::IsNullOrWhiteSpace($env:FAKE_CODEX_LOG)) {
    $record | ConvertTo-Json -Compress | Add-Content -LiteralPath $env:FAKE_CODEX_LOG -Encoding UTF8
}

if (-not [string]::IsNullOrWhiteSpace($env:FAKE_CODEX_EXIT)) {
    exit ([int]$env:FAKE_CODEX_EXIT)
}

if (($args -join '|') -eq 'debug|models|--bundled' -and -not [string]::IsNullOrWhiteSpace($env:FAKE_CODEX_BUNDLED_JSON)) {
    Write-Output $env:FAKE_CODEX_BUNDLED_JSON
}

exit 0
