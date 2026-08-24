#!/bin/sh
set -eu

# 一键启用提交规范钩子与模板（.githooks/commit-msg + .gitmessage）
repo_root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
git -C "$repo_root" config core.hooksPath .githooks
git -C "$repo_root" config commit.template .gitmessage
echo "已启用提交规范钩子与模板：$repo_root"
