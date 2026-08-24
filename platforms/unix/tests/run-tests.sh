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
test_home="$test_root/home"
mkdir -p "$test_home"

CODEX_SWITCHER_BIN_DIR="$bin_dir" \
CODEX_SWITCHER_CODEX_HOME="$codex_home" \
HOME="$test_home" \
CODEX_SWITCHER_NO_PATH=1 \
sh "$repo_root/install.sh"

test -x "$bin_dir/codex-switcher"
test -f "$codex_home/deepseek-models.json"
"$bin_dir/codex-switcher" --help >/dev/null

test -f "$test_home/.local/share/codex-switcher/completions/codex-switcher.bash"
test -f "$test_home/.local/share/codex-switcher/completions/_codex-switcher.zsh"
test -f "$test_home/.local/share/codex-switcher/completions/codex-switcher.fish"
if [ "${SHELL##*/}" = "bash" ]; then
  grep -Fq '# codex-switcher completions' "$test_home/.bashrc"
fi

test "$(CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" __complete | grep -c '^sessions$')" = "1"
test "$(CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" __complete sessions | grep -c '^sessions$')" = "1"
test "$(CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" __complete sessions rm | grep -c '^rm$')" = "1"
test "$(CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" __complete completion powershell | grep -c '^powershell$')" = "1"

mkdir -p "$codex_home/sessions/2026/08/24"
printf '%s\n' 'model = "gpt-5.5"' > "$codex_home/demo.config.toml"
test_sid=019fabc1-2222-3333-4444-555566667777
{
  printf '%s\n' "{\"timestamp\":\"2026-08-24T02:00:00.000Z\",\"type\":\"session_meta\",\"payload\":{\"session_id\":\"$test_sid\",\"id\":\"$test_sid\",\"cwd\":\"/tmp\",\"model_provider\":\"custom\",\"timestamp\":\"2026-08-24T02:00:00.000Z\"}}"
  printf '%s\n' '{"timestamp":"2026-08-24T02:00:01.000Z","type":"event_msg","payload":{"type":"user_message","message":"补全测试主题"}}'
} > "$codex_home/sessions/2026/08/24/rollout-2026-08-24T02-00-00-$test_sid.jsonl"

CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" __complete sessions rm 019 | grep -q "$test_sid"
CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" __complete sessions rm 019 | grep -q '补全测试主题'
CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" __complete edit demo | grep -q '^demo$'
CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" __complete delete demo | grep -q '^--yes$'

HOME="$test_home" "$bin_dir/codex-switcher" completion bash | grep -q '_codex_switcher_complete'
HOME="$test_home" "$bin_dir/codex-switcher" completion zsh | grep -q 'compdef'
HOME="$test_home" "$bin_dir/codex-switcher" completion fish | grep -q 'complete -c codex-switcher'

PATH="$bin_dir:$PATH" bash -c '
  source "$1/.local/share/codex-switcher/completions/codex-switcher.bash"
  COMP_WORDS=(codex-switcher sess)
  COMP_CWORD=1
  _codex_switcher_complete
  printf "%s\n" "${COMPREPLY[@]}" | grep -qx sessions
' bash "$test_home"

CODEX_SWITCHER_BIN_DIR="$bin_dir" \
CODEX_SWITCHER_CODEX_HOME="$codex_home" \
HOME="$test_home" \
sh "$repo_root/uninstall.sh"

test ! -e "$bin_dir/codex-switcher"
test ! -e "$codex_home/deepseek-models.json"
test ! -e "$test_home/.local/share/codex-switcher/completions/codex-switcher.bash"
if [ "${SHELL##*/}" = "bash" ]; then
  ! grep -Fq '# codex-switcher completions' "$test_home/.bashrc"
fi
printf '%s\n' 'PASS Unix install, completions and uninstall'
