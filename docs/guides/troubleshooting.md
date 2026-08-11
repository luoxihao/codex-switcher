# 故障排查

> 本文按常见症状列出恢复命令。返回 [README](../../README.md)。

## 先回到官方

```sh
codex-switcher official
codex login status
codex doctor
codex-switcher --version
codex --version
```

## Key 尚未填写

```sh
codex-switcher edit my-api
```

确认 Profile TOML 的 `experimental_bearer_token` 已保存，不要打印真实 Key。

## DeepSeek 出错

先安全回到官方，再检查登录、版本与连通性：

```sh
codex-switcher official
codex login status
codex-switcher --version
codex --version
```

## sync-models 失败

```sh
codex-switcher sync-models my-api
```

常见原因：

- HTTP 404：中转站未实现 `GET /models`。
- HTTP 401/403：Key 无效或没有权限。
- 无法连接：检查网络、代理、DNS 和 `base_url`。
- 返回空列表 / 无完整条目：模型不在本机缓存中，需要手工补全模型目录。

## /model 看不到模型

原因是模型没有登记到 Profile 的模型目录。参见 [模型目录与 /model 切换](./model-switching.md)。

## Windows 执行策略

使用 `-ExecutionPolicy Bypass` 运行安装和卸载脚本；正常使用已安装的 `codex-switcher.cmd` 不需要调整策略。
