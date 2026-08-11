# 模型目录与 `/model` 切换

> 本文记录「API（中转站）支持多个模型，但 Codex CLI 里 `/model` 切不了」的完整实现与排查过程。

> [!IMPORTANT]
> **前置要求（支持范围）**：本工具（codex-switcher）只支持 OpenAI 兼容中转站——中转站必须实现：
> - `GET /v1/models`：查询模型列表（`sync-models` 依赖它自动发现模型）；
> - `POST /v1/responses`：Responses API（Codex CLI 的 `wire_api = "responses"` 依赖它）。
>
> 只提供 `/v1/chat/completions` 或没有 `/models` 接口的中转站无法直接使用本工具。

## 现象

- 中转站 API 实际支持多个模型（例如 `gpt-5.5`、`gpt-5.6-sol`、`gpt-5.6-terra`、`gpt-5.6-luna`）。
- 但 Codex 会话里输入 `/model`，只能看到 / 切到默认的 `gpt-5.5`，其余模型「不存在」。

## 原因

Codex CLI 的 `/model`（以及 `codex models`）只列出 **模型目录**（`model_catalog_json`）里登记的模型：

- 每个 Profile 的 TOML 通过 `model_catalog_json = "<名称>-models.json"` 指向自己的模型目录（相对 Codex 主目录，默认 `~/.codex`）。
- 目录里没有登记的模型，即使中转站 API 支持，也无法在 `/model` 里选择。

## 涉及的文件与目录结构

```text
~/.codex/                          # Codex 主目录（codex-switcher 默认）
├── codex-5288.config.toml        # Profile TOML：codex-switcher codex-5288 实际执行 codex --profile codex-5288
├── codex-5288-models.json        # 该 Profile 的模型目录：model_catalog_json 指向的文件（相对 ~/.codex）
├── models_cache.json             # 本机官方模型缓存：模型条目的来源（只读参考，不修改）
├── auth.json                     # 登录 / Key（与本文无关，不要动）
└── config.toml                   # 官方默认配置（与本文无关）
```

`codex-switcher` 仓库内（文档）：

```text
~/codex-switcher/
└── docs/
    └── model-switching.md        # 本文
```

## 自动同步：添加 API 后工具做了什么

本工具已内置自动发现与配置，添加中转站后不需要手工复制条目：

```text
codex-switcher create my-api       # 生成干净模板（含 model_catalog_json = "my-api-models.json"）
codex-switcher edit my-api         # 填 base_url + Key，退出后自动 sync-models
   └─ 查询 <base_url>/models → 匹配完整条目 → 合并进 my-api-models.json（只增不减、备份 .bak、权限 600）
codex-switcher my-api              # 启动；模型目录不存在时才自动同步一次（不每次同步）
```

- 完整条目来源（按顺序查找）：`~/.codex/models_cache.json`（官方模型缓存）、`~/.codex/deepseek-models.json`（DeepSeek 模型来源目录）、现有模型目录（保留手工加的条目）。
- 判定「哪些模型能用」：`/models` 返回的 ID 能在上述来源里匹配到完整条目即登记；`codex-auto-review` 等非用户可选模型跳过；匹配不到的中转站别名/旧模型跳过并在终端列出。
- `CODEX_SWITCHER_NO_AUTO_SYNC=1` 关闭自动同步，只保留手动 `codex-switcher sync-models <名称>`。
- 下面的「手工操作步骤」是自动同步不可用（例如中转站没有 `/models`）时的兜底方法。

## Profile TOML 内容（`~/.codex/codex-5288.config.toml`）

```toml
model_provider = "OpenAI"
model = "gpt-5.5"                    # 默认模型（/model 只改当前会话，不改这里）
review_model = "gpt-5.5"             # 自动 review 用模型，独立于 /model
model_reasoning_effort = "xhigh"
disable_response_storage = true
network_access = "enabled"
windows_wsl_setup_acknowledged = true
model_catalog_json = "codex-5288-models.json"   # ← /model 能列出哪些模型，由这个文件决定

[model_providers.OpenAI]
name = "OpenAI"
base_url = "https://api.the5288.com/v1"   # ← 你的中转站地址（示例；别的中转站换成自己的）
wire_api = "responses"
requires_openai_auth = true
experimental_bearer_token = "<你的Key>"

[features]
goals = true

[projects."/path/to/your/project"]
trust_level = "trusted"
```

