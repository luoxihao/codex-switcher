#!/bin/sh
set -eu

package_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
bin_dir=${CODEX_SWITCHER_BIN_DIR:-$HOME/.local/bin}
codex_home_dir=${CODEX_SWITCHER_CODEX_HOME:-${CODEX_HOME:-$HOME/.codex}}

mkdir -p "$bin_dir"
install -m 0755 "$package_dir/bin/codex-switcher" "$bin_dir/codex-switcher"

if [ -d "$codex_home_dir/bin" ]; then
  install -m 0700 "$package_dir/bin/codex-switcher" "$codex_home_dir/bin/codex-switcher"
  echo "已同步 Codex 内部命令：$codex_home_dir/bin/codex-switcher"
fi

if [ -d "$codex_home_dir/codex-switcher-package/bin" ]; then
  install -m 0755 "$package_dir/bin/codex-switcher" \
    "$codex_home_dir/codex-switcher-package/bin/codex-switcher"
  echo "已同步 Codex package 命令：$codex_home_dir/codex-switcher-package/bin/codex-switcher"
fi

if [ -f "$package_dir/assets/deepseek-direct-models.json" ]; then
  mkdir -p "$codex_home_dir"
  install -m 0600 "$package_dir/assets/deepseek-direct-models.json" \
    "$codex_home_dir/deepseek-direct-models.json"
  echo "已安装 DeepSeek 直连模型目录：$codex_home_dir/deepseek-direct-models.json"
fi

add_path=1
[ "${CODEX_SWITCHER_NO_PATH:-0}" = "1" ] && add_path=0

if [ "$add_path" -eq 1 ]; then
  shell_name=${SHELL##*/}
  case "$shell_name" in
    zsh)
      rc_file=$HOME/.zshrc
      ;;
    bash)
      if [ "$(uname -s)" = "Darwin" ]; then
        rc_file=$HOME/.bash_profile
      else
        rc_file=$HOME/.bashrc
      fi
      ;;
    *)
      rc_file=$HOME/.profile
      ;;
  esac

  marker='# codex-switcher user bin'
  if [ ! -f "$rc_file" ]; then
    : > "$rc_file"
  fi
  if ! grep -Fq "$marker" "$rc_file" 2>/dev/null; then
    {
      printf '\n%s\n' "$marker"
      printf 'export PATH="$HOME/.local/bin:$PATH"\n'
    } >> "$rc_file"
    echo "已将 ~/.local/bin 加入 $rc_file"
  fi
fi

echo "codex-switcher 安装完成：$bin_dir/codex-switcher"
echo "新开一个 bash/zsh 终端，或执行：export PATH=\"$HOME/.local/bin:\$PATH\""
echo "查看帮助：codex-switcher --help"
