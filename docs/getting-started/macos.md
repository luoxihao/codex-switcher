# macOS 指南

> 面向 macOS 用户的安装、更新、卸载与验证状态。返回 [README](../../README.md)。

## 前置条件

- Python 3：`xcode-select --install` 或 `brew install python3`
- Codex CLI：`npm install -g @openai/codex`、官方安装脚本或 `brew install --cask codex`
- 默认 shell 为 zsh，安装脚本会写入 `~/.zshrc`

## 安装 / 更新

```sh
sh install.sh
```

## 卸载

```sh
sh uninstall.sh
```

## 路径与 PATH

- 命令安装到 `~/.local/bin/codex-switcher`。
- 数据目录默认是 `~/.codex`。
- 安装后重开终端，或执行 `export PATH="$HOME/.local/bin:$PATH"`。

## 验证状态

POSIX 实现与 Linux 共用。当前尚未在 Intel 与 Apple Silicon 真机上完成验证，安装后建议先跑：

```sh
codex-switcher --version
codex-switcher official
```

## 会话管理

查看本地会话（跨目录，含主题与所属目录）：

```sh
codex-switcher sessions
```

详细说明见 [会话管理指南](../guides/sessions.md)。