关键字段：

| 字段 | 作用 |
|---|---|
| `model` | 启动时的默认模型 |
| `review_model` | 自动 review 用的模型 |
| `model_catalog_json` | `/model` 与 `codex models` 读取的模型目录文件名（相对 `~/.codex`） |
| `[model_providers.<名>].base_url` | 中转站 API 根地址，查模型列表时用它拼 `/models` |
| `experimental_bearer_token` | 中转站 Key（权限 600，不要提交/打印） |

## 模型目录内容（`~/.codex/codex-5288-models.json`）

顶层结构固定为 `{"models": [...]}`，每个元素是一个完整模型条目。

### 修改前：只有 gpt-5.5

```json
{
  "models": [
    {
      "slug": "gpt-5.5",
      "display_name": "GPT-5.5",
      "description": "Frontier model for complex coding, research, and real-world work.",
      "default_reasoning_level": "medium",
      "supported_reasoning_levels": [
        { "effort": "low", "description": "Fast responses with lighter reasoning" },
        { "effort": "medium", "description": "Balances speed and reasoning depth for everyday tasks" },
        { "effort": "high", "description": "Greater reasoning depth for complex problems" },
        { "effort": "xhigh", "description": "Extra high reasoning depth for complex problems" }
      ],
      "shell_type": "shell_command",
      "visibility": "list",
      "supported_in_api": true,
      "priority": 7,
      "additional_speed_tiers": ["fast"],
      "service_tiers": [
        { "id": "priority", "name": "Fast", "description": "1.5x speed, increased usage" }
      ],
      "base_instructions": "You are Codex, a coding agent based on GPT-5. ...（长文本，从 models_cache.json 原样复制）",
      "context_window": 272000,
      "max_context_window": 272000,
      "supports_parallel_tool_calls": true,
      "input_modalities": ["text", "image"],
      "supports_search_tool": true,
      "truncation_policy": { "mode": "tokens", "limit": 10000 },
      "effective_context_window_percent": 95
    }
  ]
}
```

### 修改后：加入 5.6 系列

往 `models` 数组里追加 `gpt-5.6-sol`、`gpt-5.6-terra`、`gpt-5.6-luna` 三个条目。新条目以 `gpt-5.6-sol` 为例：

```json
{
  "slug": "gpt-5.6-sol",
  "display_name": "GPT-5.6-Sol",
  "description": "Latest frontier agentic coding model.",
  "default_reasoning_level": "low",
  "supported_reasoning_levels": [
    { "effort": "low", "description": "Fast responses with lighter reasoning" },
    { "effort": "medium", "description": "Balances speed and reasoning depth for everyday tasks" },
    { "effort": "high", "description": "Greater reasoning depth for complex problems" },
    { "effort": "xhigh", "description": "Extra high reasoning depth for complex problems" },
    { "effort": "max", "description": "Maximum reasoning depth for the hardest problems" },
    { "effort": "ultra", "description": "Maximum reasoning with automatic task delegation" }
  ],
  "shell_type": "shell_command",
  "visibility": "list",
  "supported_in_api": true,
  "priority": 1,
  "additional_speed_tiers": ["fast"],
  "service_tiers": [
    { "id": "priority", "name": "Fast", "description": "1.5x speed, increased usage" }
  ],
  "base_instructions": "You are Codex, an agent based on GPT-5. ...（长文本，从 models_cache.json 原样复制）",
  "context_window": 272000,
  "max_context_window": 272000,
  "supports_parallel_tool_calls": true,
  "input_modalities": ["text", "image"],
  "supports_search_tool": true,
  "truncation_policy": { "mode": "tokens", "limit": 10000 },
  "effective_context_window_percent": 95
}
```

`terra` / `luna` 两个条目结构相同，只有 `slug`、`display_name`、`description`、`default_reasoning_level`、`priority` 等少量字段不同。

### 怎么拿完整条目

不建议手写。本机官方模型缓存 `~/.codex/models_cache.json` 的 `models` 数组里，按 `slug` 找到同名条目，把**整个对象**原样复制进 `codex-5288-models.json` 的 `models` 数组即可（`base_instructions`、`model_messages`、`comp_hash` 等长字段都由缓存提供，改坏会导致该模型提示词异常）。

### 手工操作步骤

