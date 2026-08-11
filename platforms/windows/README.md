# codex-switcher Windows 版

这是 `codex-switcher` 的 Windows 原生实现，放在 `windows/` 子目录中，不修改根目录的 Linux 安装脚本和 `bin/codex-switcher`。

## 与 Linux 版的隔离

- Linux 版继续使用 `install.sh` / `uninstall.sh` / `bin/codex-switcher`，本目录不覆盖这些文件。
- Windows 版默认安装到 `%USERPROFILE%\.local\bin`，Profile 和模型目录使用 `%USERPROFILE%\.codex`，对应 Linux 的 `~/.local/bin` 和 `~/.codex`。
- 两台机器或两个系统互不读写对方的数据目录；同一仓库内 Linux 根目录和 `windows/` 子目录也互不修改。
- 可用 `CODEX_SWITCHER_CODEX_HOME` 把 Windows 数据目录指到任意独立路径。

## 安装

在 `windows/` 目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

如果本机没有 `codex` 命令，想同时下载官方 Codex CLI：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -InstallCodex
```

官方安装器会从 `https://chatgpt.com/codex/install.ps1` 下载并校验 SHA-256，默认安装到 `%LOCALAPPDATA%\Programs\OpenAI\Codex\bin`。

跳过 Codex CLI 安装：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -SkipCodex
```

## 卸载

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

卸载只删除 Windows 版安装的命令和安装器写入的 PATH 记录，保留 Profile TOML、`auth.json`、`config.toml`、`deepseek-models.json` 和 Codex CLI。

## 使用

```powershell
codex-switcher --help
codex-switcher create my-api
codex-switcher edit my-api
codex-switcher sync-models my-api
codex-switcher my-api
codex-switcher official
```

常用环境变量与 Linux 版对齐：

| 变量 | 作用 | 默认值 |
|---|---|---|
| `CODEX_SWITCHER_CODEX_HOME` | Codex 主目录 | `%USERPROFILE%\.codex` |
| `CODEX_SWITCHER_BIN_DIR` | 命令安装目录 | `%USERPROFILE%\.local\bin` |
| `CODEX_SWITCHER_NO_PATH` | 设为 `1` 跳过 PATH 写入 | `0` |
| `CODEX_SWITCHER_NO_AUTO_SYNC` | 设为 `1` 关闭自动同步 | `0` |
| `CODEX_SWITCHER_EDITOR` | 编辑 Profile 的编辑器 | `notepad` |
| `CODEX_SWITCHER_CODEX_BIN` | 指定 Codex 可执行文件 | 自动查找 |
| `CODEX_SWITCHER_VSCODE_BIN` | 指定 VS Code 命令 | 自动查找 |

## 测试

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\run-tests.ps1
```

测试使用临时 `CODEX_SWITCHER_CODEX_HOME`、本地 mock `/models` 服务和 fake Codex，不读写真实 `.codex` 配置。
