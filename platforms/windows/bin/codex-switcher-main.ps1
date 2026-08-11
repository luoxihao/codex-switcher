Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CodexHome {
    if (-not [string]::IsNullOrWhiteSpace($env:CODEX_SWITCHER_CODEX_HOME)) {
        return $env:CODEX_SWITCHER_CODEX_HOME.TrimEnd('\')
    }
    return Join-Path $env:USERPROFILE '.codex'
}

function Get-SwitchedBinDir {
    if (-not [string]::IsNullOrWhiteSpace($env:CODEX_SWITCHER_BIN_DIR)) {
        return $env:CODEX_SWITCHER_BIN_DIR.TrimEnd('\')
    }
    return Join-Path $env:USERPROFILE '.local\bin'
}

function Find-Codex {
    if (-not [string]::IsNullOrWhiteSpace($env:CODEX_SWITCHER_CODEX_BIN)) {
        if (Test-Path -LiteralPath $env:CODEX_SWITCHER_CODEX_BIN -PathType Leaf) {
            return $env:CODEX_SWITCHER_CODEX_BIN
        }
    }

    $cmd = Get-Command codex -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $cmd -and -not [string]::IsNullOrWhiteSpace($cmd.Source)) {
        return $cmd.Source
    }

    foreach ($candidate in @(
        (Join-Path $env:LOCALAPPDATA 'Programs\OpenAI\Codex\bin\codex.exe'),
        (Join-Path $env:APPDATA 'npm\codex.cmd'),
        (Join-Path $env:USERPROFILE '.codex\packages\standalone\current\bin\codex.exe')
    )) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    foreach ($root in @(
        (Join-Path $env:USERPROFILE '.vscode'),
        (Join-Path $env:USERPROFILE '.vscode-insiders')
    )) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) {
            continue
        }
        foreach ($ext in Get-ChildItem -LiteralPath $root -Directory -Filter 'openai.chatgpt-*' -ErrorAction SilentlyContinue) {
            foreach ($arch in @('windows-x86_64', 'windows-aarch64', 'windows-arm64')) {
                $candidate = Join-Path $ext.FullName "bin\$arch\codex.exe"
                if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                    return $candidate
                }
            }
        }
    }

    throw '找不到 Codex CLI。请先安装 Codex，或设置 CODEX_SWITCHER_CODEX_BIN。'
}

function Find-VsCode {
    if (-not [string]::IsNullOrWhiteSpace($env:CODEX_SWITCHER_VSCODE_BIN)) {
        if (Test-Path -LiteralPath $env:CODEX_SWITCHER_VSCODE_BIN -PathType Leaf) {
            return $env:CODEX_SWITCHER_VSCODE_BIN
        }
    }

    foreach ($commandName in @('code', 'code-insiders')) {
        $cmd = Get-Command $commandName -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $cmd -and -not [string]::IsNullOrWhiteSpace($cmd.Source)) {
            return $cmd.Source
        }
    }

    foreach ($candidate in @(
        (Join-Path $env:ProgramFiles 'Microsoft VS Code\bin\code.cmd'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\bin\code.cmd'),
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft VS Code\bin\code.cmd'),
        (Join-Path $env:ProgramFiles 'Microsoft VS Code Insiders\bin\code-insiders.cmd'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code Insiders\bin\code-insiders.cmd')
    )) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    throw '找不到 VS Code 命令。请安装 code 命令，或设置 CODEX_SWITCHER_VSCODE_BIN。'
}

function Get-TomlValue {
    param(
        [string]$Path,
        [string]$Key
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }
    $pattern = '^\s*' + [regex]::Escape($Key) + '\s*=\s*"([^"]*)"\s*$'
    foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
        if ($line -match $pattern) {
            return $Matches[1]
        }
    }
    return $null
}

function Test-PlaceholderKey {
    param([string]$Key)

    if ([string]::IsNullOrWhiteSpace($Key)) {
        return $true
    }
    if ($Key -like 'PASTE_*' -or $Key -like 'REPLACE_*' -or $Key -like 'YOUR_*' -or $Key.StartsWith('<') -or $Key.Length -lt 10) {
        return $true
    }
    return $false
}

