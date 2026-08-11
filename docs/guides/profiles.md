# Profile 管理

> 本文说明 Profile 的创建、编辑、删除、启动、环境变量与安全规则。返回 [README](../../README.md)。

## 基本流程

| 目的 | 命令 |
| --- | --- |
| 查看 Profile | `codex-switcher list` |
| 创建 Profile | `codex-switcher create my-api` |
| 编辑 Profile | `codex-switcher edit my-api` |
| 手动同步模型 | `codex-switcher sync-models my-api` |
| 启动 Profile | `codex-switcher my-api` |
| 删除 Profile | `codex-switcher delete my-api` |
| 强制返回官方 | `codex-switcher official` |

不带参数运行 `codex-switcher` 会进入 Profile 交互选择。`default`、`reset`、`restore` 是 `official` 的别名。

## 数据位置

- Profile：`<CODEX_SWITCHER_CODEX_HOME>/<名称>.config.toml`
- 模型目录：`<CODEX_SWITCHER_CODEX_HOME>/<名称>-models.json`
- Linux/macOS 默认 `~/.codex`，Windows 默认 `%USERPROFILE%\.codex`

`create` 生成固定干净模板，避免复制主配置中的 `personality`、`plugins` 或项目信任目录：

```toml
model_provider = "openai-proxy"
model = "gpt-5.5"
review_model = "gpt-5.5"
model_reasoning_effort = "xhigh"
disable_response_storage = true
network_access = "enabled"
model_catalog_json = "my-api-models.json"

[model_providers.openai-proxy]
name = "OpenAI 兼容中转"
base_url = "https://你的中转站/v1"
wire_api = "responses"
requires_openai_auth = true
experimental_bearer_token = "<你的Key>"
```

## 编辑与自动同步

`edit` 打开 Profile TOML；退出后自动查询 `<base_url>/models` 并合并模型目录。`CODEX_SWITCHER_NO_AUTO_SYNC=1` 可关闭自动同步，只保留手动 `sync-models`。

## 删除

`delete`、`remove`、`rm` 等价。默认要求确认，跳过确认用 `--yes`：

```sh
codex-switcher delete my-api
codex-switcher delete my-api --yes
```

删除 Profile 不删除 `config.toml` 或 `auth.json`。

## 保留名称

`official default reset restore list create edit delete remove rm sync-models help version` 不能作为 Profile 名。

## 环境变量

| 变量 | 作用 | 默认值 |
| --- | --- | --- |
| `CODEX_SWITCHER_BIN_DIR` | 命令安装目录 | `~/.local/bin` / `%USERPROFILE%\.local\bin` |
| `CODEX_SWITCHER_CODEX_HOME` | Codex 主目录 | `~/.codex` / `%USERPROFILE%\.codex` |
| `CODEX_SWITCHER_NO_PATH` | 设为 `1` 跳过 PATH 写入 | `0` |
| `CODEX_SWITCHER_EDITOR` | Profile 编辑器 | `$EDITOR` / `notepad` |
| `CODEX_SWITCHER_CODEX_BIN` | 指定 codex 可执行文件 | 自动查找 |
| `CODEX_SWITCHER_VSCODE_BIN` | 指定 VS Code 可执行文件 | 自动查找 |
| `CODEX_SWITCHER_NO_AUTO_SYNC` | 设为 `1` 关闭自动同步 | `0` |

## 安全

- Key 持久写入 Profile TOML，不要打印、提交或复制到公共目录。
- Linux/macOS 下 Profile 和模型目录权限为 600。
- 卸载不会删除 Profile、`auth.json`、`config.toml` 或 `deepseek-models.json`。
