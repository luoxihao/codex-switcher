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
! grep -Fq '# codex-switcher menu-complete' "$test_home/.bashrc" 2>/dev/null
! grep -Fq '# codex-switcher menu-complete' "$test_home/.zshrc" 2>/dev/null

# 启用 Tab 循环补全（bash 分支）
if [ "$(uname -s)" = "Darwin" ]; then
  bash_rc="$test_home/.bash_profile"
else
  bash_rc="$test_home/.bashrc"
fi
CODEX_SWITCHER_BIN_DIR="$bin_dir" \
CODEX_SWITCHER_CODEX_HOME="$codex_home" \
HOME="$test_home" \
CODEX_SWITCHER_NO_PATH=1 \
CODEX_SWITCHER_MENU_COMPLETE=1 \
SHELL=/bin/bash \
sh "$repo_root/install.sh" >/dev/null
grep -Fq '# codex-switcher menu-complete' "$bash_rc"
grep -Fq 'bind "\t":menu-complete' "$bash_rc"
grep -Fq 'menu-complete-backward' "$bash_rc"

# 启用 Tab 循环补全（zsh 分支）
CODEX_SWITCHER_BIN_DIR="$bin_dir" \
CODEX_SWITCHER_CODEX_HOME="$codex_home" \
HOME="$test_home" \
CODEX_SWITCHER_NO_PATH=1 \
CODEX_SWITCHER_MENU_COMPLETE=1 \
SHELL=/bin/zsh \
sh "$repo_root/install.sh" >/dev/null
grep -Fq '# codex-switcher menu-complete' "$test_home/.zshrc"
grep -Fq 'setopt auto_menu' "$test_home/.zshrc"
grep -Fq "zstyle ':completion:*' menu select" "$test_home/.zshrc"

test "$(CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" __complete | grep -c '^sessions$')" = "1"
test "$(CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" __complete sessions | grep -c '^sessions$')" = "1"
test "$(CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" __complete sessions rm | grep -c '^rm$')" = "1"
test "$(CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" __complete completion powershell | grep -c '^powershell$')" = "1"

mkdir -p "$codex_home/sessions/2026/08/24"
printf '%s\n' 'model = "gpt-5.5"' > "$codex_home/demo.config.toml"

# official：独立代理配置传给 Codex，已有环境变量优先，其他 profile 不受影响。
fake_codex="$test_root/fake-codex"
cat > "$fake_codex" <<'EOF'
#!/bin/sh
printf '%s\n' "${HTTP_PROXY:-}" "${HTTPS_PROXY:-}" "$@" > "$FAKE_CODEX_LOG"
EOF
chmod +x "$fake_codex"
mkdir -p "$test_root/config/codex-switcher"
printf '%s\n' 'http://127.0.0.1:7897' > "$test_root/config/codex-switcher/proxy"
(
  unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy ALL_PROXY all_proxy CODEX_SWITCHER_PROXY
  HOME="$test_home" XDG_CONFIG_HOME="$test_root/config" \
    CODEX_SWITCHER_CODEX_HOME="$codex_home" CODEX_SWITCHER_CODEX_BIN="$fake_codex" \
    FAKE_CODEX_LOG="$test_root/codex-args" \
    "$bin_dir/codex-switcher" official resume test-session >/dev/null
)
test "$(sed -n '1p' "$test_root/codex-args")" = 'http://127.0.0.1:7897'
test "$(sed -n '2p' "$test_root/codex-args")" = 'http://127.0.0.1:7897'
grep -Fxq 'resume' "$test_root/codex-args"
grep -Fxq 'test-session' "$test_root/codex-args"
(
  unset HTTP_PROXY http_proxy https_proxy ALL_PROXY all_proxy CODEX_SWITCHER_PROXY
  HOME="$test_home" XDG_CONFIG_HOME="$test_root/config" HTTPS_PROXY='http://existing:8080' \
    CODEX_SWITCHER_CODEX_HOME="$codex_home" CODEX_SWITCHER_CODEX_BIN="$fake_codex" \
    FAKE_CODEX_LOG="$test_root/codex-args" \
    "$bin_dir/codex-switcher" official >/dev/null
)
test "$(sed -n '1p' "$test_root/codex-args")" = ''
test "$(sed -n '2p' "$test_root/codex-args")" = 'http://existing:8080'
(
  unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy ALL_PROXY all_proxy CODEX_SWITCHER_PROXY
  HOME="$test_home" XDG_CONFIG_HOME="$test_root/config" \
    CODEX_SWITCHER_CODEX_HOME="$codex_home" CODEX_SWITCHER_CODEX_BIN="$fake_codex" \
    CODEX_SWITCHER_NO_AUTO_SYNC=1 FAKE_CODEX_LOG="$test_root/codex-args" \
    "$bin_dir/codex-switcher" demo >/dev/null
)
test "$(sed -n '1p' "$test_root/codex-args")" = ''
test "$(sed -n '2p' "$test_root/codex-args")" = ''

