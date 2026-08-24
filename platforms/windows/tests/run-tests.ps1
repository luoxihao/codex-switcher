param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Switcher = Join-Path $PSScriptRoot '..\bin\codex-switcher-main.ps1'
$script:Install = Join-Path $PSScriptRoot '..\install.ps1'
$script:Uninstall = Join-Path $PSScriptRoot '..\uninstall.ps1'
$script:FakeCodex = Join-Path $PSScriptRoot 'fake-codex.ps1'
$script:Passed = 0
$script:Failed = 0
$script:Failures = @()

function Write-TestLine {
    param([string]$Message)
    Write-Host $Message
}

function Test-Case {
    param(
        [string]$Name,
        [scriptblock]$Body
    )

    try {
        & $Body
        $script:Passed += 1
        Write-TestLine "PASS $Name"
    } catch {
        $script:Failed += 1
        $script:Failures += "FAIL $Name`n    $($_.Exception.Message)"
        Write-TestLine "FAIL $Name`n    $($_.Exception.Message)"
    }
}

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Equal {
    param(
        [object]$Expected,
        [object]$Actual,
        [string]$Message
    )

    if ($Expected -ne $Actual) {
        throw "$Message (expected '$Expected', actual '$Actual')"
    }
}

function Assert-Contains {
    param(
        [string]$Haystack,
        [string]$Needle,
        [string]$Message
    )

    if ($Haystack.IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "$Message (missing '$Needle')"
    }
}

function Assert-FileExists {
    param(
        [string]$Path,
        [string]$Message
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Message (missing file '$Path')"
    }
}

function Assert-FileContains {
    param(
        [string]$Path,
        [string]$Needle,
        [string]$Message
    )

    Assert-FileExists -Path $Path -Message $Message
    $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    Assert-Contains -Haystack $content -Needle $Needle -Message $Message
}

function New-TempDir {
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-switcher-test-" + [guid]::NewGuid().ToString('N'))
    [System.IO.Directory]::CreateDirectory($path) | Out-Null
    return $path
}

function Remove-TempDir {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }
    if (-not $Path.StartsWith([System.IO.Path]::GetTempPath(), [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove non-temp path: $Path"
    }
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
}

function Save-Env {
    param([hashtable]$TestEnv)

    $saved = @{}
    foreach ($key in @($TestEnv.Keys)) {
        $saved[$key] = [Environment]::GetEnvironmentVariable($key)
    }
    foreach ($key in $TestEnv.Keys) {
        [Environment]::SetEnvironmentVariable($key, [string]$TestEnv[$key])
    }
    return $saved
}

function Restore-Env {
    param([hashtable]$Saved)

    foreach ($key in $Saved.Keys) {
        if ($null -eq $Saved[$key]) {
            [Environment]::SetEnvironmentVariable($key, $null)
        } else {
            [Environment]::SetEnvironmentVariable($key, [string]$Saved[$key])
        }
    }
}

function New-TestContext {
    $codexHome = New-TempDir
    return [pscustomobject]@{
        Home = $codexHome
        Log = Join-Path $codexHome 'fake-codex.log'
    }
}

function Invoke-Switcher {
    param(
        [string[]]$CommandArgs,
        [hashtable]$TestEnv = @{}
    )

    $saved = Save-Env -TestEnv $TestEnv
    try {
        . $script:Switcher
        $raw = & {
            Invoke-CodexSwitcher -CommandArgs $CommandArgs
            $global:SwitcherExitCode
        } 2>&1
    } finally {
        Restore-Env -Saved $saved
    }

    $exitCode = $raw | Where-Object { $_ -is [int] } | Select-Object -Last 1
    if ($null -eq $exitCode) {
        $exitCode = -1
    }
    $output = ($raw | Where-Object { $_ -isnot [int] } | Out-String)
    return [pscustomobject]@{
        ExitCode = [int]$exitCode
        Output = $output
    }
}

function Invoke-Process {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList = @(),
        [hashtable]$TestEnv = @{}
    )

    $saved = Save-Env -TestEnv $TestEnv
    $originalExitCode = $global:LASTEXITCODE
    try {
        $global:LASTEXITCODE = 0
        $output = & $FilePath @ArgumentList 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    } finally {
        Restore-Env -Saved $saved
        $global:LASTEXITCODE = $originalExitCode
    }
    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = $output
    }
}