function Write-Utf8File {
    param(
        [string]$Path,
        [string]$Content
    )

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function New-ProfileTemplate {
    param(
        [string]$Name,
        [string]$CodexHome
    )

    $target = Join-Path $CodexHome "$Name.config.toml"
    if (Test-Path -LiteralPath $target) {
        throw "profile 已存在，不会覆盖：$target"
    }
    New-Item -ItemType Directory -Force -Path $CodexHome | Out-Null
    $content = @"
model_provider = "openai-proxy"
model = "gpt-5.5"
review_model = "gpt-5.5"
model_reasoning_effort = "xhigh"
disable_response_storage = true
network_access = "enabled"
model_catalog_json = "$Name-models.json"

[model_providers.openai-proxy]
name = "OpenAI 兼容中转"
base_url = "https://你的中转站/v1"
wire_api = "responses"
requires_openai_auth = true
experimental_bearer_token = "<你的Key>"
"@
    Write-Utf8File -Path $target -Content $content
}

function Get-ProfileList {
    param([string]$CodexHome)

    if (-not (Test-Path -LiteralPath $CodexHome -PathType Container)) {
        return @()
    }
    return @(
        Get-ChildItem -LiteralPath $CodexHome -Filter '*.config.toml' -File -ErrorAction SilentlyContinue |
            ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) } |
            Sort-Object -Unique
    )
}

function Test-ValidName {
    param([string]$Name)

    if ($Name -notmatch '^[A-Za-z0-9._-]+$') {
        throw '名称只能包含字母、数字、点、下划线和短横线。'
    }
}

function Test-ReservedName {
    param([string]$Name)

    if ($Name -in @('list', 'create', 'edit', 'delete', 'remove', 'rm', 'sync-models', 'official', 'default', 'reset', 'restore', 'help', 'version')) {
        throw "'$Name' 是保留命令名，请换一个 profile 名称。"
    }
}

function Merge-ModelCatalog {
    param(
        [string]$CodexHome,
        [string]$Name,
        [string[]]$Ids
    )

    $catalogPath = Join-Path $CodexHome "$Name-models.json"
    $sourceFiles = @(
        (Join-Path $CodexHome 'models_cache.json'),
        (Join-Path $CodexHome 'deepseek-models.json'),
        $catalogPath
    )

    $bySlug = @{}
    foreach ($sourceFile in $sourceFiles) {
        if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
            continue
        }
        try {
            $models = @((Get-Content -LiteralPath $sourceFile -Raw -Encoding UTF8 | ConvertFrom-Json).models)
        } catch {
            continue
        }
        foreach ($model in $models) {
            $slug = [string]$model.slug
            if (-not [string]::IsNullOrWhiteSpace($slug) -and -not $bySlug.ContainsKey($slug)) {
                $bySlug[$slug] = $model
            }
        }
    }

    $existing = @{}
    if (Test-Path -LiteralPath $catalogPath -PathType Leaf) {
        try {
            foreach ($model in @((Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json).models)) {
                $slug = [string]$model.slug
                if (-not [string]::IsNullOrWhiteSpace($slug)) {
                    $existing[$slug] = $model
                }
            }
        } catch {
            throw "模型目录 JSON 无法解析：$catalogPath"
        }
    }

    $excluded = @('codex-auto-review')
    $added = @()
    $skipped = @()
    foreach ($id in $Ids) {
        if ($excluded -contains $id) {
            $skipped += [pscustomobject]@{ Id = $id; Reason = '非用户可选模型' }
            continue
        }
        if ($existing.ContainsKey($id)) {
            continue
        }
        if ($bySlug.ContainsKey($id)) {
            $existing[$id] = $bySlug[$id]
            $added += $id
        } else {
            $skipped += [pscustomobject]@{ Id = $id; Reason = '无完整条目（models_cache.json / deepseek-models.json 均无）' }
        }
    }

    $models = @($existing.Values | Sort-Object @{
        Expression = {
            $priorityProperty = $_.PSObject.Properties['priority']
            if ($null -ne $priorityProperty -and $null -ne $priorityProperty.Value) {
                [int]$priorityProperty.Value
            } else {
                0
            }
        }
        Descending = $true
    }, @{ Expression = { [string]$_.slug } })

    if ($added.Count -gt 0 -or -not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
        if (Test-Path -LiteralPath $catalogPath -PathType Leaf) {
            Copy-Item -LiteralPath $catalogPath -Destination "$catalogPath.bak" -Force
        }
        $payload = [pscustomobject]@{ models = @($models) }
        $json = $payload | ConvertTo-Json -Depth 100
        Write-Utf8File -Path $catalogPath -Content $json
    }

    if ($added.Count -gt 0) {
        Write-Output "新增 $($added.Count) 个模型：$($added -join '、')"
    } else {
        Write-Output '没有需要新增的模型。'
    }
    foreach ($item in $skipped) {
        Write-Output "跳过：$($item.Id)（$($item.Reason)）"
    }
    Write-Output "模型目录：$catalogPath（共 $($models.Count) 个）"
    Write-Output "/model 可用模型：$(($models | ForEach-Object { [string]$_.slug }) -join '、')"
}

