Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$key = $env:CODEX_SWITCHER_TEST_DEEPSEEK_KEY
if ([string]::IsNullOrWhiteSpace($key)) {
    $key = [Environment]::GetEnvironmentVariable('CODEX_SWITCHER_TEST_DEEPSEEK_KEY', 'User')
}
if ([string]::IsNullOrWhiteSpace($key)) {
    throw 'CODEX_SWITCHER_TEST_DEEPSEEK_KEY is not set.'
}
if (-not $key.StartsWith('sk-')) {
    throw 'CODEX_SWITCHER_TEST_DEEPSEEK_KEY does not look like a DeepSeek key.'
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$switcher = Join-Path $repoRoot 'platforms\windows\bin\codex-switcher-main.ps1'
$asset = Join-Path $repoRoot 'assets\deepseek-models.json'
$root = Join-Path $env:TEMP ("codex-switcher-real-ds-" + [guid]::NewGuid().ToString('N'))
$endpointFile = Join-Path $env:TEMP ("ds-endpoint-" + [guid]::NewGuid().ToString('N') + '.json')
$rootCreated = $false
$oldCodexHome = $env:CODEX_SWITCHER_CODEX_HOME

try {
    New-Item -ItemType Directory -Path $root | Out-Null
    $rootCreated = $true

    $endpointOk = $null
    foreach ($url in @('https://api.deepseek.com/models', 'https://api.deepseek.com/v1/models')) {
        $code = & curl.exe -sS -o $endpointFile -w '%{http_code}' -m 20 -H "Authorization: Bearer $key" $url
        "ENDPOINT=$url HTTP=$code"
        if ($code -eq '200') {
            $parsed = Get-Content -LiteralPath $endpointFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $ids = @($parsed.data | Where-Object { $_.id } | ForEach-Object { [string]$_.id })
            "MODEL_COUNT=$($ids.Count)"
            $ids | Select-Object -First 20
            if ($null -eq $endpointOk) {
                $endpointOk = $url
            }
        }
    }
    if ($null -eq $endpointOk) {
        throw 'No DeepSeek /models endpoint returned 200.'
    }

    $baseUrl = $endpointOk -replace '/models$', ''
    $env:CODEX_SWITCHER_CODEX_HOME = $root

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $switcher create deepseek-test
    $createExit = $LASTEXITCODE
    "CREATE_EXIT=$createExit"

    $profilePath = Join-Path $root 'deepseek-test.config.toml'
    $content = @"
model_provider = "openai-proxy"
model = "gpt-5.5"
model_catalog_json = "deepseek-test-models.json"

[model_providers.openai-proxy]
name = "OpenAI 兼容中转"
base_url = "$baseUrl"
wire_api = "responses"
requires_openai_auth = true
experimental_bearer_token = "$key"
"@
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($profilePath, $content, $utf8NoBom)
    Copy-Item -LiteralPath $asset -Destination (Join-Path $root 'deepseek-models.json') -Force

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $switcher sync-models deepseek-test
    $syncExit = $LASTEXITCODE
    "SYNC_EXIT=$syncExit"

    $catalogPath = Join-Path $root 'deepseek-test-models.json'
    if (Test-Path -LiteralPath $catalogPath -PathType Leaf) {
        $catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
        "CATALOG_COUNT=$($catalog.models.Count)"
        $catalog.models | Select-Object -ExpandProperty slug
    }
} finally {
    if ($null -eq $oldCodexHome) {
        Remove-Item Env:CODEX_SWITCHER_CODEX_HOME -ErrorAction SilentlyContinue
    } else {
        $env:CODEX_SWITCHER_CODEX_HOME = $oldCodexHome
    }
    Remove-Item -LiteralPath $endpointFile -Force -ErrorAction SilentlyContinue
    if ($rootCreated -and (Test-Path -LiteralPath $root)) {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}
