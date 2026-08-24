#!/bin/sh
set -eu

# codex-switcher 卸载脚本
# 用法: sh uninstall.sh
# 环境变量:
#   CODEX_SWITCHER_BIN_DIR    自定义安装目录（默认 ~/.local/bin）
#   CODEX_SWITCHER_CODEX_HOME Codex 主目录（默认 $HOME/.codex）

bin_dir=${CODEX_SWITCHER_BIN_DIR:-$HOME/.local/bin}
codex_home_dir=${CODEX_SWITCHER_CODEX_HOME:-${CODEX_HOME:-$HOME/.codex}}

# 卸载不删除 ~/.codex 下的 Profile TOML、auth.json、config.toml 等用户数据。
removed=0
for target in \
  "$bin_dir/codex-switcher" \
  "$codex_home_dir/bin/codex-switcher" \
  "$codex_home_dir/codex-switcher-package/bin/codex-switcher" \
  "$codex_home_dir/deepseek-models.json" \
  "$HOME/.local/share/codex-switcher/completions/codex-switcher.bash" \
  "$HOME/.local/share/codex-switcher/completions/_codex-switcher.zsh" \
  "$HOME/.local/share/codex-switcher/completions/codex-switcher.fish" \
  "${XDG_CONFIG_HOME:-$HOME/.config}/fish/completions/codex-switcher.fish"; do
  if [ -f "$target" ]; then
    rm -f "$target"
    removed=1
    echo "已删除：$target"
  fi
done

# 移除安装脚本写入的 PATH / 补全标记及其后的导出行
for rc_file in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
  [ -f "$rc_file" ] || continue
  if grep -Fq '# codex-switcher user bin' "$rc_file" || grep -Fq '# codex-switcher completions' "$rc_file"; then
    tmp="$rc_file.tmp.$$"
    awk '
      /^# codex-switcher user bin$/ { skip=1; next }
      /^# codex-switcher completions$/ { skip=1; next }
      skip && /^(export PATH=|source )/ { skip=0; next }
      { skip=0; print }
    ' "$rc_file" > "$tmp"
    chmod --reference="$rc_file" "$tmp" 2>/dev/null || chmod 644 "$tmp"
    mv -f "$tmp" "$rc_file"
    removed=1
    echo "已移除 $rc_file 中的 codex-switcher 配置"
  fi
done

if [ "$removed" -eq 0 ]; then
  echo "未发现已安装的 codex-switcher，无需卸载。"
  exit 0
fi

echo
echo "codex-switcher 卸载完成。"
echo "注意：~/.codex 下的 deepseek-*.config.toml（含 API Key）、auth.json、config.toml 均被保留，"
echo "如确认不再需要请手动删除，或先备份：$codex_home_dir"
