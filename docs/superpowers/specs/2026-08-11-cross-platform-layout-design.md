# 跨平台目录与文档重构设计

## 目标

将目前“Linux 实现在仓库根目录、Windows 实现在 `windows/`”的不对称结构，整理为明确的平台实现层与统一文档层。重构不改变任何现有命令的业务行为。

已确认的兼容承诺：

- Linux 用户继续使用 `sh install.sh` 与 `sh uninstall.sh`。
- macOS 复用 POSIX `sh` 实现，不建立一套重复的 macOS 代码。
- Windows 保留 PowerShell 和 `.cmd` 入口能力。
- README 与其他用户文档须简洁、完整、可按任务快速定位。

## 目标目录

```text
.
├── README.md
├── install.sh
├── uninstall.sh
├── install.ps1
├── uninstall.ps1
├── assets/
│   └── deepseek-models.json
├── platforms/
│   ├── unix/
│   │   ├── bin/codex-switcher
│   │   ├── install.sh
│   │   ├── uninstall.sh
│   │   └── tests/
│   └── windows/
│       ├── bin/codex-switcher-main.ps1
│       ├── bin/codex-switcher.cmd
│       ├── install.ps1
│       ├── uninstall.ps1
│       └── tests/
└── docs/
    ├── getting-started/
    │   ├── linux.md
    │   ├── macos.md
    │   └── windows.md
    ├── guides/
    │   ├── profiles.md
    │   ├── model-switching.md
    │   ├── vscode.md
    │   └── troubleshooting.md
    └── development/
        ├── architecture.md
        ├── testing.md
        └── roadmap.md
```

根目录只放项目元数据和用户可直接执行的安装入口。`platforms/` 放平台实现；`assets/` 放所有平台共同读取的数据；`docs/` 放所有面向用户和维护者的说明。

## 迁移与兼容策略

| 现有路径 | 目标路径 | 处理 |
| --- | --- | --- |
| `bin/codex-switcher` | `platforms/unix/bin/codex-switcher` | 原样迁移，调整资源定位。 |
| `install.sh` | `platforms/unix/install.sh` | 主要逻辑迁移；根目录保留转发脚本。 |
| `uninstall.sh` | `platforms/unix/uninstall.sh` | 主要逻辑迁移；根目录保留转发脚本。 |
| `windows/bin/*` | `platforms/windows/bin/*` | 原样迁移，调整仓库根目录计算。 |
| `windows/install.ps1` | `platforms/windows/install.ps1` | 主要逻辑迁移；新增根目录 PowerShell 转发入口。 |
| `windows/uninstall.ps1` | `platforms/windows/uninstall.ps1` | 主要逻辑迁移；新增根目录 PowerShell 转发入口。 |
| `windows/tests/*` | `platforms/windows/tests/*` | 原样迁移，并更新相对路径。 |

根目录的 Shell 入口只解析自身所在目录，并使用 `exec sh` 转发所有参数给 Unix 实现。PowerShell 入口使用 `$PSScriptRoot` 转发所有参数给 Windows 实现。两类实现都不得依赖调用者当前工作目录。

不抽取跨语言的业务逻辑：Shell 与 PowerShell 的实现语言不同，强行共享函数会增加运行时依赖和维护成本。只共享 `assets/deepseek-models.json` 与面向用户的行为契约。

## 文档信息架构

`README.md` 是唯一首页，仅保留：工具简介、支持系统表、每个平台最短安装命令、核心命令示例、文档导航、安全提示和贡献入口。它不再重复完整的 Profile、模型目录和排障说明。

各类文档的职责如下：

- `getting-started/`：分别解释 Linux、macOS、Windows 的前置条件、安装、更新、卸载及该平台特有问题。
- `guides/`：解释所有平台共享的功能，例如 Profile 管理、模型同步、VS Code 与故障排查。
- `development/`：解释代码边界、测试方法和后续路线，不与用户手册重复。

现有 `docs/linux.md`、`docs/windows.md`、`windows/README.md` 的内容会合并到平台入门指南；两份 development plan 会合并为 `docs/development/roadmap.md`；现有模型目录说明迁移为 `docs/guides/model-switching.md`。

## 实施边界

- 保留 `sh install.sh`、`sh uninstall.sh` 的功能、参数、环境变量和输出语义。
- 保留 Windows 安装、卸载、命令包装、Profile、模型同步与测试行为。
- 所有仓库内链接在迁移后必须有效。
- 不改写用户的 `~/.codex`、`~/.local/bin`、Windows 用户 PATH 或既有 Profile 数据；安装脚本仅继续执行其原有职责。
- 不删除用户已有的未跟踪 Windows 实现；仅将其纳入新的目录结构。

## 验收

1. Linux/macOS：在仓库根目录执行 `sh install.sh` 与 `sh uninstall.sh`，能正确转发到 Unix 实现。
2. Windows：根目录 PowerShell 入口能转发安装和卸载参数；原有 Windows 测试套件通过。
3. 原有命令（`create`、`edit`、`sync-models`、`delete`、`official` 和 Profile 启动）没有行为变更。
4. README 只提供行动导向的概览；平台安装和功能细节可由链接在一个层级内找到。
5. 仓库中不再存在重复且相互矛盾的平台 README 或 development plan。

## Research notes

- GNU Bash 文档说明脚本运行时 `$0` 是脚本文件名，适合让根目录 Shell 兼容入口根据自身位置转发：<https://www.gnu.org/s/bash/manual/html_node/Shell-Scripts.html>。
- Microsoft 文档说明 `$PSScriptRoot` 保存当前脚本所在目录，适合让 PowerShell 兼容入口不受调用目录影响：<https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables>。
- 仓库现状确认 Unix 实现位于根目录，完整 Windows 实现位于未跟踪的 `windows/`；两者仅共享 `assets/deepseek-models.json`，因此按平台归位而非强行合并语言实现。
