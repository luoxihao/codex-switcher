# Linux 指南

> 面向 Linux 用户的安装、更新、卸载、路径与 PATH 说明。返回 [README](../../README.md)。

## 前置条件

- POSIX `sh`
- `python3`（`sync-models` 合并模型目录使用）
- Codex CLI，可通过 `CODEX_SWITCHER_CODEX_BIN` 指定现有可执行文件

## 安装

```sh
sh install.sh
```

自定义目录或跳过 PATH 写入：

```sh
CODEX_SWITCHER_BIN_DIR=/opt/tools CODEX_SWITCHER_NO_PATH=1 sh install.sh
```

## 更新

重新执行安装命令即可覆盖旧命令，不会覆盖已有用户数据：

```sh
sh install.sh
```

## 卸载

```sh
sh uninstall.sh
```

卸载删除安装的命令和 PATH 配置，保留 Profile、`auth.json`、`config.toml` 与 `deepseek-models.json`。

## 路径与 PATH

- 命令安装到 `~/.local/bin/codex-switcher`，默认加入 `~/.bashrc`、`~/.bash_profile` 或 `~/.profile`。
- 数据目录默认是 `~/.codex`，可用 `CODEX_SWITCHER_CODEX_HOME` 覆盖。
- 安装后重开终端，或执行 `export PATH="$HOME/.local/bin:$PATH"`。

## 会话管理

查看本地会话（跨目录，含主题与所属目录）：

```sh
codex-switcher sessions
```

详细说明见 [会话管理指南](../guides/sessions.md)。
