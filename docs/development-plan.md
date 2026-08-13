# 开发计划

> 本文件是 codex-switcher 的后续开发计划。当前实现基于 POSIX sh（Linux 已完成），
> 下一步目标是让工具在 Windows 与 macOS 上可用。

## 现状

- Linux 已完成：`create`（干净模板）、`edit`（退出自动同步模型）、`sync-models`
  （查询中转站 `/models` 自动生成模型目录）、`/model` 切换、`official` 回退、
  `sessions`（跨目录列出全部会话，含所属目录）。
- 无 LiteLLM；无 apt 打包发布（已移除）。

## 任务 1：适配 Windows PowerShell

目标：在 Windows 上原生可用（cmd / PowerShell 直接敲 `codex-switcher`）。

- 用 PowerShell 实现 `codex-switcher.ps1`，功能与 sh 版对齐（`create` / `edit` /
  `sync-models` / `delete` / `official` / `sessions` / 启动 Profile）。
- 关键点：
  - 路径：`$env:USERPROFILE\.codex`、`<名称>.config.toml`、`<名称>-models.json`。
  - 调用 Codex：`codex --profile <名称>`（npm 安装的 `codex.cmd`）。
  - 查 `/models`：`Invoke-RestMethod -Headers @{Authorization="Bearer $key"} "$baseUrl/models"`。
  - JSON 合并：`ConvertFrom-Json` / `ConvertTo-Json`，逻辑与 sh 版一致（只增不减、写前备份 `.bak`）。
  - `sessions`：递归遍历 `$env:USERPROFILE\.codex\sessions\**\*.jsonl`，解析每个文件
    `session_meta` 事件 payload 中的 `session_id` / `cwd` / `model_provider` / `timestamp`，
    按时间排序输出与 sh 版一致的表格（日期、会话 ID、Provider、大小、目录）。
  - 环境隔离：`$env:CODEX_HOME` 只对当前进程生效，天然终端级覆盖。
  - 权限：NTFS 上跳过 `chmod`。
- 交付：`bin/codex-switcher.ps1`、`install.ps1` / `uninstall.ps1`、README「Windows」小节。

## 任务 2：适配 macOS

目标：在 macOS 上开箱即用。

- 现状：脚本为 POSIX sh、无 GNU 专属写法（`sed` 仅用 `sed -n 's/.../p'`），
  curl / sed / grep 系统自带，预计基本可用，需真机验证。
- 关键点：
  - 前置：`python3`（`xcode-select --install` 或 `brew install python3`）、
    Codex CLI（npm / 官方安装脚本 / `brew install --cask codex`）。
  - PATH：默认 shell 是 zsh，`install.sh` 会写 `~/.zshrc`，装完重开终端。
  - `find_codex` 已验证覆盖 macOS 的 VSCode 扩展路径。
- 交付：真机（Intel + Apple Silicon）实测 `install.sh`、`sync-models`、`/model` 切换；
  README「macOS」小节。

## 验收标准（两个任务通用）

- 在目标平台上跑通：`create` → `edit`（填 base_url + Key）→ 自动同步模型目录 →
  `/model` 能列出并切换该中转站支持的所有模型。
- `sessions` 能跨目录列出全部会话并显示所属目录，输出与 sh 版一致。
- `CODEX_SWITCHER_NO_AUTO_SYNC=1` 关闭自动同步生效。
- 关键错误（404 / 401 / 空列表 / 无完整条目）有明确提示。
