# codex-switcher

在官方 OpenAI Codex 与 OpenAI 兼容中转站（第三方 Provider）之间安全切换的轻量命令行工具。

## 简介

- 按中转站当前 `/models` 列表增删 Profile 模型目录，`/model` 可直接切换仍受支持的模型。
- 提供 `create` / `edit` / `delete` / `list`（支持 `--json`）、模型同步与命令行切换（`model`）、环境诊断（`doctor`）、会话管理（列出/删除/重命名/统计）、shell 补全（bash/zsh/fish/PowerShell）、VS Code 集成和强制返回官方。
- API Key 持久保存在本机 Profile TOML，不依赖临时环境变量。

## 支持平台

| 平台 | 安装入口 | 状态 |
| --- | --- | --- |
| Linux | `sh install.sh` | 可用 |
| macOS | `sh install.sh` | POSIX 实现可用，待 Intel / Apple Silicon 真机验证 |
| Windows | `powershell -ExecutionPolicy Bypass -File .\install.ps1` | PowerShell 5.1+ 可用 |

## 安装

Linux / macOS：

```sh
sh install.sh
```

Windows：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Windows 已安装 Codex CLI 时，可跳过 Codex 安装器：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -SkipCodex
```

卸载命令：

```sh
sh uninstall.sh
```

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

## 快速开始

```sh
codex-switcher list
codex-switcher sessions
codex-switcher sessions rm <会话ID>
codex-switcher sessions rename <会话ID> 新主题
codex-switcher stats
codex-switcher doctor
codex-switcher completion bash
codex-switcher create my-api
codex-switcher edit my-api
codex-switcher sync-models my-api
codex-switcher model my-api gpt-5.6-sol
codex-switcher my-api
codex-switcher official
```

## 文档

平台入门：

- [Linux 指南](docs/getting-started/linux.md)
- [macOS 指南](docs/getting-started/macos.md)
- [Windows 指南](docs/getting-started/windows.md)

用户指南：

- [Profile 管理](docs/guides/profiles.md)
- [模型目录与 /model 切换](docs/guides/model-switching.md)
- [会话管理](docs/guides/sessions.md)
- [补全](docs/guides/completion.md)
- [VS Code 与会话](docs/guides/vscode.md)
- [故障排查](docs/guides/troubleshooting.md)

## 参与贡献

- [提交规范](docs/CONTRIBUTING.md)

维护文档：

- [架构](docs/development/architecture.md)
- [测试](docs/development/testing.md)
- [路线图](docs/development/roadmap.md)

## 安全与数据

- API Key 写入 `~/.codex/<名称>.config.toml`（Windows 为 `%USERPROFILE%\.codex`），权限按平台收紧为 600。
- 不要提交或打印 Profile、`auth.json` 或真实 Key。
- 安装和卸载不会覆盖或删除 Profile、`auth.json`、`config.toml`、`deepseek-models.json` 等用户数据。
- `codex-switcher official` 只清理当前进程的第三方 Provider 环境并返回官方 Codex。

## 开发

根目录的安装脚本是兼容入口，实际实现位于 `platforms/unix/` 与 `platforms/windows/`，公共数据位于 `assets/`。测试命令见 [docs/development/testing.md](docs/development/testing.md)。
