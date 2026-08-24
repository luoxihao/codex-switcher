# 提交规范

> 本仓库统一使用 **英文 Conventional 前缀 + 中文描述** 的提交信息格式。返回 [README](../../README.md)。

## 格式

```text
<类型>: <中文描述>
```

示例：

```text
feat: 新增 model 命令
docs: 补充补全指南
fix: 修复安装脚本覆盖已有模型目录的问题
```

## 类型表

| 类型 | 用途 |
| --- | --- |
| `feat` | 新功能 |
| `fix` | 修复缺陷 |
| `docs` | 文档 |
| `refactor` | 重构（不改行为） |
| `test` | 测试 |
| `chore` | 杂项（构建、依赖、配置等） |
| `perf` | 性能优化 |
| `build` | 构建系统 |
| `ci` | CI 配置 |
| `style` | 格式（不影响逻辑） |
| `revert` | 回退 |
| `merge` | 合并分支 |

## 钩子与模板

仓库提供 `.githooks/commit-msg` 校验钩子与 `.gitmessage` 模板，clone 后执行一次即可启用（提交自动校验前缀、编辑器打开模板）：

```sh
sh scripts/install-hooks.sh
```

或手动配置：

```sh
git config core.hooksPath .githooks
git config commit.template .gitmessage
```

`git merge` 的默认提交信息（`Merge branch ...`）不会被钩子拦截；需要自定义时使用 `merge: 描述`。

## CI 校验

仓库自带 `.github/workflows/commit-check.yml`：push 或 PR 时会自动校验范围内所有提交信息的前缀，不符合规范则检查失败（GitHub Actions 默认开启，无需手动配置）。

如需“必须通过检查才能合并”，在 GitHub 仓库 **Settings → Branches** 为 `develop`/`main` 开启分支保护并勾选该检查。

## 历史说明

历史提交已统一改写为上述格式（含 tag `v3.0.0` 与 `main`/`develop` 分支）；改写只修改提交信息，不改变任何代码内容。
