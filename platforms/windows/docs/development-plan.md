# Windows 版开发计划

## 目标

在 Windows 上提供与 Linux 版对齐的 `codex-switcher`：`create`、`edit`、`sync-models`、`delete`、`official`、`vscode` 和 Profile 启动均可直接使用。

## 目录隔离

- Linux 侧：`install.sh`、`uninstall.sh`、`bin/codex-switcher`、根目录 `README.md` 不修改。
- Windows 侧：所有实现和文档放在 `windows/`：
  - `bin/codex-switcher-main.ps1`：PowerShell 核心命令。
  - `bin/codex-switcher.cmd`：cmd/PowerShell 可直接调用 `codex-switcher` 的入口。
  - `install.ps1` / `uninstall.ps1`：Windows 安装和卸载。
  - `tests/run-tests.ps1`：自动化测试。
  - `README.md`：Windows 使用说明。

## 关键实现

- 默认数据目录：`%USERPROFILE%\.codex`，可通过 `CODEX_SWITCHER_CODEX_HOME` 覆盖。
- 默认命令安装目录：`%USERPROFILE%\.local\bin`，可通过 `CODEX_SWITCHER_BIN_DIR` 覆盖。
- Codex 查找顺序：`CODEX_SWITCHER_CODEX_BIN` → PATH 中的 `codex` → VS Code 扩展内置 Codex。
- `sync-models` 使用 `Invoke-WebRequest` 查询 `/models`，显式 `ConvertFrom-Json`，避免 PowerShell 5.1 对非标准 `Content-Type` 不解析的问题。
- JSON 合并使用 `ConvertTo-Json -Depth 100`，写前保留 `.bak`，只增不减。
- Windows 下不依赖 `chmod`；卸载保留 Profile、Key、`auth.json`、`config.toml`、`deepseek-models.json` 和 Codex CLI。

## 验收

- `windows/tests/run-tests.ps1` 全部通过。
- `install.ps1` 复制命令和模型来源文件，不覆盖已有 `deepseek-models.json`。
- `uninstall.ps1` 删除 Windows 命令，保留用户数据。
- `official --version` 可调用真实 Codex CLI 并清理第三方 Provider 环境变量。