test_sid=019fabc1-2222-3333-4444-555566667777
{
  printf '%s\n' "{\"timestamp\":\"2026-08-24T02:00:00.000Z\",\"type\":\"session_meta\",\"payload\":{\"session_id\":\"$test_sid\",\"id\":\"$test_sid\",\"cwd\":\"/tmp\",\"model_provider\":\"custom\",\"timestamp\":\"2026-08-24T02:00:00.000Z\"}}"
  printf '%s\n' '{"timestamp":"2026-08-24T02:00:01.000Z","type":"event_msg","payload":{"type":"user_message","message":"补全测试主题"}}'
} > "$codex_home/sessions/2026/08/24/rollout-2026-08-24T02-00-00-$test_sid.jsonl"

CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" __complete sessions rm 019 | grep -q "$test_sid"
CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" __complete sessions rm 019 | grep -q '补全测试主题'
CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" __complete edit demo | grep -q '^demo$'
CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" __complete delete demo | grep -q '^--yes$'
test "$(CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" __complete sessions rename | grep -c '^rename$')" = "1"
CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" __complete sessions rename 019 | grep -q "$test_sid"

# sessions rename：设置与清除自定义名称
CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" sessions rename "$test_sid" 新的会话主题
grep -q '^新的会话主题$' "$codex_home/sessions/2026/08/24/rollout-2026-08-24T02-00-00-$test_sid.jsonl.name"
CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" sessions | grep -q '新的会话主题'
CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" sessions rename "$test_sid"
test ! -e "$codex_home/sessions/2026/08/24/rollout-2026-08-24T02-00-00-$test_sid.jsonl.name"

# model 命令：直接切换与交互切换
printf '%s\n' '{"models":[{"slug":"gpt-5.5"},{"slug":"gpt-5.6-sol"}]}' > "$codex_home/demo-models.json"
CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" model demo gpt-5.6-sol
grep -q '^model = "gpt-5.6-sol"' "$codex_home/demo.config.toml"
printf '2\n' | CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" model demo >/dev/null
grep -q '^model = "gpt-5.6-sol"' "$codex_home/demo.config.toml"
printf '1\n' | CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" model demo >/dev/null
grep -q '^model = "gpt-5.5"' "$codex_home/demo.config.toml"
test "$(CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" __complete model demo gpt | grep -c '^gpt-5.6-sol$')" = "1"

