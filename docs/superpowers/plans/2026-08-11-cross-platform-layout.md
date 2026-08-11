# Cross-Platform Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superjawn:subagent-driven-development (recommended) or superjawn:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Unix and Windows implementations into explicit platform directories while retaining root-level installation commands and replacing duplicated documentation with a concise, task-oriented documentation set.

**Architecture:** Root-level `install` and `uninstall` scripts become compatibility launchers only. POSIX implementation lives in `platforms/unix/`, Windows implementation lives in `platforms/windows/`, and both resolve the repository root from their own file locations to read the shared model asset. Documentation is centralized under `docs/` by reader task instead of colocated with platform code.

**Tech Stack:** POSIX `sh`, PowerShell, Windows `.cmd`, Markdown, Git.

---

## File structure

| Path | Responsibility |
| --- | --- |
| `install.sh`, `uninstall.sh` | Backward-compatible Unix entrypoints; delegate to `platforms/unix/`. |
| `install.ps1`, `uninstall.ps1` | Root-level Windows entrypoints; delegate to `platforms/windows/`. |
| `platforms/unix/bin/codex-switcher` | Existing Linux/macOS command implementation. |
| `platforms/unix/install.sh`, `platforms/unix/uninstall.sh` | Unix installation implementation. |
| `platforms/unix/tests/run-tests.sh` | Characterization test for root Unix install and uninstall commands. |
| `platforms/windows/` | Existing PowerShell implementation, launcher, and tests. |
| `docs/getting-started/` | OS-specific setup, install, update, and uninstall instructions. |
| `docs/guides/` | Platform-neutral operational guides. |
| `docs/development/` | Architecture, test instructions, and roadmap. |

### Task 1: Add a Unix root-entrypoint characterization test

**Files:**
- Create: `platforms/unix/tests/run-tests.sh`
- Test: `platforms/unix/tests/run-tests.sh`

- [ ] **Step 1: Create the test script that exercises the public root commands in isolated temporary paths**

```sh
#!/bin/sh
set -eu

repo_root=$(CDPATH= cd "$(dirname "$0")/../../.." && pwd)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/codex-switcher-unix-test.XXXXXX")
cleanup() { rm -rf "$test_root"; }
trap cleanup EXIT HUP INT TERM

bin_dir="$test_root/bin"
codex_home="$test_root/codex-home"

CODEX_SWITCHER_BIN_DIR="$bin_dir" \
CODEX_SWITCHER_CODEX_HOME="$codex_home" \
CODEX_SWITCHER_NO_PATH=1 \
sh "$repo_root/install.sh"

test -x "$bin_dir/codex-switcher"
test -f "$codex_home/deepseek-models.json"
"$bin_dir/codex-switcher" --help >/dev/null

CODEX_SWITCHER_BIN_DIR="$bin_dir" \
CODEX_SWITCHER_CODEX_HOME="$codex_home" \
sh "$repo_root/uninstall.sh"

test ! -e "$bin_dir/codex-switcher"
test ! -e "$codex_home/deepseek-models.json"
printf '%s\n' 'PASS root Unix install and uninstall entrypoints'
```

- [ ] **Step 2: Mark the script executable and run it before moving Unix code**

Run: `chmod +x platforms/unix/tests/run-tests.sh && sh platforms/unix/tests/run-tests.sh`

Expected: `PASS root Unix install and uninstall entrypoints`.

- [ ] **Step 3: Commit the characterization test**

```text
git add platforms/unix/tests/run-tests.sh
git commit -m "test: cover root unix entrypoints"
```

### Task 2: Move Unix implementation and retain `sh install.sh` compatibility

**Files:**
- Move: `bin/codex-switcher` → `platforms/unix/bin/codex-switcher`
- Move: `install.sh` → `platforms/unix/install.sh`
- Move: `uninstall.sh` → `platforms/unix/uninstall.sh`
- Modify: `install.sh`
- Modify: `uninstall.sh`
- Modify: `platforms/unix/install.sh`
- Test: `platforms/unix/tests/run-tests.sh`

- [ ] **Step 1: Move the Unix files without changing their contents**

Run:

```text
git mv bin platforms/unix/bin
git mv install.sh platforms/unix/install.sh
git mv uninstall.sh platforms/unix/uninstall.sh
```

- [ ] **Step 2: Make the moved installer locate the shared asset from the repository root**

At the top of `platforms/unix/install.sh`, retain the existing `package_dir` expression, add the following root calculation, and replace the asset path with `$repo_root/assets/deepseek-models.json`:

```sh
package_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_root=$(CDPATH= cd "$package_dir/../.." && pwd)
```

