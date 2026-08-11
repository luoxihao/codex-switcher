# codex-switcher

在官方 OpenAI Codex 与 OpenAI 兼容中转站 / 第三方 Provider 之间安全切换的命令行包装器。

`codex-switcher` 本身是 Codex CLI 的一层薄封装：它按 Profile 准备环境（模型目录、API Key），再以 `codex --profile <name>` 启动。添加 OpenAI 兼容中转站后，工具会自动查询它的 `/models` 并生成模型目录，让 `/model` 直接切换该中转站支持的所有模型。

> [!IMPORTANT]
> **支持范围（前置要求）**：本工具只支持 OpenAI 兼容中转站——中转站必须实现 `GET /v1/models`（查询模型列表）与 `POST /v1/responses`（Responses API）。
> - 只提供 `/v1/chat/completions`、没有 Responses API 的中转站**无法直接使用**本工具。
> - 没有实现 `/models` 接口的中转站无法自动发现模型，需要按 [模型目录与 /model 切换](#模型目录与-model-切换) 手工配置。

> [!TIP]
> 相关项目：[proxy-switcher](../proxy-switcher) 提供 Linux 桌面的统一代理切换，两者可以配合使用。

## 目录

- [特性](#特性)
- [环境要求](#环境要求)
- [快速开始](#快速开始)
- [安装 / 更新 / 卸载](#安装--更新--卸载)
- [工作原理](#工作原理)
- [使用](#使用)
- [配置 DeepSeek Key](#配置-deepseek-key)
- [启动与恢复会话](#启动与恢复会话)
- [Codex 命令兼容性](#codex-命令兼容性)
- [Profile 管理](#profile-管理)
- [模型目录与 /model 切换](#模型目录与-model-切换)
- [VS Code](#vs-code)
- [强制返回官方](#强制返回官方)
- [环境变量参考](#环境变量参考)
- [故障排查](#故障排查)
- [文件结构](#文件结构)
- [迁移到其他机器](#迁移到其他机器)
- [安全说明](#安全说明)
- [参考资料](#参考资料)

## 特性

- 官方 Codex、DeepSeek 官方直连、以及任意 OpenAI 兼容中转站 Profile 一键切换。
- 添加 API 后自动配置全部可用模型：`create` 生成干净模板，`edit` 退出后自动查询中转站 `/models` 并生成模型目录，`/model` 可直接切换。
- API Key 持久化写入 Profile TOML（权限 600），不依赖临时环境变量。
- 支持会话恢复（`resume`）、分叉（`fork`）、归档（`archive`）等 Codex 常用命令透传。
- 提供 VS Code 集成，让 VS Code 内嵌 Codex 使用指定 Provider。
- 提供 `install.sh` / `uninstall.sh`，安装、更新、卸载一条命令完成。

## 环境要求

| 依赖 | 说明 |
|---|---|
| Codex CLI | `codex` 命令需在 `PATH` 中，或通过 `CODEX_SWITCHER_CODEX_BIN` 指定路径 |
| POSIX Shell | 安装脚本使用 `sh`，包装器为 POSIX shell 脚本 |
| python3 | `sync-models` 合并模型目录 JSON 需要（多数 Linux 已自带） |
| 编辑器（可选） | 编辑 Profile 时使用 `$EDITOR`，可通过 `CODEX_SWITCHER_EDITOR` 覆盖 |

## 快速开始

把仓库克隆到任意目录（下文以 `~/codex-switcher` 为例），然后安装：

```bash
git clone <仓库地址> ~/codex-switcher
cd ~/codex-switcher
sh install.sh
```

安装完成后：

```bash
# 查看已有哪些 Profile
codex-switcher list

# 启动 DeepSeek 官方直连（推荐）
codex-switcher deepseek-direct-flash
codex-switcher deepseek-direct-pro

# 添加 OpenAI 兼容中转站（示例：创建 → 编辑填 base_url/Key → 自动同步模型）
codex-switcher create my-api
codex-switcher edit my-api

# 恢复最近的 DeepSeek 直连会话
codex-switcher deepseek-direct-flash resume --last

# 强制停止代理并返回官方 Codex
codex-switcher official
```

`deepseek-direct-*` 是预置 Profile 名称；它们对应的 TOML 会在首次编辑 Key 时创建（见[配置 DeepSeek Key](#配置-deepseek-key)）。普通中转站 Profile 用 `create` 生成干净模板（见 [Profile 管理](#profile-管理)）。

## 安装 / 更新 / 卸载

### 安装或更新

```bash
sh ~/codex-switcher/install.sh
```

安装器只写入用户目录，不需要 root：

1. 把 `bin/codex-switcher` 安装到 `~/.local/bin/codex-switcher`。
2. 如果 Codex 主目录下存在 `bin/` 或 `codex-switcher-package/bin/`，同步一份命令过去。
3. 安装 DeepSeek 直连模型目录到 Codex 主目录。
4. 如尚未配置，向 shell 启动文件追加 `~/.local/bin` 的 `PATH`。

不希望修改 shell 配置时：

```bash
CODEX_SWITCHER_NO_PATH=1 sh ~/codex-switcher/install.sh
```

自定义安装目录：

```bash
CODEX_SWITCHER_BIN_DIR=/opt/tools sh ~/codex-switcher/install.sh
```

### 卸载

```bash
sh ~/codex-switcher/uninstall.sh
```

卸载会删除安装的命令与 PATH 配置。**不会删除** Codex 主目录下的 `auth.json`、`config.toml` 或各 Profile TOML（其中包含 API Key，属于用户数据）。

## 工作原理

```mermaid
flowchart LR
    A[终端命令] --> B{启动方式}
    B -->|codex| C[官方 config.toml]
    C --> D[OpenAI Codex]
    B -->|codex-switcher deepseek-direct-flash/pro| E[DeepSeek Direct Profile]
    E --> H[DeepSeek API]
    B -->|codex-switcher my-api| F[OpenAI 兼容中转 Profile]
    F -->|sync-models 查询 /models| G[生成模型目录]
    G --> F
    F --> H2[中转站 API]
    B -->|codex-switcher official| I[清理 Provider 环境]
    I --> D
```

### 作用范围

切换只影响新启动的进程：

- `codex-switcher <名称>` 只影响它启动的 Codex 进程。
- 已经打开的其他 Codex 或 VS Code 会话不会自动切换。
- 关闭第三方 Codex 后，直接运行 `codex` 会使用官方默认配置。
- `codex-switcher official` 会清理第三方 Provider 环境变量。

## 使用

### 常用命令

| 目的 | 命令 |
|---|---|
| 官方 Codex | `codex` |
| DeepSeek Flash 直连 | `codex-switcher deepseek-direct-flash` |
| DeepSeek Pro 直连 | `codex-switcher deepseek-direct-pro` |
| 添加中转站 Profile | `codex-switcher create my-api` + `codex-switcher edit my-api` |
| 同步中转站模型 | `codex-switcher sync-models my-api` |
| 强制返回官方 | `codex-switcher official` |
| 查看 Profile | `codex-switcher list` |
| 查看帮助 | `codex-switcher --help` |
| 查看版本 | `codex-switcher --version` |

不带参数直接运行 `codex-switcher` 会进入 Profile 交互选择。

## 配置 DeepSeek Key

> [!IMPORTANT]
> Key 是持久写入 TOML，不是临时环境变量。保存后关闭终端或重启电脑仍然有效。

### 配置文件位置

Codex 主目录（默认 `~/.codex`）下的 Profile TOML：

```text
~/.codex/deepseek-direct-pro.config.toml
~/.codex/deepseek-direct-flash.config.toml
```

### 编辑 Key

```bash
codex-switcher edit deepseek-direct-flash
codex-switcher edit deepseek-direct-pro
```

直连 Profile 使用：

```toml
[model_providers.deepseek-direct]
name = "DeepSeek Direct"
base_url = "https://api.deepseek.com/"
wire_api = "responses"
requires_openai_auth = false
supports_websockets = false
experimental_bearer_token = "在这里填写真实 DeepSeek API Key"
```

如果使用 Vim：

1. 按 `i` 进入编辑模式。
2. 替换 `experimental_bearer_token` 引号内的内容。
3. 按 `Esc`。
4. 输入 `:wq` 并回车。

> [!NOTE]
> Key 持久写入 TOML。可以填写同一个 DeepSeek Key，也可以填写不同 Key。

> [!WARNING]
> 不要把真实 Key 写进本文档、复制到公共目录或提交到 Git。

### 不需要环境变量

不需要下面的临时写法：

```bash
# 不需要这样启动 DeepSeek
DEEPSEEK_API_KEY='你的密钥' codex-switcher deepseek-direct-flash
```

启动器会从对应 TOML 的 `experimental_bearer_token` 读取 Key，并且不会在终端中打印它。

## 启动与恢复会话

### 启动

```bash
codex-switcher deepseek-direct-flash
codex-switcher deepseek-direct-pro
```

启动器会自动：

1. 检查对应 Profile 和 Key。
2. 对直连 Profile 安装 DeepSeek 模型目录。
3. 使用对应 Profile 启动 Codex。

### 恢复会话

```bash
# 打开会话选择器
codex-switcher deepseek-direct-flash resume
codex-switcher deepseek-direct-pro resume

# 恢复最近一次会话
codex-switcher deepseek-direct-flash resume --last
codex-switcher deepseek-direct-pro resume --last

# 按会话 ID 恢复
codex-switcher deepseek-direct-flash resume <SESSION_ID>
codex-switcher deepseek-direct-pro resume <SESSION_ID>
```

> [!CAUTION]
> 不要用普通 `codex resume` 恢复 DeepSeek 会话。恢复时继续使用创建该会话的原 Profile。

即使中间执行过 `codex-switcher official`，DeepSeek 恢复命令也会重新准备对应直连模型目录。

## Codex 命令兼容性

`codex-switcher <profile> ...` 实际会调用：

```text
codex --profile <profile> ...
```

因此参数会透传给 Codex，但只有 Codex 原生允许搭配 `--profile` 的命令才能使用。

### 支持通过 codex-switcher 运行

| 功能 | 示例 |
|---|---|
| 交互式 Codex | `codex-switcher deepseek-direct-flash` |
| 非交互任务 | `codex-switcher deepseek-direct-flash exec "检查项目"` |
| 非交互任务别名 | `codex-switcher deepseek-direct-flash e "运行测试"` |
| 代码审查 | `codex-switcher deepseek-direct-flash review` |
| 恢复会话 | `codex-switcher deepseek-direct-flash resume --last` |
| 分叉会话 | `codex-switcher deepseek-direct-flash fork --last` |
| 归档会话 | `codex-switcher deepseek-direct-flash archive <SESSION_ID>` |
| 删除会话 | `codex-switcher deepseek-direct-flash delete <SESSION_ID>` |
| 取消归档 | `codex-switcher deepseek-direct-flash unarchive <SESSION_ID>` |
| Codex 沙箱 | `codex-switcher deepseek-direct-flash sandbox --help` |
| MCP 管理 | `codex-switcher deepseek-direct-flash mcp --help` |
| 指定目录 | `codex-switcher deepseek-direct-flash -C /path/to/project` |
| 指定沙箱 | `codex-switcher deepseek-direct-flash --sandbox read-only` |
| Debug prompt-input | `codex-switcher deepseek-direct-flash debug prompt-input --help` |

> [!WARNING]
> `delete` 会永久删除指定会话，使用前确认会话 ID。

### 必须直接使用原生 codex

下面这些属于安装、认证、服务或全局管理，不应通过 Profile 启动：

| 功能 | 正确命令 |
|---|---|
| 登录状态 | `codex login status` |
| 登录/退出 | `codex login` / `codex logout` |
| 安装诊断 | `codex doctor` |
| 更新 Codex | `codex update` |
| 插件管理 | `codex plugin --help` |
| MCP Server | `codex mcp-server` |
| App Server | `codex app-server --help` |
| 远程控制 | `codex remote-control --help` |
| Shell 补全 | `codex completion zsh` |
| 应用最近补丁 | `codex apply` |
| Codex Cloud | `codex cloud --help` |
| 功能开关 | `codex features` |
| Exec Server | `codex exec-server` |
| 其他 Debug | `codex debug --help` |

错误示例：

```bash
codex-switcher deepseek-direct-flash login status
codex-switcher deepseek-direct-flash doctor
codex-switcher deepseek-direct-flash update
```

正确示例：

```bash
codex login status
codex doctor
codex update
```

## Profile 管理

```bash
# 查看
codex-switcher list

# 创建普通第三方 Profile（干净模板）
codex-switcher create provider-a

# 编辑（退出后自动同步该中转站的全部模型）
codex-switcher edit provider-a
CODEX_SWITCHER_EDITOR=nvim codex-switcher edit provider-a

# 手动同步模型目录（查询 <base_url>/models 并合并进 provider-a-models.json）
codex-switcher sync-models provider-a

# 删除（默认要求确认）
codex-switcher delete provider-a

# 跳过确认，谨慎使用
codex-switcher delete provider-a --yes

# 交互选择 Profile
codex-switcher
```

`remove` 和 `rm` 是 `delete` 的别名。删除 Profile 不会删除 `config.toml` 或 `auth.json`。

保留名称：

```text
official default reset restore list create edit delete remove rm sync-models help version
```

`create` 不再复制主配置 `config.toml`，而是生成固定干净模板（避免把 `personality`、`plugins`、`[projects]` 信任目录等脏配置复制进来）：

```toml
model_provider = "openai-proxy"
model = "gpt-5.5"
review_model = "gpt-5.5"
model_reasoning_effort = "xhigh"
disable_response_storage = true
network_access = "enabled"
model_catalog_json = "provider-a-models.json"   # sync-models 自动生成

[model_providers.openai-proxy]
name = "OpenAI 兼容中转"
base_url = "https://你的中转站/v1"                # 必填，改成中转站地址
wire_api = "responses"
requires_openai_auth = true
experimental_bearer_token = "<你的Key>"          # 必填
```

`edit` 退出后自动执行 `sync-models`：查询 `<base_url>/models`，把能匹配到完整条目（来源：`~/.codex/models_cache.json`、`~/.codex/deepseek-direct-models.json`、现有模型目录）的模型合并进 `<名称>-models.json`（只增不减、写前备份 `.bak`、权限 600），并补上缺失的 `model_catalog_json`。启动 Profile 时若模型目录不存在也会自动同步一次；`CODEX_SWITCHER_NO_AUTO_SYNC=1` 可关闭自动同步。

<details>
<summary><strong>其他普通第三方 Provider 配置</strong></summary>

本节不适用于已经配置好的 DeepSeek Direct Profile。

| 类型 | Key 保存方式 |
|---|---|
| DeepSeek Direct | 持久写入 TOML 的 `experimental_bearer_token` |
| 其他普通 Provider | 可直接写 `experimental_bearer_token`，或用 `env_key` + Shell 环境变量（`sync-models` 同样支持） |

Responses API Provider 最小示例：

```toml
model = "some-coder-model"
model_provider = "provider_a"

[model_providers.provider_a]
name = "Provider A"
base_url = "https://api.example.com/v1"
env_key = "PROVIDER_A_API_KEY"
wire_api = "responses"
```

运行：

```bash
PROVIDER_A_API_KEY='你的密钥' codex-switcher provider-a
```

只提供 `/v1/chat/completions`、没有 Responses API 的中转站无法直接使用本工具（见文档开头的「支持范围」）。

</details>

## 模型目录与 `/model` 切换

Codex CLI 的 `/model`（以及 `codex models`）只列出 Profile TOML 里 `model_catalog_json` 指向的模型目录中登记的模型：

```text
~/.codex/<名称>.config.toml        # Profile TOML
model_catalog_json = "<名称>-models.json"   # 模型目录，相对 ~/.codex
```

> [!IMPORTANT]
> API 支持某模型，不等于 `/model` 里能选它。目录里没登记的模型无法在 `/model` 切换。

本工具在添加 API 后自动处理：`create` 生成干净模板 → `edit` 退出（或手动 `sync-models <名称>`）查询中转站 `<base_url>/models`，把能匹配到完整条目（来源：`~/.codex/models_cache.json`、`~/.codex/deepseek-direct-models.json`）的模型合并进 `<名称>-models.json`，`/model` 即可切换。

- `/model` 切换只对当前会话生效；默认模型仍由 TOML 的 `model` 决定。
- `review_model` 不跟随 `/model` 切换，需要单独修改。
- 只增不减：自动同步不会删掉你手工加的模型条目。

> [!NOTE]
> 完整实现与判断「哪些模型能用」的标准见 [docs/model-switching.md](docs/model-switching.md)。

## VS Code

完全退出已有 VS Code 后运行：

```bash
codex-switcher vscode deepseek-direct-pro
codex-switcher vscode deepseek-direct-flash
codex-switcher vscode provider-a
codex-switcher vscode official
```

已有 VS Code 进程可能继续沿用旧环境，因此必须完全退出后重新启动。

独立窗口模式：

```bash
codex-switcher vscode provider-a --isolated
```

独立模式使用单独的 VS Code 用户数据目录，但可能需要重新设置部分 VS Code 偏好。

## 强制返回官方

```bash
codex-switcher official
```

等价别名：

```bash
codex-switcher default
codex-switcher reset
codex-switcher restore
```

官方回退会：

1. 清除第三方 Provider 的 Base URL 和 API Key 环境覆盖。
2. 忽略继承的 `HOME`、`CODEX_HOME` 和 `CODEX_SWITCHER_HOME`。
3. 使用解析出的 Codex 主目录（默认 `~/.codex`，忽略继承的 `CODEX_HOME`，见[迁移到其他机器](#迁移到其他机器)）。
4. 强制 `model_provider="openai"`。
5. 保留 `~/.codex/auth.json` 和现有 ChatGPT 登录。

> [!NOTE]
> 回退已在同时污染 `HOME`、`CODEX_HOME`、`CODEX_SWITCHER_HOME`、`OPENAI_BASE_URL` 和 Provider Key 的情况下验证，最终仍显示官方登录状态。

## 环境变量参考

| 变量 | 作用 | 默认值 |
|---|---|---|
| `CODEX_SWITCHER_BIN_DIR` | 命令安装目录 | `~/.local/bin` |
| `CODEX_SWITCHER_CODEX_HOME` | Codex 主目录（安装脚本与包装器共用） | `~/.codex` |
| `CODEX_SWITCHER_NO_PATH` | 设为 `1` 时跳过 PATH 写入 | `0` |
| `CODEX_SWITCHER_EDITOR` | 编辑 Profile 的编辑器 | `$EDITOR` |
| `CODEX_SWITCHER_CODEX_BIN` | 指定 codex 可执行文件路径 | 自动查找 |
| `CODEX_SWITCHER_VSCODE_BIN` | 指定 VS Code 可执行文件路径 | 自动查找 |
| `CODEX_SWITCHER_DEEPSEEK_MODELS_JSON` | DeepSeek 模型目录 JSON 的来源文件 | 仓库 `assets/` |
| `CODEX_SWITCHER_NO_AUTO_SYNC` | 设为 `1` 时关闭自动同步（edit 退出 / 启动补全），只保留手动 `sync-models` | `0` |

## 故障排查

<details open>
<summary><strong>Key 尚未填写</strong></summary>

```bash
codex-switcher edit deepseek-direct-pro
codex-switcher edit deepseek-direct-flash
```

确认 `experimental_bearer_token` 已保存，但不要在终端打印真实 Key。

</details>

<details>
<summary><strong>DeepSeek 出错</strong></summary>

先安全回到官方：

```bash
codex-switcher official
```

再检查：

```bash
codex login status
codex-switcher --version
codex --version
```

</details>

<details>
<summary><strong>模型同步失败（sync-models）</strong></summary>

```bash
codex-switcher sync-models <名称>
```

终端会给出具体原因：

- `HTTP 404`：中转站未实现 `GET /models`（本工具前置要求），改为向中转站确认模型列表后手工配置。
- `HTTP 401/403`：Key 无效或没有权限，检查 Profile TOML 的 `experimental_bearer_token`。
- 无法连接：检查网络 / 代理 / DNS，确认 `base_url` 可访问。
- 返回空列表 / 模型无完整条目：该中转站模型不在本机模型缓存（`models_cache.json` / `deepseek-direct-models.json`）里，无法自动生成完整条目，需手工添加。

</details>

<details>
<summary><strong>`/model` 看不到 / 切不了某个模型</strong></summary>

原因通常是该模型没有登记在 Profile 的模型目录（`model_catalog_json`）里。参见 [模型目录与 `/model` 切换](#模型目录与-model-切换) 与 [docs/model-switching.md](docs/model-switching.md)。

</details>

## 文件结构

```text
~/codex-switcher/                 # 源码仓库（clone 位置可自定义）
├── README.md
├── install.sh
├── uninstall.sh
├── assets/
│   └── deepseek-direct-models.json
├── bin/
│   └── codex-switcher
└── docs/
    └── model-switching.md          # 模型目录与 /model 切换的实现文档

~/.local/bin/
└── codex-switcher                # 安装后的命令

~/.codex/                         # Codex 主目录（安装目标之一，用户数据）
├── auth.json                     # 官方 ChatGPT 登录
├── config.toml                   # 官方默认配置
├── deepseek-direct-models.json   # DeepSeek 官方直连模型目录
├── deepseek-direct-pro.config.toml
├── deepseek-direct-flash.config.toml
├── codex-5288.config.toml        # 自定义 OpenAI 兼容中转 Profile（示例）
├── codex-5288-models.json        # 该 Profile 的模型目录（sync-models 自动生成，示例）
```

Profile TOML 与 `auth.json` 属于机器相关的用户数据，**不在仓库内**，安装脚本也不会覆盖它们。

## 迁移到其他机器

把项目给其他机器/用户使用时，请注意：

1. **安装脚本已参数化**：`install.sh` 通过 `CODEX_SWITCHER_BIN_DIR`、`CODEX_SWITCHER_CODEX_HOME`、`CODEX_SWITCHER_NO_PATH` 控制安装位置，不需要改代码。
2. **包装器主目录解析**：`bin/codex-switcher` 与 `install.sh` 统一从 `CODEX_SWITCHER_CODEX_HOME` 解析 Codex 主目录，默认 `~/.codex`：

   ```sh
   codex_home=${CODEX_SWITCHER_CODEX_HOME:-$HOME/.codex}
   ```

   继承的 `CODEX_HOME` / `CODEX_SWITCHER_HOME` 被**有意忽略**，防止第三方 Provider 工具污染环境后“强制返回官方”失效；需要自定义主目录时，显式设置 `CODEX_SWITCHER_CODEX_HOME` 即可。

3. **Profile 与 Key 不入库**：DeepSeek Profile TOML、`auth.json` 包含机器相关配置和密钥，换机器后重新编辑填写即可。

## 安全说明

> [!WARNING]
> - 不要提交 API Key、DeepSeek Profile 或 `auth.json`。
> - 不要删除或复制 `auth.json` 来切换 Provider。
> - 安装后的命令默认位于 `~/.local/bin/codex-switcher`，请通过它使用，而不是直接执行仓库里的副本（安装器会处理同步）。
> - 重新安装时使用 `~/codex-switcher/install.sh`，不要手工覆盖 Codex 主目录文件。
> - 删除 Profile 或会话前先确认目标。

Profile 权限：

```text
600 ~/.codex/deepseek-direct-pro.config.toml
600 ~/.codex/deepseek-direct-flash.config.toml
600 ~/.codex/deepseek-direct-models.json
600 ~/.codex/<名称>.config.toml      # 任意普通 Profile
600 ~/.codex/<名称>-models.json      # 自动生成的模型目录
```

## 参考资料

- [Codex 配置参考](https://developers.openai.com/codex/config-reference/)
- [Codex CLI 参考](https://developers.openai.com/codex/cli/reference/)
- [DeepSeek Codex Setup](https://cdn.deepseek.com/api-docs/codex-deepseek-setup.sh)

---

如果不确定当前 Provider 状态，执行：

```bash
codex-switcher official
```