function Invoke-PowerShellScript {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList = @(),
        [hashtable]$TestEnv = @{}
    )

    $saved = Save-Env -TestEnv $TestEnv
    $originalExitCode = $global:LASTEXITCODE
    try {
        $global:LASTEXITCODE = 0
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $FilePath @ArgumentList 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    } finally {
        Restore-Env -Saved $saved
        $global:LASTEXITCODE = $originalExitCode
    }
    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = $output
    }
}

function Get-FreePort {
    $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $port = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
    $listener.Stop()
    return $port
}

function Start-MockHttpServer {
    param(
        [string]$Root,
        [int]$Port
    )

    $python = (Get-Command python.exe -ErrorAction Stop).Source
    $process = Start-Process -FilePath $python -ArgumentList @('-m', 'http.server', "$Port", '--bind', '127.0.0.1', '--directory', $Root) -WindowStyle Hidden -PassThru
    $ready = $false
    for ($i = 0; $i -lt 50; $i++) {
        try {
            Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$Port/v1/models" -TimeoutSec 1 | Out-Null
            $ready = $true
            break
        } catch {
            Start-Sleep -Milliseconds 100
        }
    }
    if (-not $ready) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        throw "Mock HTTP server failed to start on port $Port"
    }
    return $process
}

function Stop-MockHttpServer {
    param($Process)

    if ($null -ne $Process) {
        Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
    }
}

function Write-TestProfile {
    param(
        [string]$CodexHome,
        [string]$Name,
        [string]$BaseUrl
    )

    $profilePath = Join-Path $CodexHome "$Name.config.toml"
    $content = @"
model_provider = "openai-proxy"
model = "gpt-test"
model_catalog_json = "$Name-models.json"

[model_providers.openai-proxy]
name = "OpenAI 兼容中转"
base_url = "$BaseUrl"
wire_api = "responses"
requires_openai_auth = true
experimental_bearer_token = "sk-test-123456"
"@
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($profilePath, $content, $utf8NoBom)
}

function Write-MockModels {
    param(
        [string]$Root,
        [string]$Json
    )

    $modelsDir = Join-Path $Root 'v1'
    [System.IO.Directory]::CreateDirectory($modelsDir) | Out-Null
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText((Join-Path $modelsDir 'models'), $Json, $utf8NoBom)
}

function Write-ModelsCache {
    param([string]$CodexHome)

    $json = @'
{
  "models": [
    {
      "slug": "gpt-test",
      "display_name": "GPT Test",
      "description": "test",
      "default_reasoning_level": "low",
      "supported_reasoning_levels": [],
      "shell_type": "shell_command",
      "visibility": "list",
      "supported_in_api": true,
      "priority": 5
    }
  ]
}
'@
    Set-Content -LiteralPath (Join-Path $CodexHome 'models_cache.json') -Value $json -Encoding UTF8
}

function Start-SyncModelsTestServer {
    $root = New-TempDir
    Write-MockModels -Root $root -Json '{"data":[{"id":"gpt-test"},{"id":"unknown-model"}]}'
    $port = Get-FreePort
    $process = Start-MockHttpServer -Root $root -Port $port
    return [pscustomobject]@{
        Root = $root
        Port = $port
        Process = $process
    }
}

function Stop-SyncModelsTestServer {
    param($Server)

    if ($null -ne $Server) {
        Stop-MockHttpServer -Process $Server.Process
        Remove-TempDir -Path $Server.Root
    }
}

Test-Case -Name 'version prints windows version' {
    $ctx = New-TestContext
    try {
        $r = Invoke-Switcher -CommandArgs @('--version') -TestEnv @{
            CODEX_SWITCHER_CODEX_HOME = $ctx.Home
            CODEX_SWITCHER_CODEX_BIN = $script:FakeCodex
            FAKE_CODEX_LOG = $ctx.Log
        }
        Assert-Equal 0 $r.ExitCode 'version should exit 0'
        Assert-Contains $r.Output 'codex-switcher 3.2.0-windows' 'version output should include windows marker'
    } finally {
        Remove-TempDir -Path $ctx.Home
    }
}

