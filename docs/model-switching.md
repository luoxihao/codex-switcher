# 模型目录与 `/model` 切换

> 本文记录「API 支持多个模型，但 Codex CLI 里 `/model` 切不了」的完整实现与排查过程，
> 以 OpenAI 兼容代理 Profile（codex5288）为具体例子。

## 现象

- API（例如 `api.the5288.com/v1`）的 `/v1/models` 里能看到 `gpt-5.5`、`gpt-5.6-sol`、`gpt-5.6-terra`、`gpt-5.6-luna` 等模型。
- 但在 Codex 会话里输入 `/model`，只能看到 / 切到 `gpt-5.5`，其余模型「不存在」。

## 原因

Codex CLI 的 `/model`（以及 `codex models`）只列出 **模型目录**（`model_catalog_json`）里登记的模型：

- 每个 Profile 的 TOML 通过 `model_catalog_json = "<名称>-models.json"` 指向自己的模型目录（相对 Codex 主目录，默认 `~/.codex`）。
- 目录里没有登记的模型，即使 API 支持，也无法在 `/model` 里选择。
- codex5288 的例子：`~/.codex/codex-5288-models.json` 里只有 `gpt-5.5` 一个条目，所以 `/model` 里没有别的可选。

## 解决思路

把 API 支持、并且希望能在 `/model` 里切换的模型，以**完整条目**的形式合并进对应 Profile 的模型目录 JSON。条目关键字段：

| 字段 | 说明 |
|---|---|
| `slug` | 模型 ID，必须与 API 的模型 ID 完全一致（例如 `gpt-5.6-sol`） |
| `display_name` / `description` | 展示用名称与描述 |
| `default_reasoning_level` / `supported_reasoning_levels` | 推理档位（low/medium/high/xhigh/max/ultra） |
| `supported_in_api` | 必须为 `true` |
| `priority` | `/model` 列表排序权重 |
| `context_window` / `max_context_window` | 上下文窗口 |
| `base_instructions` | 该模型的系统提示词 |

> [!TIP]
> 不建议手写条目。直接从本机官方模型缓存 `~/.codex/models_cache.json` 的 `models` 数组里按 `slug` 复制同名条目，字段完整且不容易出错。

## 具体步骤（以 codex5288 为例）

### 1. 确认 API 支持的模型

```bash
curl -sS -H "Authorization: Bearer <你的Key>" https://api.the5288.com/v1/models
```

在返回的 `data[].id` 里确认 5.5/5.6 系列：`gpt-5.5`、`gpt-5.6-sol`、`gpt-5.6-terra`、`gpt-5.6-luna`。

### 2. 把模型条目合并进 Profile 目录

```python
import copy
import json
import os
import shutil

profile = "codex-5288"                       # 要改的 Profile 名称
codex_home = os.path.expanduser("~/.codex")  # 按实际 Codex 主目录调整
catalog_path = os.path.join(codex_home, f"{profile}-models.json")
cache_path = os.path.join(codex_home, "models_cache.json")
want = ["gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna"]  # 想加入的模型

with open(catalog_path) as f:
    cat = json.load(f)
with open(cache_path) as f:
    cache = json.load(f)

existing = {m["slug"] for m in cat["models"]}
for slug in want:
    if slug in existing:
        continue
    entry = next((m for m in cache["models"] if m["slug"] == slug), None)
    if entry is None:
        raise SystemExit(f"官方缓存里没有 {slug}")
    cat["models"].append(copy.deepcopy(entry))

cat["models"].sort(key=lambda m: m.get("priority", 0), reverse=True)

shutil.copy(catalog_path, catalog_path + ".bak")  # 先备份
with open(catalog_path, "w") as f:
    json.dump(cat, f, ensure_ascii=False, indent=1)
os.chmod(catalog_path, 0o600)                     # 与 Profile TOML 同权限

print("完成：", [m["slug"] for m in cat["models"]])
```

### 3. 重启并验证

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
- 模型 ID 必须与 API 的 `/v1/models` 完全一致，否则切换后请求会 404 / 报模型不存在。
- 模型目录 JSON 属于用户数据，不入库；API 后续新增模型时，把新 slug 加进 `want` 列表重跑即可。
- 回退：删除多余的模型条目，或恢复 `catalog_path + ".bak"` 备份。
