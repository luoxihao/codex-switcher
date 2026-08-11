#!/bin/sh
set -eu

repo_root=$(CDPATH= cd "$(dirname "$0")/../../.." && pwd)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/codex-switcher-unix-test.XXXXXX")
cleanup() { rm -rf "$test_root"; }
trap cleanup EXIT HUP INT TERM

test -f "$repo_root/platforms/unix/install.sh"
test -f "$repo_root/platforms/unix/uninstall.sh"
test -f "$repo_root/platforms/unix/bin/codex-switcher"

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
