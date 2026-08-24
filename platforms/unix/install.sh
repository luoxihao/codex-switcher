#!/bin/sh
set -eu

package_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_root=$(CDPATH= cd "$package_dir/../.." && pwd)
bin_dir=${CODEX_SWITCHER_BIN_DIR:-$HOME/.local/bin}
codex_home_dir=${CODEX_SWITCHER_CODEX_HOME:-$HOME/.codex}

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

if [ -f "$repo_root/assets/deepseek-models.json" ]; then
  mkdir -p "$codex_home_dir"
  if [ -f "$codex_home_dir/deepseek-models.json" ]; then
    echo "已存在 DeepSeek 模型来源目录，保留现有内容不覆盖：$codex_home_dir/deepseek-models.json"
  else
    install -m 0600 "$repo_root/assets/deepseek-models.json" \
      "$codex_home_dir/deepseek-models.json"
    echo "已安装 DeepSeek 模型来源目录：$codex_home_dir/deepseek-models.json"
  fi
fi

add_path=1
[ "${CODEX_SWITCHER_NO_PATH:-0}" = "1" ] && add_path=0

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

if [ "$add_path" -eq 1 ]; then
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

if [ "${CODEX_SWITCHER_NO_COMPLETION:-0}" != "1" ]; then
  completions_dir="$HOME/.local/share/codex-switcher/completions"
  mkdir -p "$completions_dir"
  install -m 0644 "$package_dir/completions/codex-switcher.bash" "$completions_dir/codex-switcher.bash"
  install -m 0644 "$package_dir/completions/_codex-switcher.zsh" "$completions_dir/_codex-switcher.zsh"
  install -m 0644 "$package_dir/completions/codex-switcher.fish" "$completions_dir/codex-switcher.fish"
  echo "已安装补全文件：$completions_dir"

  case "$shell_name" in
    zsh)
      marker='# codex-switcher completions'
      if ! grep -Fq "$marker" "$rc_file" 2>/dev/null; then
        {
          printf '\n%s\n' "$marker"
          printf 'source "$HOME/.local/share/codex-switcher/completions/_codex-switcher.zsh"\n'
        } >> "$rc_file"
        echo "已在 $rc_file 启用 zsh 补全"
      fi
      ;;
    bash)
      marker='# codex-switcher completions'
      if ! grep -Fq "$marker" "$rc_file" 2>/dev/null; then
        {
          printf '\n%s\n' "$marker"
          printf 'source "$HOME/.local/share/codex-switcher/completions/codex-switcher.bash"\n'
        } >> "$rc_file"
        echo "已在 $rc_file 启用 bash 补全"
      fi
      ;;
  esac

  fish_dir="${XDG_CONFIG_HOME:-$HOME/.config}/fish/completions"
  if command -v fish >/dev/null 2>&1 || [ -d "${XDG_CONFIG_HOME:-$HOME/.config}/fish" ]; then
    mkdir -p "$fish_dir"
    install -m 0644 "$package_dir/completions/codex-switcher.fish" "$fish_dir/codex-switcher.fish"
    echo "已安装 fish 补全：$fish_dir/codex-switcher.fish"
  fi
fi

if [ "${CODEX_SWITCHER_MENU_COMPLETE:-0}" = "1" ]; then
  marker='# codex-switcher menu-complete'
  case "$shell_name" in
    zsh)
      if ! grep -Fq "$marker" "$rc_file" 2>/dev/null; then
        {
          printf '\n%s\n' "$marker"
          printf 'setopt auto_menu\n'
          printf "zstyle ':completion:*' menu select\n"
        } >> "$rc_file"
        echo "已在 $rc_file 启用 zsh Tab 循环补全（menu select）"
      fi
      ;;
    bash)
      if ! grep -Fq "$marker" "$rc_file" 2>/dev/null; then
        {
          printf '\n%s\n' "$marker"
          printf 'bind "\\t":menu-complete\n'
          printf 'bind "\\e[Z":menu-complete-backward\n'
        } >> "$rc_file"
        echo "已在 $rc_file 启用 bash Tab 循环补全（menu-complete）"
      fi
      ;;
  esac
fi

echo "codex-switcher 安装完成：$bin_dir/codex-switcher"
echo "新开一个 bash/zsh 终端，或执行：export PATH=\"$HOME/.local/bin:\$PATH\""
echo "查看帮助：codex-switcher --help"
