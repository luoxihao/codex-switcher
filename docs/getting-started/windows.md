# Windows 指南

> 面向 Windows 用户的安装、卸载、PATH 与常用命令说明。返回 [README](../../README.md)。

## 前置条件

- Windows PowerShell 5.1 或更高版本
- 用户 PATH 可写（默认安装目录为 `%USERPROFILE%\.local\bin`）
- Codex CLI 可通过 `CODEX_SWITCHER_CODEX_BIN` 指定，或由安装器下载

## 安装

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

同时下载官方 Codex CLI：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -InstallCodex
```

跳过 Codex CLI 安装：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -SkipCodex
```

## 更新

重新执行安装命令即可：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -SkipCodex
```

## 卸载

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

卸载只删除安装的命令和安装器写入的 PATH 记录，保留 Profile、`auth.json`、`config.toml`、`deepseek-models.json` 和 Codex CLI。

## 路径与 PATH

- 命令安装到 `%USERPROFILE%\.local\bin\codex-switcher.cmd`。
- 数据目录默认是 `%USERPROFILE%\.codex`，可用 `CODEX_SWITCHER_CODEX_HOME` 覆盖。
- 安装器会写入用户 PATH；`CODEX_SWITCHER_NO_PATH=1` 可跳过。
- 安装后新开一个 PowerShell 窗口，或执行 `codex-switcher --help`。

## 常用命令

```powershell
codex-switcher create my-api
codex-switcher edit my-api
codex-switcher sync-models my-api
codex-switcher my-api
codex-switcher official
```

## 会话管理

查看本地会话（跨目录，含主题与所属目录）：

```powershell
codex-switcher sessions
codex-switcher sessions rm <会话ID>
```

详细说明见 [会话管理指南](../guides/sessions.md)。
