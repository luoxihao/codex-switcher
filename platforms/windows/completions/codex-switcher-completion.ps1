# PowerShell completion for codex-switcher
# 安装：install.ps1 会自动在 $PROFILE 中注册本文件；手动启用：
#   . <本文件路径>

Register-ArgumentCompleter -CommandName codex-switcher -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $elements = @($commandAst.CommandElements)
    $words = if ($elements.Count -gt 1) {
        @($elements[1..($elements.Count - 1)] | ForEach-Object { $_.ToString() })
    } else {
        @()
    }
    $candidates = & codex-switcher __complete @words 2>$null
    foreach ($line in $candidates) {
        $parts = $line -split "`t", 2
        $cand = $parts[0]
        $desc = if ($parts.Count -gt 1) { $parts[1] } else { '' }
        if ($cand -like "$wordToComplete*") {
            [System.Management.Automation.CompletionResult]::new($cand, $cand, 'ParameterValue', $desc)
        }
    }
}