Test-Case -Name 'sessions lists topics and rm reports missing id' {
    $ctx = New-TestContext
    try {
        $sid = '019fabc1-2222-3333-4444-555566667777'
        $day = Join-Path $ctx.Home 'sessions\2026\08\24'
        New-Item -ItemType Directory -Force -Path $day | Out-Null
        $rollout = Join-Path $day "rollout-2026-08-24T10-00-00-$sid.jsonl"
        Set-Content -LiteralPath $rollout -Value @(
            '{"timestamp":"2026-08-24T02:00:00.000Z","type":"session_meta","payload":{"session_id":"' + $sid + '","id":"' + $sid + '","cwd":"C:\work","model_provider":"custom","timestamp":"2026-08-24T02:00:00.000Z"}}',
            '{"timestamp":"2026-08-24T02:00:01.000Z","type":"event_msg","payload":{"type":"user_message","message":"Windows 测试主题"}}'
        ) -Encoding UTF8
        $env = @{ CODEX_SWITCHER_CODEX_HOME = $ctx.Home }

        $r = Invoke-Switcher -CommandArgs @('sessions') -TestEnv $env
        Assert-Equal 0 $r.ExitCode 'sessions should exit 0'
        Assert-Contains $r.Output 'Windows 测试主题' 'sessions should show topic'
        Assert-Contains $r.Output $sid 'sessions should show session id'

        $r2 = Invoke-Switcher -CommandArgs @('sessions', 'rm', 'missing-id') -TestEnv $env
        Assert-Equal 1 $r2.ExitCode 'rm missing id should exit 1'
        Assert-Contains $r2.Output '未找到会话' 'rm should report missing session'
    } finally {
        Remove-TempDir -Path $ctx.Home
    }
}

Test-Case -Name '__complete provides dynamic candidates' {
    $ctx = New-TestContext
    try {
        $sid = '019fabc1-2222-3333-4444-555566667777'
        $day = Join-Path $ctx.Home 'sessions\2026\08\24'
        New-Item -ItemType Directory -Force -Path $day | Out-Null
        $rollout = Join-Path $day "rollout-2026-08-24T10-00-00-$sid.jsonl"
        Set-Content -LiteralPath $rollout -Value @(
            '{"timestamp":"2026-08-24T02:00:00.000Z","type":"session_meta","payload":{"session_id":"' + $sid + '","id":"' + $sid + '","cwd":"C:\work","model_provider":"custom","timestamp":"2026-08-24T02:00:00.000Z"}}',
            '{"timestamp":"2026-08-24T02:00:01.000Z","type":"event_msg","payload":{"type":"user_message","message":"补全测试主题"}}'
        ) -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $ctx.Home 'demo.config.toml') -Value 'model = "gpt-5.5"' -Encoding UTF8
        $env = @{ CODEX_SWITCHER_CODEX_HOME = $ctx.Home }

        $r = Invoke-Switcher -CommandArgs @('__complete') -TestEnv $env
        Assert-Equal 0 $r.ExitCode '__complete should exit 0'
        Assert-Contains $r.Output 'sessions' 'top level should include sessions'
        Assert-Contains $r.Output 'demo' 'top level should include profile names'

        $r2 = Invoke-Switcher -CommandArgs @('__complete', 'sessions', 'rm') -TestEnv $env
        Assert-Contains $r2.Output 'remove' 'sessions should complete remove'
        Assert-Contains $r2.Output 'rm' 'sessions should complete rm'

        $r3 = Invoke-Switcher -CommandArgs @('__complete', 'sessions', 'rm', '019') -TestEnv $env
        Assert-Contains $r3.Output $sid 'sessions rm should complete session id'
        Assert-Contains $r3.Output '补全测试主题' 'sessions rm should include topic'

        $r4 = Invoke-Switcher -CommandArgs @('__complete', 'edit', 'demo') -TestEnv $env
        Assert-Contains $r4.Output 'demo' 'edit should complete profile names'

        $r5 = Invoke-Switcher -CommandArgs @('completion', 'powershell') -TestEnv $env
        Assert-Contains $r5.Output 'Register-ArgumentCompleter' 'completion powershell should print completer'
    } finally {
        Remove-TempDir -Path $ctx.Home
    }
}

Test-Case -Name 'create writes profile template' {
    $ctx = New-TestContext
    try {
        $r = Invoke-Switcher -CommandArgs @('create', 'demo') -TestEnv @{
            CODEX_SWITCHER_CODEX_HOME = $ctx.Home
        }
        Assert-Equal 0 $r.ExitCode 'create should exit 0'
        Assert-FileExists -Path (Join-Path $ctx.Home 'demo.config.toml') -Message 'create should write demo.config.toml'
        Assert-FileContains -Path (Join-Path $ctx.Home 'demo.config.toml') -Needle 'model_catalog_json = "demo-models.json"' -Message 'profile should reference its model catalog'
    } finally {
        Remove-TempDir -Path $ctx.Home
    }
}

