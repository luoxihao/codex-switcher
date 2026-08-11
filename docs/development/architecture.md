# 架构

> 维护者文档：记录根启动器、平台实现、共享资产和数据边界。返回 [README](../../README.md)。

## 目录边界

```text
.
├── README.md
├── install.sh
├── uninstall.sh
├── install.ps1
├── uninstall.ps1
├── assets/
│   └── deepseek-models.json
├── platforms/
│   ├── unix/
│   │   ├── bin/codex-switcher
│   │   ├── install.sh
│   │   ├── uninstall.sh
│   │   └── tests/
│   └── windows/
│       ├── bin/
│       ├── install.ps1
│       ├── uninstall.ps1
│       └── tests/
└── docs/
```

## 根启动器

- `install.sh` / `uninstall.sh` 是 POSIX 兼容转发入口，解析自身目录后调用 `platforms/unix/`。
- `install.ps1` / `uninstall.ps1` 是 PowerShell 转发入口，使用 `$PSScriptRoot` 调用 `platforms/windows/`。
- 根入口不依赖调用者当前工作目录，并保留公开参数和退出码。

## 平台实现

- `platforms/unix/` 使用 POSIX `sh`，供 Linux/macOS 共用。
- `platforms/windows/` 使用 PowerShell 和 `.cmd` 包装器。
- 不抽取跨语言共享业务逻辑；Shell 与 PowerShell 各自实现相同行为契约。

## 共享资产

`assets/deepseek-models.json` 是唯一跨平台共享数据，由各平台安装器复制到用户 Codex 主目录，不覆盖已有文件。

## 数据边界

安装和卸载只操作命令安装目录、PATH 配置和共享模型来源文件；Profile TOML、`auth.json`、`config.toml` 属于用户数据，安装和卸载均保留。