```sh
if [ -f "$repo_root/assets/deepseek-models.json" ]; then
```

- [ ] **Step 3: Replace root Shell scripts with forwarding launchers**

`install.sh`:

```sh
#!/bin/sh
set -eu

repo_root=$(CDPATH= cd "$(dirname "$0")" && pwd)
exec sh "$repo_root/platforms/unix/install.sh" "$@"
```

`uninstall.sh`:

```sh
#!/bin/sh
set -eu

repo_root=$(CDPATH= cd "$(dirname "$0")" && pwd)
exec sh "$repo_root/platforms/unix/uninstall.sh" "$@"
```

- [ ] **Step 4: Run syntax checks and the root-entrypoint test**

Run: `sh -n install.sh uninstall.sh platforms/unix/install.sh platforms/unix/uninstall.sh platforms/unix/bin/codex-switcher && sh platforms/unix/tests/run-tests.sh`

Expected: no syntax output and `PASS root Unix install and uninstall entrypoints`.

- [ ] **Step 5: Commit the Unix relocation**

```text
git add install.sh uninstall.sh platforms/unix
git commit -m "refactor: group unix implementation by platform"
```

### Task 3: Move Windows implementation and add root PowerShell launchers

**Files:**
- Move: `windows/` → `platforms/windows/`
- Create: `install.ps1`
- Create: `uninstall.ps1`
- Modify: `platforms/windows/install.ps1`
- Modify: `platforms/windows/tests/run-tests.ps1`
- Modify: `platforms/windows/tests/real-deepseek-test.ps1`
- Test: `platforms/windows/tests/run-tests.ps1`

- [ ] **Step 1: Move the imported Windows implementation into the platform directory**

Run: `Move-Item -LiteralPath windows -Destination platforms/windows`

- [ ] **Step 2: Add PowerShell root launchers that preserve all arguments and exit codes**

Use this exact content for `install.ps1`, with `install.ps1` in the final `Join-Path`:

```powershell
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [object[]]$RemainingArgs
)

$implementation = Join-Path $PSScriptRoot 'platforms\windows\install.ps1'
& $implementation @RemainingArgs
exit $LASTEXITCODE
```

Create `uninstall.ps1` with the same content except its final path is `platforms\windows\uninstall.ps1`.

- [ ] **Step 3: Correct Windows implementation paths after the move**

In `platforms/windows/install.ps1`, set the platform directory and repository root as follows, then use `$platformDir` for the two source command paths:

```powershell
$platformDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $platformDir)
$sourcePs1 = Join-Path $platformDir 'bin\codex-switcher-main.ps1'
$sourceCmd = Join-Path $platformDir 'bin\codex-switcher.cmd'
```

In `platforms/windows/tests/run-tests.ps1`, change the default repository root to `..\..\..`. In `platforms/windows/tests/real-deepseek-test.ps1`, change the command path from `windows\bin\codex-switcher-main.ps1` to `platforms\windows\bin\codex-switcher-main.ps1`.

- [ ] **Step 4: Extend the existing Windows installer test to call the root launcher**

In the existing `install copies files and preserves existing deepseek models` test case, set `$rootInstall = Join-Path $RepoRoot 'install.ps1'` and invoke `$rootInstall` instead of `$script:Install`; retain `-SkipCodex` and the temporary environment variables. This verifies that `install.ps1` accepts and forwards the public switch.

- [ ] **Step 5: Run the Windows test suite and static PowerShell parse checks**

Run:

```text
powershell -NoProfile -Command "[void][scriptblock]::Create((Get-Content -Raw install.ps1)); [void][scriptblock]::Create((Get-Content -Raw uninstall.ps1)); [void][scriptblock]::Create((Get-Content -Raw platforms/windows/install.ps1)); [void][scriptblock]::Create((Get-Content -Raw platforms/windows/uninstall.ps1))"
powershell -NoProfile -ExecutionPolicy Bypass -File .\platforms\windows\tests\run-tests.ps1
```

Expected: parse command exits 0; test suite reports `12 passed, 0 failed` or more with zero failures.

- [ ] **Step 6: Commit the Windows relocation**

```text
git add install.ps1 uninstall.ps1 platforms/windows
git commit -m "refactor: group windows implementation by platform"
```

### Task 4: Replace duplicated documentation with a reader-oriented set

