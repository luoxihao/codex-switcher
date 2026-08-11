# VS Code 与会话

> 本文说明 VS Code 集成、独立窗口模式、会话恢复与直接使用 Codex 的限制。返回 [README](../../README.md)。

## VS Code 集成

完全退出已有 VS Code 后运行：

```sh
codex-switcher vscode my-api
codex-switcher vscode official
```

已有 VS Code 进程可能沿用旧环境，因此必须先退出再启动。

## 独立窗口

```sh
codex-switcher vscode my-api --isolated
```

独立模式使用单独的 VS Code 用户数据目录，可能需要重新设置部分偏好。

## 会话恢复 / 分叉 / 归档

```sh
codex-switcher my-api resume
codex-switcher my-api resume --last
codex-switcher my-api resume <SESSION_ID>
codex-switcher my-api fork --last
codex-switcher my-api archive <SESSION_ID>
```

不要用普通 `codex resume` 恢复第三方 Profile 会话；恢复时会重新准备对应 Profile 的模型目录。

## 直接运行原生 Codex

登录、更新、诊断、插件和服务管理应直接使用原生 Codex：

```sh
codex login status
codex doctor
codex update
codex plugin --help
```

## 环境变量

`CODEX_SWITCHER_VSCODE_BIN` 可指定 VS Code 可执行文件；未设置时自动查找。