# sync-models：按远端列表新增和删除模型，并在变更前备份
sync_bin="$test_root/sync-bin"
mkdir -p "$sync_bin"
{
  printf '%s\n' '#!/bin/sh' 'set -eu'
  printf '%s\n' 'output_file='
  printf '%s\n' 'while [ "$#" -gt 0 ]; do'
  printf '%s\n' '  case "$1" in'
  printf '%s\n' '    -o) output_file=$2; shift 2 ;;'
  printf '%s\n' '    -w) shift 2 ;;'
  printf '%s\n' '    *) shift ;;'
  printf '%s\n' '  esac'
  printf '%s\n' 'done'
  printf '%s\n' 'printf '\''%s\n'\'' '\''{"data":[{"id":"gpt-test"},{"id":"gpt-bundled"},{"id":"unknown-model"}]}'\'' > "$output_file"'
  printf '%s\n' 'printf '\''200'\'''
} > "$sync_bin/curl"
chmod +x "$sync_bin/curl"
{
  printf '%s\n' '#!/bin/sh' 'set -eu'
  printf '%s\n' 'test "$1 $2 $3" = "debug models --bundled"'
  printf '%s\n' 'printf '\''%s\n'\'' '\''{"models":[{"slug":"gpt-bundled","display_name":"GPT Bundled","base_instructions":"test","priority":2}]}'\'''
} > "$sync_bin/codex"
chmod +x "$sync_bin/codex"
printf '%s\n' \
  'model = "gpt-test"' \
  'base_url = "https://api.example.com/v1"' \
  'experimental_bearer_token = "sk-0123456789abcdef"' \
  'model_catalog_json = "demo-models.json"' > "$codex_home/demo.config.toml"
printf '%s\n' '{"models":[{"slug":"gpt-test","display_name":"GPT Test","priority":1}]}' > "$codex_home/models_cache.json"
printf '%s\n' '{"models":[{"slug":"removed-model","display_name":"Removed"}]}' > "$codex_home/demo-models.json"
PATH="$sync_bin:$PATH" CODEX_SWITCHER_CODEX_HOME="$codex_home" \
  CODEX_SWITCHER_CODEX_BIN="$sync_bin/codex" \
  "$bin_dir/codex-switcher" sync-models demo > "$test_root/sync-output.txt"
grep -Fq '新增 2 个模型：gpt-test、gpt-bundled' "$test_root/sync-output.txt"
grep -Fq '删除 1 个远端已下架模型：removed-model' "$test_root/sync-output.txt"
grep -Fq '跳过：unknown-model' "$test_root/sync-output.txt"
grep -Fq '"slug": "gpt-test"' "$codex_home/demo-models.json"
grep -Fq '"slug": "gpt-bundled"' "$codex_home/demo-models.json"
! grep -Fq 'removed-model' "$codex_home/demo-models.json"
grep -Fq 'removed-model' "$codex_home/demo-models.json.bak"

# doctor：完整配置通过、缺配置报问题
printf '%s\n' 'model = "gpt-5.5"' 'base_url = "https://api.example.com/v1"' 'experimental_bearer_token = "sk-0123456789abcdef"' 'model_catalog_json = "demo-models.json"' > "$codex_home/demo.config.toml"
CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" doctor demo >/dev/null
CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" __complete doctor demo | grep -q '^demo$'
printf '%s\n' 'model = "gpt-5.5"' 'experimental_bearer_token = "<你的Key>"' > "$codex_home/demo.config.toml"
if CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" doctor demo >/dev/null 2>&1; then
  echo "doctor 应报告问题并返回非零" >&2
  exit 1
fi

# list --json：机器可读输出
CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" list --json > "$test_root/list.json"
python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
assert isinstance(d, list) and any(p["name"] == "demo" for p in d)
assert all("key_ok" in p and "experimental_bearer_token" not in p for p in d)
' "$test_root/list.json"
test "$(CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" __complete list --json | grep -c '^--json$')" = "1"

# stats：会话统计
CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" stats | grep -q '会话统计'
CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" stats | grep -q 'custom'
CODEX_SWITCHER_CODEX_HOME="$codex_home" "$bin_dir/codex-switcher" __complete stats | grep -q '^stats$'

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
! grep -Fq '# codex-switcher menu-complete' "$test_home/.bashrc" 2>/dev/null
! grep -Fq '# codex-switcher menu-complete' "$test_home/.zshrc" 2>/dev/null
printf '%s\n' 'PASS Unix install, completions and uninstall'
