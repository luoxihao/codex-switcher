# 补全

> 本文说明 `codex-switcher` 的 shell 补全（bash / zsh / fish / PowerShell）。返回 [README](../../README.md)。

## 启用方式

安装时自动启用：

- Linux/macOS：`sh install.sh` 会把补全写入检测到的默认 shell（bash → `~/.bashrc`，zsh → `~/.zshrc`，fish → fish completions 目录），补全文件安装到 `~/.local/share/codex-switcher/completions/`。
- Windows：`install.ps1` 会把补全注册进 PowerShell `$PROFILE`，补全文件安装到 `%LOCALAPPDATA%\codex-switcher\completions\`。

装完新开一个终端即可用 Tab 补全。已打开的旧终端需要重开，或手动 `source` 对应 rc 文件。

## 补全内容

| 场景 | 补全 |
| --- | --- |
| 顶层 | 命令、`-h/--help/-V/--version`、profile 名称 |
| `edit` / `sync-models` / `vscode` | profile 名称 |
| `delete` / `remove` / `rm` | profile 名称、`--yes` |
| `vscode <名称>` | `--isolated` |
| `sessions` | `remove`、`rm` |
| `sessions remove|rm` | 会话 ID（zsh / fish / PowerShell 带主题提示） |
| `completion` | `bash`、`zsh`、`fish`、`powershell` |

主题提示取会话的第一条用户消息或 Codex 自定义会话名（`*.jsonl.name`）；bash 不支持描述，只显示会话 ID。

## 手动启用

`codex-switcher completion <shell>` 会打印补全脚本，用于未自动启用的场景（例如安装后更换了 shell）：

```sh
codex-switcher completion bash
codex-switcher completion zsh
codex-switcher completion fish
```

PowerShell：

```powershell
codex-switcher completion powershell
```

zsh 手动启用需要已加载 compinit（`autoload -U compinit && compinit`）。

## 禁用

- 安装时跳过补全：`CODEX_SWITCHER_NO_COMPLETION=1 sh install.sh`（Windows 同理）。
- 删除 rc 文件 / `$PROFILE` 中以 `# codex-switcher completions` 标记的段落，或执行 `sh uninstall.sh` / `uninstall.ps1` 一并清理。

## Tab 循环候选（可选）

默认补全行为是“第一下 Tab 补公共前缀、再按列出候选”。想要“连续 Tab 在候选间循环”，安装时开启：

```sh
CODEX_SWITCHER_MENU_COMPLETE=1 sh install.sh
```

Windows：

```powershell
$env:CODEX_SWITCHER_MENU_COMPLETE='1'; .\install.ps1 -SkipCodex
```

效果：

- bash：每次 Tab 循环到下一个候选，`Shift+Tab` 反向循环（写入 `~/.bashrc` 的 `bind "\t":menu-complete` 等）。
- zsh：第一次 Tab 弹出候选菜单，再按 Tab 循环、方向键选择（写入 `~/.zshrc` 的 `setopt auto_menu` 与 `zstyle ':completion:*' menu select`）。
- PowerShell：Tab 使用 PSReadLine `MenuComplete`（写入 `$PROFILE` 的 `Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete`）。

注意：bash 的绑定对 readline 全局生效，所有命令的 Tab 都会变成循环；zsh 的 `menu select` 同样全局生效但只影响有候选时的行为。卸载时 `sh uninstall.sh` / `uninstall.ps1` 会自动移除这些标记段。
