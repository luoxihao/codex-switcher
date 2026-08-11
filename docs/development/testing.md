# 测试

> 维护者文档：列出跨平台验证命令。返回 [README](../../README.md)。

## Unix

```sh
sh -n install.sh uninstall.sh platforms/unix/install.sh platforms/unix/uninstall.sh platforms/unix/bin/codex-switcher
sh platforms/unix/tests/run-tests.sh
```

Unix 测试在临时目录中安装、卸载根入口命令，不修改用户数据。

## Windows

```powershell
powershell -NoProfile -Command "[void][scriptblock]::Create((Get-Content -Raw install.ps1)); [void][scriptblock]::Create((Get-Content -Raw uninstall.ps1)); [void][scriptblock]::Create((Get-Content -Raw platforms/windows/install.ps1)); [void][scriptblock]::Create((Get-Content -Raw platforms/windows/uninstall.ps1))"
powershell -NoProfile -ExecutionPolicy Bypass -File .\platforms\windows\tests\run-tests.ps1
```

Windows 测试使用临时 Codex 主目录、本地 mock `/models` 服务和 fake Codex，不读写真实 `.codex` 配置。

## 全量检查

```sh
git diff --check
```

## 可选真实 DeepSeek 测试

`platforms/windows/tests/real-deepseek-test.ps1` 需要 `CODEX_SWITCHER_TEST_DEEPSEEK_KEY`，会访问 DeepSeek 官方 API；默认 CI 不要求运行。
