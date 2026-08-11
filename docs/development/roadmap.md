# 路线图

> 维护者文档：记录平台状态与下一步。返回 [README](../../README.md)。

## 状态

| 平台 | 状态 |
| --- | --- |
| Linux | 已完成并测试 |
| Windows | 实现和自动化测试已完成，待发布集成 |
| macOS | POSIX 实现可复用，待 Intel / Apple Silicon 真机验证 |

## 已交付

- 根目录安装入口兼容 Linux/macOS `sh install.sh` 与 Windows PowerShell 入口。
- Unix 与 Windows 实现迁移到 `platforms/`。
- Windows 支持 `create`、`edit`、`sync-models`、`delete`、`official`、`vscode` 与 Profile 启动。
- 文档按读者任务重组，README 只保留入口概览。

## 下一步

1. 完成发布集成，把 Windows 实现纳入发布产物或发布检查。
2. 在 Intel 和 Apple Silicon macOS 上验证安装、`sync-models`、`/model` 切换。
3. 根据真机结果补充 macOS 已知问题和安装说明。

## 平台验收标准

- 每个平台跑通 `create` → `edit`（填写 base_url + Key）→ 自动同步模型目录 → `/model` 可列出并切换模型。
- `CODEX_SWITCHER_NO_AUTO_SYNC=1` 能关闭自动同步。
- 关键错误（404 / 401 / 空列表 / 无完整条目）有明确提示。