Test-Case -Name 'create does not overwrite existing profile' {
    $ctx = New-TestContext
    try {
        $null = Invoke-Switcher -CommandArgs @('create', 'demo') -TestEnv @{ CODEX_SWITCHER_CODEX_HOME = $ctx.Home }
        $r = Invoke-Switcher -CommandArgs @('create', 'demo') -TestEnv @{ CODEX_SWITCHER_CODEX_HOME = $ctx.Home }
        Assert-Equal 1 $r.ExitCode 'second create should fail'
        Assert-Contains $r.Output '已存在' 'second create should say profile exists'
    } finally {
        Remove-TempDir -Path $ctx.Home
    }
}

Test-Case -Name 'list shows profiles' {
    $ctx = New-TestContext
    try {
        $null = Invoke-Switcher -CommandArgs @('create', 'alpha') -TestEnv @{ CODEX_SWITCHER_CODEX_HOME = $ctx.Home }
        $null = Invoke-Switcher -CommandArgs @('create', 'beta') -TestEnv @{ CODEX_SWITCHER_CODEX_HOME = $ctx.Home }
        $r = Invoke-Switcher -CommandArgs @('list') -TestEnv @{ CODEX_SWITCHER_CODEX_HOME = $ctx.Home }
        Assert-Equal 0 $r.ExitCode 'list should exit 0'
        Assert-Contains $r.Output 'alpha' 'list should include alpha'
        Assert-Contains $r.Output 'beta' 'list should include beta'
    } finally {
        Remove-TempDir -Path $ctx.Home
    }
}

Test-Case -Name 'delete removes profile with --yes' {
    $ctx = New-TestContext
    try {
        $null = Invoke-Switcher -CommandArgs @('create', 'demo') -TestEnv @{ CODEX_SWITCHER_CODEX_HOME = $ctx.Home }
        $r = Invoke-Switcher -CommandArgs @('delete', 'demo', '--yes') -TestEnv @{ CODEX_SWITCHER_CODEX_HOME = $ctx.Home }
        Assert-Equal 0 $r.ExitCode 'delete should exit 0'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $ctx.Home 'demo.config.toml'))) 'delete should remove profile file'
    } finally {
        Remove-TempDir -Path $ctx.Home
    }
}

Test-Case -Name 'profile launch passes profile and CODEX_HOME' {
    $ctx = New-TestContext
    try {
        $null = Invoke-Switcher -CommandArgs @('create', 'demo') -TestEnv @{ CODEX_SWITCHER_CODEX_HOME = $ctx.Home }
        $r = Invoke-Switcher -CommandArgs @('demo', '--version') -TestEnv @{
            CODEX_SWITCHER_CODEX_HOME = $ctx.Home
            CODEX_SWITCHER_CODEX_BIN = $script:FakeCodex
            FAKE_CODEX_LOG = $ctx.Log
        }
        Assert-Equal 0 $r.ExitCode 'profile launch should exit 0'
        Assert-FileExists -Path $ctx.Log -Message 'fake codex should be invoked'
        Assert-FileContains -Path $ctx.Log -Needle '--profile|demo|--version' -Message 'fake codex should receive profile and args'
        Assert-FileContains -Path $ctx.Log -Needle 'CodexHome' -Message 'fake codex should receive CODEX_HOME'
    } finally {
        Remove-TempDir -Path $ctx.Home
    }
}

Test-Case -Name 'official clears provider env and passes args' {
    $ctx = New-TestContext
    try {
        $r = Invoke-Switcher -CommandArgs @('official', '--version') -TestEnv @{
            CODEX_SWITCHER_CODEX_HOME = $ctx.Home
            CODEX_SWITCHER_CODEX_BIN = $script:FakeCodex
            FAKE_CODEX_LOG = $ctx.Log
            OPENAI_BASE_URL = 'http://bad'
            OPENAI_API_KEY = 'bad-key'
        }
        Assert-Equal 0 $r.ExitCode 'official should exit 0'
        Assert-FileContains -Path $ctx.Log -Needle '--version' -Message 'official should pass args to codex'
        $log = Get-Content -LiteralPath $ctx.Log -Raw -Encoding UTF8
        Assert-True ($log.IndexOf('http://bad', [System.StringComparison]::OrdinalIgnoreCase) -lt 0) 'provider env should be cleared (found bad OPENAI_BASE_URL)'
        Assert-True ($log.IndexOf('bad-key', [System.StringComparison]::OrdinalIgnoreCase) -lt 0) 'provider env should be cleared (found bad OPENAI_API_KEY)'
    } finally {
        Remove-TempDir -Path $ctx.Home
    }
}

