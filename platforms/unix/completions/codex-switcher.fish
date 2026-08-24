# fish completion for codex-switcher

function __codex_switcher_complete
    set -l tokens (commandline -opc)
    set -l cur (commandline -ct)
    set -l words
    if test (count $tokens) -ge 2
        set words $tokens[2..-1]
    end
    codex-switcher __complete $words 2>/dev/null | while read -l line
        set -l cand (string split -m1 -f1 \t -- $line)
        set -l desc (string split -m1 -f2 \t -- $line)
        string match -q -- "$cur*" "$cand"; and printf '%s\t%s\n' "$cand" "$desc"
    end
end

complete -c codex-switcher -f -a '(__codex_switcher_complete)'
