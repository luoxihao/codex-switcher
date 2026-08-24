#compdef codex-switcher
# zsh completion for codex-switcher（需要已加载 compinit）

_codex_switcher() {
  local line cand desc
  local -a cands descs
  cands=()
  descs=()
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    cand=${line%%$'\t'*}
    desc=${line#*$'\t'}
    if [ "$desc" = "$line" ]; then
      desc=''
    fi
    cands+=("$cand")
    descs+=("$desc")
  done < <(codex-switcher __complete "${words[@]:1}" 2>/dev/null)
  if (( ${#cands[@]} )); then
    compadd -a cands -d descs
  fi
}

if (( $+functions[compdef] )); then
  compdef _codex_switcher codex-switcher
fi