function Sync-Models {
    param([string]$Name)

    $codexHome = Get-CodexHome
    if ($Name -in @('official', 'default', 'reset', 'restore')) {
        throw '内置 Profile 不需要同步模型。'
    }

    $profilePath = Join-Path $codexHome "$Name.config.toml"
    if (-not (Test-Path -LiteralPath $profilePath -PathType Leaf)) {
        throw "不存在 profile：$Name"
    }

    $baseUrl = Get-TomlValue -Path $profilePath -Key 'base_url'
    if ([string]::IsNullOrWhiteSpace($baseUrl)) {
        throw "Profile $Name 未配置 base_url，请先 codex-switcher edit $Name 填写中转站地址。"
    }

    $key = Get-TomlValue -Path $profilePath -Key 'experimental_bearer_token'
    if (Test-PlaceholderKey -Key $key) {
        $envKeyName = Get-TomlValue -Path $profilePath -Key 'env_key'
        if (-not [string]::IsNullOrWhiteSpace($envKeyName)) {
            $key = [Environment]::GetEnvironmentVariable($envKeyName)
        }
    }
    if (Test-PlaceholderKey -Key $key) {
        throw "Profile $Name 未配置有效 Key（experimental_bearer_token 或 env_key）。"
    }

    $baseUrl = $baseUrl.TrimEnd('/')
    $modelsUrl = "$baseUrl/models"
    Write-Output "正在查询模型列表：$modelsUrl"

    try {
        $webResponse = Invoke-WebRequest -UseBasicParsing -Uri $modelsUrl -Headers @{ Authorization = "Bearer $key" } -TimeoutSec 20
    } catch {
        $status = 0
        if ($_.Exception -is [System.Net.WebException] -and $null -ne $_.Exception.Response) {
            $status = [int]$_.Exception.Response.StatusCode
        }
        if ($status -eq 404) {
            throw "查询 $modelsUrl 失败（HTTP 404）。该中转站未实现 GET /models；本工具要求中转站支持 OpenAI 兼容的 /models 接口。"
        }
        if ($status -eq 401 -or $status -eq 403) {
            throw "查询 $modelsUrl 失败（HTTP $status）。中转站拒绝访问：Key 无效或没有权限，请检查 experimental_bearer_token。"
        }
        if ($status -gt 0) {
            throw "查询 $modelsUrl 失败（HTTP $status）。"
        }
        throw "无法连接 $modelsUrl（网络/代理/DNS）。$($_.Exception.Message)"
    }

    try {
        $webContent = $webResponse.Content
        if ($webContent -is [byte[]]) {
            $jsonText = [System.Text.Encoding]::UTF8.GetString([byte[]]$webContent)
        } else {
            $jsonText = [string]$webContent
        }
        if ($jsonText.Length -gt 0 -and $jsonText[0] -eq [char]0xFEFF) {
            $jsonText = $jsonText.Substring(1)
        }
        $response = $jsonText | ConvertFrom-Json
    } catch {
        throw "无法解析 $modelsUrl 的响应（不是标准 OpenAI /models JSON）。"
    }

    try {
        $ids = @($response.data | Where-Object { $_.id } | ForEach-Object { [string]$_.id })
    } catch {
        throw "无法解析 $modelsUrl 的响应（不是标准 OpenAI /models JSON）。"
    }
    if ($ids.Count -eq 0) {
        throw "$modelsUrl 返回的模型列表为空（data 为空）。"
    }

    Merge-ModelCatalog -CodexHome $codexHome -Name $Name -Ids $ids

    if (-not (Select-String -LiteralPath $profilePath -Pattern '^\s*model_catalog_json\s*=' -Quiet)) {
        Copy-Item -LiteralPath $profilePath -Destination "$profilePath.bak" -Force
        $original = Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8
        $updated = "model_catalog_json = `"$Name-models.json`"`r`n$original"
        Write-Utf8File -Path $profilePath -Content $updated
        Write-Output "已为 $profilePath 补上 model_catalog_json 配置。"
    }
}

function Resolve-EditorPath {
    param([string]$Editor)

    if (Test-Path -LiteralPath $Editor -PathType Leaf) {
        return $Editor
    }
    $cmd = Get-Command $Editor -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $cmd -and -not [string]::IsNullOrWhiteSpace($cmd.Source)) {
        return $cmd.Source
    }
    throw "找不到编辑器 '$Editor'。可设置 CODEX_SWITCHER_EDITOR，或使用 notepad。"
}

function Edit-Profile {
    param([string]$Name)

    $codexHome = Get-CodexHome
    $builtIn = $Name -in @('official', 'default', 'reset', 'restore')
    if ($builtIn) {
        $target = Join-Path $codexHome 'config.toml'
    } else {
        $target = Join-Path $codexHome "$Name.config.toml"
    }
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        throw "找不到配置文件：$target"
    }

    $editor = $env:CODEX_SWITCHER_EDITOR
    if ([string]::IsNullOrWhiteSpace($editor)) {
        $editor = $env:VISUAL
    }
    if ([string]::IsNullOrWhiteSpace($editor)) {
        $editor = $env:EDITOR
    }
    if ([string]::IsNullOrWhiteSpace($editor)) {
        $editor = 'notepad'
    }

    $editorPath = Resolve-EditorPath -Editor $editor
    if ($editorPath -match '\.ps1$') {
        & $editorPath $target
        $exitCode = $LASTEXITCODE
    } else {
        $process = Start-Process -FilePath $editorPath -ArgumentList @($target) -Wait -PassThru
        $exitCode = $process.ExitCode
    }
    if ($exitCode -ne 0) {
        throw "编辑器退出码：$exitCode"
    }
    if (-not $builtIn -and $env:CODEX_SWITCHER_NO_AUTO_SYNC -ne '1') {
        Write-Output '编辑完成，正在同步模型目录...'
        Sync-Models -Name $Name
        Write-Output '模型目录同步完成。'
    }
}

function Remove-Profile {
    param(
        [string]$Name,
        [switch]$Yes
    )

    $codexHome = Get-CodexHome
    $target = Join-Path $codexHome "$Name.config.toml"
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        throw "不存在 profile：$Name"
    }
    if (-not $Yes) {
        $answer = Read-Host "确定删除 profile '$Name'？只删除该 profile，不影响默认配置和 auth.json。[y/N] "
        if ($answer -notmatch '^(y|yes)$') {
            Write-Output '已取消。'
            return
        }
    }
    Remove-Item -LiteralPath $target -Force
    Write-Output "已删除 profile：$Name"
}

function Clear-ProviderEnvironment {
    Remove-Item Env:ANTHROPIC_BASE_URL -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue
    Remove-Item Env:OPENAI_BASE_URL -ErrorAction SilentlyContinue
    Remove-Item Env:OPENAI_API_KEY -ErrorAction SilentlyContinue
}

function Invoke-Official {
    param([string[]]$RemainingArgs)

    $codexHome = Get-CodexHome
    $codexBin = Find-Codex
    Clear-ProviderEnvironment
    Remove-Item Env:CODEX_SWITCHER_HOME -ErrorAction SilentlyContinue
    Remove-Item Env:CODEX_SWITCHER_CODEX_BIN -ErrorAction SilentlyContinue
    Remove-Item Env:CODEX_SWITCHER_VSCODE_BIN -ErrorAction SilentlyContinue
    Remove-Item Env:CODEX_SWITCHER_EDITOR -ErrorAction SilentlyContinue
    Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue
    $env:CODEX_HOME = $codexHome
    Write-Output '已清理第三方 Provider 环境，正在使用官方 OpenAI Codex。'
    & $codexBin -c 'model_provider="openai"' -c 'model="gpt-5.4"' @RemainingArgs
    $global:SwitcherExitCode = $LASTEXITCODE
}

function Invoke-VsCode {
    param([string[]]$CommandArgs)

    if ($CommandArgs.Count -lt 2) {
        throw '请指定供应商，例如：codex-switcher vscode provider-a'
    }

    $codexHome = Get-CodexHome
    $name = $CommandArgs[1]
    Test-ValidName -Name $name
    $builtIn = $name -in @('official', 'default', 'reset', 'restore')

    if ($builtIn) {
        Clear-ProviderEnvironment
        $vscodeHome = $codexHome
    } else {
        Test-ReservedName -Name $name
        $profilePath = Join-Path $codexHome "$name.config.toml"
        if (-not (Test-Path -LiteralPath $profilePath -PathType Leaf)) {
            throw "不存在 profile：$name"
        }
        $vscodeHome = Join-Path $codexHome "codex-switcher-vscode\$name"
        New-Item -ItemType Directory -Force -Path $vscodeHome | Out-Null
        Copy-Item -LiteralPath $profilePath -Destination (Join-Path $vscodeHome 'config.toml') -Force

        $authSource = Join-Path $codexHome 'auth.json'
        $authTarget = Join-Path $vscodeHome 'auth.json'
        if ((Test-Path -LiteralPath $authSource -PathType Leaf) -and -not (Test-Path -LiteralPath $authTarget)) {
            try {
                New-Item -ItemType HardLink -Path $authTarget -Target $authSource | Out-Null
            } catch {
                Copy-Item -LiteralPath $authSource -Destination $authTarget -Force
                Write-Output "警告：无法创建硬链接，已复制 auth.json 到 $authTarget"
            }
        }
    }

    $vscodeBin = Find-VsCode
    if ($CommandArgs.Count -gt 2) {
        $remaining = @($CommandArgs[2..($CommandArgs.Count - 1)])
    } else {
        $remaining = @()
    }
    $isolated = $false
    if ($remaining.Count -gt 0 -and $remaining[0] -eq '--isolated') {
        $isolated = $true
        if ($remaining.Count -gt 1) {
            $remaining = @($remaining[1..($remaining.Count - 1)])
        } else {
            $remaining = @()
        }
    }

    Write-Output "正在启动 VS Code Codex，供应商：$name"
    Write-Output "CODEX_HOME=$vscodeHome"
    Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue
    $env:CODEX_HOME = $vscodeHome
    if ($isolated) {
        $dataHome = Join-Path $codexHome "codex-switcher-vscode-data\$name"
        New-Item -ItemType Directory -Force -Path $dataHome | Out-Null
        Write-Output "使用独立 VS Code 用户数据目录：$dataHome"
        & $vscodeBin --new-window --user-data-dir $dataHome @remaining
    } else {
        & $vscodeBin --new-window @remaining
    }
    $global:SwitcherExitCode = $LASTEXITCODE
}

function Start-Profile {
    param(
        [string]$Name,
        [string[]]$RemainingArgs
    )

    $codexHome = Get-CodexHome
    $codexBin = Find-Codex
    $target = Join-Path $codexHome "$Name.config.toml"
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        throw "不存在 profile：$Name"
    }

    if ($env:CODEX_SWITCHER_NO_AUTO_SYNC -ne '1') {
        $catalogPath = Join-Path $codexHome "$Name-models.json"
        if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
            try {
                Sync-Models -Name $Name
                Write-Output "已自动生成模型目录：$catalogPath"
            } catch {
                Write-Output "警告：模型同步失败，/model 可能不可用；可执行 codex-switcher sync-models $Name 重试。$($_.Exception.Message)"
            }
        }
    }

    Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue
    $env:CODEX_HOME = $codexHome
    & $codexBin --profile $Name @RemainingArgs
    $global:SwitcherExitCode = $LASTEXITCODE
}

function Invoke-InteractiveSelect {
    $codexHome = Get-CodexHome
    $profiles = @(Get-ProfileList -CodexHome $codexHome)
    if ($profiles.Count -eq 0) {
        throw '还没有 profile。先运行：codex-switcher create <名称>'
    }
    Write-Output '选择 Codex profile：'
    for ($i = 0; $i -lt $profiles.Count; $i++) {
        Write-Output ("  {0}) {1}" -f ($i + 1), $profiles[$i])
    }
    $choiceText = Read-Host '编号：'
    $choice = 0
    if (-not [int]::TryParse($choiceText, [ref]$choice) -or $choice -lt 1 -or $choice -gt $profiles.Count) {
        throw '无效选择。'
    }
    Start-Profile -Name $profiles[$choice - 1] -RemainingArgs @()
}

function Show-Usage {
    Write-Output @'
用法：
  codex-switcher                         交互选择 profile 并启动 Codex
  codex-switcher official                使用默认/官方配置启动 Codex
  codex-switcher vscode <名称>           带指定供应商环境启动 VS Code Codex
  codex-switcher list                    列出已有 profile
  codex-switcher create <名称>           创建新的 profile（干净模板，不会复制主配置）
  codex-switcher edit <名称>             用编辑器打开对应 TOML，退出后自动同步模型
  codex-switcher sync-models <名称>      查询中转站 <base_url>/models 并自动生成/合并模型目录
  codex-switcher delete <名称> [--yes]   删除一个 profile（默认需要确认）
  codex-switcher <名称> [Codex参数...]   启动指定 profile

官方回退别名：official、default、reset、restore
所有第三方 Provider（包括 DeepSeek）都走同一个通用流程：
  create 生成干净模板，edit 填写 base_url 与 Key，退出编辑或执行 sync-models 时
  自动查询 <base_url>/models 并生成 <名称>-models.json，/model 直接切换该中转站
  支持的所有模型（只增不减、自动备份）。
环境变量：CODEX_SWITCHER_NO_AUTO_SYNC=1 可关闭自动同步，只保留手动 sync-models。
编辑器：优先使用 CODEX_SWITCHER_EDITOR，其次 VISUAL/EDITOR，默认 notepad
profile：<Codex 主目录>/<名称>.config.toml（默认 %USERPROFILE%\.codex，可用 CODEX_SWITCHER_CODEX_HOME 覆盖）
认证文件 %USERPROFILE%\.codex\auth.json 不会被复制、删除或切换。
'@
}

function Invoke-CodexSwitcher {
    param([string[]]$CommandArgs)

    $global:SwitcherExitCode = 0
    try {
        if ($CommandArgs.Count -eq 0) {
            Invoke-InteractiveSelect
            return
        }

        $command = $CommandArgs[0]
        switch ($command.ToLowerInvariant()) {
            '-h' { Show-Usage; return }
            '--help' { Show-Usage; return }
            'help' { Show-Usage; return }
            '-v' { Write-Output 'codex-switcher 3.0.0-windows'; return }
            '--version' { Write-Output 'codex-switcher 3.0.0-windows'; return }
            'version' { Write-Output 'codex-switcher 3.0.0-windows'; return }
            'list' {
                $codexHome = Get-CodexHome
                Get-ProfileList -CodexHome $codexHome
                return
            }
            'create' {
                if ($CommandArgs.Count -lt 2) {
                    throw '请指定 profile 名称，例如：codex-switcher create provider-a'
                }
                $name = $CommandArgs[1]
                Test-ValidName -Name $name
                Test-ReservedName -Name $name
                New-ProfileTemplate -Name $name -CodexHome (Get-CodexHome)
                Write-Output "已创建干净模板：$(Join-Path (Get-CodexHome) "$name.config.toml")"
                Write-Output "下一步：codex-switcher edit $name  填写 base_url 与 Key；退出编辑后会自动同步模型目录。"
                return
            }
            'sync-models' {
                if ($CommandArgs.Count -lt 2) {
                    throw '请指定 profile 名称，例如：codex-switcher sync-models provider-a'
                }
                $name = $CommandArgs[1]
                Test-ValidName -Name $name
                Sync-Models -Name $name
                return
            }
            'edit' {
                if ($CommandArgs.Count -lt 2) {
                    throw '请指定 profile 名称，例如：codex-switcher edit provider-a'
                }
                $name = $CommandArgs[1]
                Test-ValidName -Name $name
                Edit-Profile -Name $name
                return
            }
            'delete' {
                if ($CommandArgs.Count -lt 2) {
                    throw '请指定要删除的 profile，例如：codex-switcher delete provider-a'
                }
                $name = $CommandArgs[1]
                $yes = $CommandArgs.Count -gt 2 -and $CommandArgs[2] -eq '--yes'
                if ($name -eq '--yes') {
                    if ($CommandArgs.Count -lt 3) {
                        throw '请指定要删除的 profile。'
                    }
                    $name = $CommandArgs[2]
                    $yes = $true
                }
                Test-ValidName -Name $name
                Remove-Profile -Name $name -Yes:$yes
                return
            }
            'official' {
                if ($CommandArgs.Count -gt 1) {
                    Invoke-Official -RemainingArgs @($CommandArgs[1..($CommandArgs.Count - 1)])
                } else {
                    Invoke-Official -RemainingArgs @()
                }
                return
            }
            'default' {
                if ($CommandArgs.Count -gt 1) {
                    Invoke-Official -RemainingArgs @($CommandArgs[1..($CommandArgs.Count - 1)])
                } else {
                    Invoke-Official -RemainingArgs @()
                }
                return
            }
            'reset' {
                if ($CommandArgs.Count -gt 1) {
                    Invoke-Official -RemainingArgs @($CommandArgs[1..($CommandArgs.Count - 1)])
                } else {
                    Invoke-Official -RemainingArgs @()
                }
                return
            }
            'restore' {
                if ($CommandArgs.Count -gt 1) {
                    Invoke-Official -RemainingArgs @($CommandArgs[1..($CommandArgs.Count - 1)])
                } else {
                    Invoke-Official -RemainingArgs @()
                }
                return
            }
            'vscode' {
                Invoke-VsCode -CommandArgs $CommandArgs
                return
            }
            default {
                if ($command.StartsWith('-')) {
                    throw '请先指定 profile 名称；使用 codex-switcher --help 查看用法。'
                }
                $name = $command
                Test-ValidName -Name $name
                Test-ReservedName -Name $name
                if ($CommandArgs.Count -gt 1) {
                    Start-Profile -Name $name -RemainingArgs @($CommandArgs[1..($CommandArgs.Count - 1)])
                } else {
                    Start-Profile -Name $name -RemainingArgs @()
                }
                return
            }
        }
    } catch {
        Write-Output "错误：$($_.Exception.Message)"
        $global:SwitcherExitCode = 1
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-CodexSwitcher -CommandArgs $args
    exit $global:SwitcherExitCode
}