Test-Case -Name 'toml parser reads test key' {
    $ctx = New-TestContext
    try {
        Write-TestProfile -CodexHome $ctx.Home -Name 'relay' -BaseUrl 'http://127.0.0.1:1/v1'
        . $script:Switcher
        $key = Get-TomlValue -Path (Join-Path $ctx.Home 'relay.config.toml') -Key 'experimental_bearer_token'
        Assert-Equal 'sk-test-123456' $key "toml parser should read key, got: $key"
    } finally {
        Remove-TempDir -Path $ctx.Home
    }
}

Test-Case -Name 'sync-models queries /models and merges catalog' {
    $ctx = New-TestContext
    $server = $null
    try {
        $null = Invoke-Switcher -CommandArgs @('create', 'relay') -TestEnv @{ CODEX_SWITCHER_CODEX_HOME = $ctx.Home }
        Write-ModelsCache -CodexHome $ctx.Home
        $server = Start-SyncModelsTestServer
        Write-TestProfile -CodexHome $ctx.Home -Name 'relay' -BaseUrl "http://127.0.0.1:$($server.Port)/v1"
        Set-Content -LiteralPath (Join-Path $ctx.Home 'relay-models.json') -Value '{"models":[{"slug":"manual-model","display_name":"Manual"}]}' -Encoding UTF8
        $probe = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$($server.Port)/v1/models"
        $probeText = [System.Text.Encoding]::UTF8.GetString([byte[]]$probe.Content)
        Assert-Contains $probeText 'gpt-test' "mock models endpoint should serve JSON, got: $probeText"

        $r = Invoke-Switcher -CommandArgs @('sync-models', 'relay') -TestEnv @{ CODEX_SWITCHER_CODEX_HOME = $ctx.Home }
        Assert-Equal 0 $r.ExitCode "sync-models should exit 0. Output: $($r.Output)"
        Assert-Contains $r.Output '新增 1 个模型' 'sync should report one added model'
        Assert-Contains $r.Output '跳过：unknown-model' 'sync should report skipped unknown model'
        Assert-FileContains -Path (Join-Path $ctx.Home 'relay-models.json') -Needle 'gpt-test' -Message 'synced catalog should include gpt-test'
        Assert-FileContains -Path (Join-Path $ctx.Home 'relay-models.json') -Needle 'manual-model' -Message 'sync should preserve manual entries'
    } finally {
        Stop-SyncModelsTestServer -Server $server
        Remove-TempDir -Path $ctx.Home
    }
}