1. 备份：`cp ~/.codex/codex-5288-models.json ~/.codex/codex-5288-models.json.bak`
2. 编辑 `~/.codex/codex-5288-models.json`，把缓存里的同名条目整个复制进 `models` 数组。
3. （可选）按 `priority` 从大到小排序，控制 `/model` 展示顺序。
4. 保存后收紧权限：`chmod 600 ~/.codex/codex-5288-models.json`
5. 校验 JSON：`python3 -m json.tool ~/.codex/codex-5288-models.json > /dev/null && echo ok`

## 确认中转站支持哪些模型（通用命令）

不要写死某个中转站域名。`base_url` 从 Profile TOML 的 `[model_providers.<名>].base_url` 取，拼上 `/models`：

```bash
# base_url 示例：https://api.the5288.com/v1
# 若 base_url 以 /v1 结尾，${base_url}/models 就是 /v1/models；
# 有的中转站根路径不带 /v1，直接就是 /models
curl -sS -H "Authorization: Bearer <你的Key>" "${base_url}/models"
```

- 返回 `200` 且 `data[].id` 里有你要的模型 → 该中转站支持查询，`slug` 以这里返回的为准。
- 返回非 `200`（404 / 401 / 403）或 `data` 为空 → 见下一节。

> [!NOTE]
> 部分 Codex 自检（如 `codex doctor` 的连通性检查）会探测 `GET /models`；中转站返回 404 时该项可能提示「端点不可达」，但只要实际调用接口能通，不影响使用。

## 什么情况下中转站能查 `/models`、什么情况下不能

| 中转站形态 | `/models` 表现 | 能否查询 |
|---|---|---|
| 标准 OpenAI 兼容中转（one-api / new-api 等面板常见） | `200` + `data[].id` 完整列表 | ✅ 能 |
| 未实现 `/models` 路由 | `404` | ❌ 不能 |
| 对 `/models` 做鉴权 / 白名单 / 套餐限制 | `401` / `403`，或返回空 `data: []` | ❌ 不能（或查不全） |
| 只代理固定几个模型、不暴露模型列表 | `404` 或空列表 | ❌ 不能 |
| 模型名做了别名映射（返回名 ≠ 上游官方名） | `200`，但 `data[].id` 是别名 | ⚠️ 能查，但 `slug` 必须以它返回的为准 |
| 只兼容 `/v1/chat/completions`，不兼容 Responses API | `/models` 可能正常，但 Codex 实际调用失败 | ⚠️ 能查模型，但 `wire_api="responses"` 接不上；本工具不支持，需要第三方协议转换层 |

**能查**：按上一节的命令拿到 `data[].id`，把要用的模型补进模型目录，`/model` 即可切换。

**查不了（404 / 401 / 403 / 空列表）怎么办**：

1. 去中转站文档 / 客服确认它支持的模型 ID 列表。
2. 或者直接拿疑似 ID 试一次真实请求，通了就说明该 ID 可用：

```bash
curl -sS -H "Authorization: Bearer <你的Key>" "${base_url}/responses" \
  -d '{"model":"gpt-5.6-sol","input":"hi"}' | head -c 500
```

3. 确认可用的 ID 照样补进模型目录。**`/model` 能不能选只取决于模型目录里有没有登记，与 `/models` 能不能查无关**。

## 重启并验证

```bash
codex-switcher codex-5288
```

进入会话后输入 `/model`，应能看到并切换：

```text
gpt-5.5        GPT-5.5
gpt-5.6-sol    GPT-5.6-Sol
gpt-5.6-terra  GPT-5.6-Terra
gpt-5.6-luna   GPT-5.6-Luna
```

## 注意事项

- `/model` 切换只对**当前会话**生效，不会改 Profile TOML 里的默认 `model`。
- 想让某个模型成为默认，改 Profile TOML：

  ```toml
  model = "gpt-5.6-sol"
  review_model = "gpt-5.6-sol"
  ```

- `review_model`（自动 review 用的模型）**不会**跟随 `/model` 切换，需要时单独在 TOML 里修改。
- `slug` 必须与中转站实际接受的模型 ID 完全一致（以它 `/models` 返回或文档为准），否则切换后请求会 404 / 报模型不存在。
- 模型目录 JSON 属于用户数据，不入库；中转站后续新增模型时，按「手工操作步骤」补条目即可。
- 回退：删除多余的模型条目，或恢复 `codex-5288-models.json.bak` 备份。