**Files:**
- Modify: `README.md`
- Create: `docs/getting-started/linux.md`
- Create: `docs/getting-started/macos.md`
- Create: `docs/getting-started/windows.md`
- Create: `docs/guides/profiles.md`
- Move: `docs/model-switching.md` → `docs/guides/model-switching.md`
- Create: `docs/guides/vscode.md`
- Create: `docs/guides/troubleshooting.md`
- Create: `docs/development/architecture.md`
- Create: `docs/development/testing.md`
- Create: `docs/development/roadmap.md`
- Delete after content migration: `docs/linux.md`, `docs/windows.md`, `docs/development-plan.md`, `platforms/windows/README.md`, `platforms/windows/docs/development-plan.md`

- [ ] **Step 1: Rewrite `README.md` as a concise project entrypoint**

The README must contain only these sections, in this order: `简介`、`支持平台`、`安装`、`快速开始`、`文档`、`安全与数据`、`开发`。 Include the exact installation commands:

```sh
# Linux / macOS
sh install.sh
```

```powershell
# Windows
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Its `文档` section must link to all three platform guides, the four user guides, and the three development documents. Keep the command examples to `list`, `create`, `edit`, `sync-models`, a named Profile launch, and `official`.

- [ ] **Step 2: Write short, single-purpose platform guides**

`linux.md` documents prerequisites, `sh install.sh`, update, uninstall, Linux paths, and PATH shell reload. `macos.md` documents the same command plus Python 3, zsh, Intel/Apple Silicon validation status, and macOS-specific prerequisites. `windows.md` documents PowerShell requirements, `install.ps1`, `-InstallCodex`, `-SkipCodex`, user PATH behavior, uninstall, and the execution-policy command.

- [ ] **Step 3: Split common guides by user task**

Move the full model catalogue explanation unchanged to `docs/guides/model-switching.md`. Extract Profile lifecycle, environment variables, and security rules into `profiles.md`; extract VS Code and session behavior into `vscode.md`; extract errors and recovery commands into `troubleshooting.md`. Each guide begins with one-sentence scope and links back to `README.md`.

- [ ] **Step 4: Consolidate maintainer documents**

`architecture.md` records the root-launcher/platform-implementation/assets boundary. `testing.md` lists the Unix and Windows test commands. `roadmap.md` combines the two existing development plans, marks Windows implementation as complete pending release integration, and lists macOS validation as the next platform task.

- [ ] **Step 5: Delete superseded documents only after link migration**

Run:

```text
git rm docs/linux.md docs/windows.md docs/development-plan.md
git rm platforms/windows/README.md platforms/windows/docs/development-plan.md
```

- [ ] **Step 6: Validate Markdown links and old-path references**

Run:

```text
rg -n "\]\((docs/|windows/)|windows/README|docs/(linux|windows|development-plan)\.md" README.md docs platforms
rg -n "占位" README.md docs
```

Expected: neither command prints a stale link, placeholder, or unfinished document marker.

- [ ] **Step 7: Commit the documentation reorganization**

```text
git add README.md docs platforms/windows
git commit -m "docs: organize cross-platform guides"
```

### Task 5: Run final verification and prepare the branch for integration

**Files:**
- Test: `platforms/unix/tests/run-tests.sh`
- Test: `platforms/windows/tests/run-tests.ps1`
- Verify: `README.md`, `docs/`, `platforms/`

- [ ] **Step 1: Run all automated checks from the repository root**

Run:

```text
sh -n install.sh uninstall.sh platforms/unix/install.sh platforms/unix/uninstall.sh platforms/unix/bin/codex-switcher
sh platforms/unix/tests/run-tests.sh
powershell -NoProfile -ExecutionPolicy Bypass -File .\platforms\windows\tests\run-tests.ps1
git diff --check
```

Expected: Unix test prints its PASS line; Windows test has zero failures; Git emits no whitespace errors.

- [ ] **Step 2: Check the final repository structure and documentation surface**

Run:

```text
git status --short
rg --files README.md docs platforms assets install.sh uninstall.sh install.ps1 uninstall.ps1
```

Expected: no `windows/` root directory, no obsolete platform README, and only intended migration changes.

- [ ] **Step 3: Commit any final verification-only fixes**

```text
git add README.md docs platforms assets install.sh uninstall.sh install.ps1 uninstall.ps1 .gitignore
git commit -m "chore: verify cross-platform migration"
```

Skip this commit when `git status --short` is clean after the preceding task commits.

## Self-review

- Spec coverage: Tasks 2 and 3 preserve root install commands and move each implementation; Task 4 implements the complete document information architecture; Task 5 enforces no behavior or link regressions.
- Placeholder scan: the plan contains no unfinished instructions or unnamed paths; every code change and command names an exact target.
- Consistency: every root launcher targets `platforms/unix/` or `platforms/windows/`; Windows tests calculate the repository root with three parent traversals after the move.
