# 会话管理

> 本文说明用 `codex-switcher sessions` 查看与删除本地 Codex 会话。返回 [README](../../README.md)。

## 列出全部会话

`codex-switcher sessions` 跨目录递归扫描 Codex 的 `sessions` 目录（Linux/macOS 默认 `~/.codex/sessions`，Windows 默认 `%USERPROFILE%\.codex\sessions`），按时间列出所有会话：

```sh
codex-switcher sessions
```

输出包含时间、会话 ID、Provider、大小、所属目录和主题，与 `codex resume` 选择器看到的信息一致：

```text
时间                会话 ID                                Provider               大小  目录                       主题
2026-08-03 11:30  019fc5ac-9dd5-7f23-ac4f-f5386ff76590 openai              166KB  /home/lg/develop/dws/backend 检查一下电脑环境
```

## 主题来源

- 默认取会话中第一条真实用户消息，与 `codex resume` 显示的会话标题一致；多行内容会折叠为一行并截断到 60 字符。
- 若会话存在 Codex 自定义会话名（`*.jsonl.name` 旁路文件），优先显示自定义名。
- 找不到主题的会话显示为空。

## 数据位置

- Linux/macOS：`~/.codex/sessions`（可用 `CODEX_SWITCHER_CODEX_HOME` 覆盖）
- Windows：`%USERPROFILE%\.codex\sessions`

`sessions` 只读取会话文件，不会修改 Profile、`auth.json` 或 `config.toml`。

## 删除会话

```sh
codex-switcher sessions remove <会话ID>
codex-switcher sessions rm <会话ID>     # rm 是 remove 的同义命令
```

删除前会显示该会话的主题并二次确认，输入 `y`/`yes` 才删除，其他输入均取消：

```text
会话 019fc5ac-9dd5-7f23-ac4f-f5386ff76590
主题：检查一下电脑环境
确定删除该会话文件？[y/N]
```

- 会话 ID 可以从 `codex-switcher sessions` 输出中复制。
- 删除会话文件时会同时移除对应的 `*.jsonl.name` 自定义名旁路文件。
- 找不到指定 ID 会直接报错，不会删除任何文件。