Test-Case -Name 'edit auto syncs after editor exits' {
    $ctx = New-TestContext
    $server = $null
    $fakeEditor = Join-Path $ctx.Home 'fake-editor.ps1'
    try {
        $null = Invoke-Switcher -CommandArgs @('create', 'relay') -TestEnv @{ CODEX_SWITCHER_CODEX_HOME = $ctx.Home }
        Write-ModelsCache -CodexHome $ctx.Home
        $server = Start-SyncModelsTestServer
        $editorContent = @"
param([string]`$Target)
`$content = @'
model_provider = "openai-proxy"
model = "gpt-test"
model_catalog_json = "relay-models.json"

[model_providers.openai-proxy]
name = "OpenAI 兼容中转"
base_url = "http://127.0.0.1:$($server.Port)/v1"
wire_api = "responses"
requires_openai_auth = true
experimental_bearer_token = "sk-test-123456"
'@
`$utf8 = New-Object System.Text.UTF8Encoding(`$false)
[System.IO.File]::WriteAllText(`$Target, `$content, `$utf8)
exit 0
"@
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($fakeEditor, $editorContent, $utf8NoBom)

        $r = Invoke-Switcher -CommandArgs @('edit', 'relay') -TestEnv @{
            CODEX_SWITCHER_CODEX_HOME = $ctx.Home
            CODEX_SWITCHER_EDITOR = $fakeEditor
        }
        Assert-Equal 0 $r.ExitCode "edit should exit 0. Output: $($r.Output)"
        Assert-Contains $r.Output '模型目录同步完成' 'edit should sync model catalog'
        Assert-FileContains -Path (Join-Path $ctx.Home 'relay-models.json') -Needle 'gpt-test' -Message 'edit sync should create catalog'
    } finally {
        Stop-SyncModelsTestServer -Server $server
        Remove-TempDir -Path $ctx.Home
    }
}

Test-Case -Name 'install copies files and preserves existing deepseek models' {
    $codexHome = New-TempDir
    $bin = New-TempDir
    try {
        Set-Content -LiteralPath (Join-Path $codexHome 'deepseek-models.json') -Value '{"models":[{"slug":"existing"}]}' -Encoding UTF8
        $rootInstall = Join-Path $RepoRoot 'install.ps1'
        $r = Invoke-PowerShellScript -FilePath $rootInstall -ArgumentList @('-SkipCodex') -TestEnv @{
            CODEX_SWITCHER_BIN_DIR = $bin
            CODEX_SWITCHER_CODEX_HOME = $codexHome
            CODEX_SWITCHER_NO_PATH = '1'
        }
        Assert-Equal 0 $r.ExitCode 'install should exit 0'
        Assert-FileExists -Path (Join-Path $bin 'codex-switcher-main.ps1') -Message 'install should copy main ps1'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $bin 'codex-switcher.ps1'))) 'install should remove stale ps1'
        Assert-FileExists -Path (Join-Path $bin 'codex-switcher.cmd') -Message 'install should copy cmd'
        Assert-FileContains -Path (Join-Path $codexHome 'deepseek-models.json') -Needle 'existing' -Message 'install should not overwrite existing deepseek models'

        $r2 = Invoke-Process -FilePath (Join-Path $bin 'codex-switcher.cmd') -ArgumentList @('--version') -TestEnv @{
            CODEX_SWITCHER_CODEX_HOME = $codexHome
        }
        Assert-Equal 0 $r2.ExitCode 'installed cmd should run'
        Assert-Contains $r2.Output 'codex-switcher 3.2.0-windows' 'installed cmd should invoke ps1'
    } finally {
        Remove-TempDir -Path $codexHome
        Remove-TempDir -Path $bin
    }
}

Test-Case -Name 'uninstall removes switcher files but keeps user data' {
    $codexHome = New-TempDir
    $bin = New-TempDir
    try {
        Set-Content -LiteralPath (Join-Path $codexHome 'deepseek-models.json') -Value '{"models":[{"slug":"existing"}]}' -Encoding UTF8
        $null = Invoke-Process -FilePath $script:Install -TestEnv @{
            CODEX_SWITCHER_BIN_DIR = $bin
            CODEX_SWITCHER_CODEX_HOME = $codexHome
            CODEX_SWITCHER_NO_PATH = '1'
        }
        $null = Invoke-Switcher -CommandArgs @('create', 'demo') -TestEnv @{ CODEX_SWITCHER_CODEX_HOME = $codexHome }

        $rootUninstall = Join-Path $RepoRoot 'uninstall.ps1'
        $r = Invoke-PowerShellScript -FilePath $rootUninstall -TestEnv @{
            CODEX_SWITCHER_BIN_DIR = $bin
            CODEX_SWITCHER_CODEX_HOME = $codexHome
        }
        Assert-Equal 0 $r.ExitCode 'uninstall should exit 0'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $bin 'codex-switcher-main.ps1'))) 'uninstall should remove main ps1'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $bin 'codex-switcher.ps1'))) 'uninstall should remove stale ps1'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $bin 'codex-switcher.cmd'))) 'uninstall should remove cmd'
        Assert-FileExists -Path (Join-Path $codexHome 'demo.config.toml') -Message 'uninstall should keep profile'
        Assert-FileExists -Path (Join-Path $codexHome 'deepseek-models.json') -Message 'uninstall should keep deepseek models'
    } finally {
        Remove-TempDir -Path $codexHome
        Remove-TempDir -Path $bin
    }
}

Write-Host ''
Write-Host "Result: $($script:Passed) passed, $($script:Failed) failed"
if ($script:Failed -gt 0) {
    $script:Failures | ForEach-Object { Write-Host $_ }
    exit 1
}
exit 0
