# bash completion for codex-switcher
# 安装：sh install.sh 会自动 source 本文件；手动启用：source <本文件路径>

_codex_switcher_complete() {
  local cur line cand
  cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=()
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    cand=${line%%$'\t'*}
    case "$cand" in
      "$cur"*) COMPREPLY+=("$cand") ;;
    esac
  done < <(codex-switcher __complete "${COMP_WORDS[@]:1}" 2>/dev/null)
}

complete -o bashdefault -o default -F _codex_switcher_complete codex-switcher
