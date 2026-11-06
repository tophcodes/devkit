#!/usr/bin/env bash
# Claude Code statusline, three lines with a left and a right side each:
#
#   <session title>                                      <model> │ ctx <n>%
#   <cwd> (<change>/<commit>, <bookmark>)                     <peer name>
#   For <refs> │ Result <refs>                                     <mode>
#
# "For" and "Result" are the references the agent filed on its erker session
# (`erker session for|result`), as clickable links. The 5h/weekly rate limits
# are cached in ~/.cache/claude-code-usage.json for other readers rather than
# shown here.
set +e +u +o pipefail

cache_file="$HOME/.cache/claude-code-usage.json"
mkdir -p "$(dirname "$cache_file")"

input=$(cat)
field() { jq -r "$1 // empty" <<<"$input"; }

model=$(field '.model.display_name // .model.id')
[ -z "$model" ] && model="Claude"
model=$(sed -E 's/ context\)/)/' <<<"$model")

cwd=$(field '.workspace.current_dir')
used_pct=$(field '.context_window.used_percentage')
session_title=$(field '.session_name')
session_id=$(field '.session_id')
mode=$(field '.permission_mode')
[ -z "$mode" ] && mode=$(field '.vim.mode')

five_hour_pct=$(field '.rate_limits.five_hour.used_percentage')
seven_day_pct=$(field '.rate_limits.seven_day.used_percentage')

# resets_at (unix epoch) lets a reader of the cache draw a live "pace" marker:
# how far through the window we are, independent of usage.
five_hour_reset=$(field '.rate_limits.five_hour.resets_at')
seven_day_reset=$(field '.rate_limits.seven_day.resets_at')

# rate_limits isn't present on every tick - fall back to the last known cache
if [ -f "$cache_file" ]; then
    [ -z "$five_hour_pct" ] && five_hour_pct=$(jq -r '.five_hour_pct // empty' "$cache_file")
    [ -z "$seven_day_pct" ] && seven_day_pct=$(jq -r '.seven_day_pct // empty' "$cache_file")
    [ -z "$five_hour_reset" ] && five_hour_reset=$(jq -r '.five_hour_resets_at // empty' "$cache_file")
    [ -z "$seven_day_reset" ] && seven_day_reset=$(jq -r '.seven_day_resets_at // empty' "$cache_file")
fi

json_num() {
    if [ -z "$1" ]; then echo null; else echo "$1"; fi
}
printf '{"five_hour_pct":%s,"seven_day_pct":%s,"five_hour_resets_at":%s,"seven_day_resets_at":%s}\n' \
    "$(json_num "$five_hour_pct")" "$(json_num "$seven_day_pct")" \
    "$(json_num "$five_hour_reset")" "$(json_num "$seven_day_reset")" >"$cache_file.tmp"
mv "$cache_file.tmp" "$cache_file"

# The peer name ("infra-9f") is what other sessions pass to SendMessage. Claude
# Code keeps it in its per-process session file, keyed by session id.
peer_name=""
if [ -n "$session_id" ]; then
    session_file=$(grep -l -F "\"sessionId\":\"$session_id\"" "$HOME"/.claude/sessions/*.json 2>/dev/null | head -1)
    [ -n "$session_file" ] && peer_name=$(jq -r '.name // empty' "$session_file" 2>/dev/null)
fi

RST='\033[0m'
DIM='\033[2m'
BOLD='\033[1m'
BLUE='\033[34m'
MAGENTA='\033[35m'
CYAN='\033[36m'
YELLOW='\033[33m'
GREEN='\033[32m'
BGREEN='\033[1;32m'
BYELLOW='\033[1;33m'
BRED='\033[1;31m'
BCYAN='\033[1;36m'
GRAY='\033[90m'

# Where the work stands: jj's change and commit of @ with the nearest bookmark,
# or git's branch and commit. Colours follow `jj log`: the shortest unique
# prefix bold, the rest grey.
vcs=""
if [ -n "$cwd" ] && command -v jj >/dev/null 2>&1 \
    && ids=$(jj -R "$cwd" log --ignore-working-copy --no-graph --color=never -r @ \
        -T 'change_id.shortest().prefix() ++ " " ++ change_id.shortest(8).rest() ++ " " ++ commit_id.shortest().prefix() ++ " " ++ commit_id.shortest(8).rest()' 2>/dev/null); then
    read -r cp cr hp hr <<<"$ids"
    bookmark=$(jj -R "$cwd" log --ignore-working-copy --no-graph --color=never \
        -r 'heads(::@ & bookmarks())' -T 'bookmarks.join(" ") ++ "\n"' 2>/dev/null | head -1)
    vcs="${BOLD}${MAGENTA}${cp}${RST}${GRAY}${cr}${RST}${DIM}/${RST}${BOLD}${BLUE}${hp}${RST}${GRAY}${hr}${RST}"
    [ -n "$bookmark" ] && vcs="$vcs${DIM},${RST} ${MAGENTA}${bookmark}${RST}"
elif [ -n "$cwd" ] && hash=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null); then
    branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
    vcs="${BLUE}${hash}${RST}"
    [ -n "$branch" ] && vcs="$vcs${DIM},${RST} ${MAGENTA}${branch}${RST}"
fi

# A reference as a terminal hyperlink (OSC 8): github:owner/repo#n opens the
# issue or pull request (GitHub redirects /issues/n to a pull request), a URL
# opens itself, anything else stays plain text.
link() {
    local ref=$1 url="" text=$1
    if [[ "$ref" =~ ^github:([^/]+)/([^#]+)#([0-9]+)$ ]]; then
        url="https://github.com/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}/issues/${BASH_REMATCH[3]}"
        text="${BASH_REMATCH[2]}#${BASH_REMATCH[3]}"
    elif [[ "$ref" =~ ^https?:// ]]; then
        url=$ref
        [[ "$ref" =~ ^https://github\.com/[^/]+/([^/]+)/(issues|pull)/([0-9]+) ]] \
            && text="${BASH_REMATCH[1]}#${BASH_REMATCH[3]}"
    fi
    if [ -n "$url" ]; then
        printf '\033]8;;%s\a%s\033]8;;\a' "$url" "$text"
    else
        printf '%s' "$text"
    fi
}

links() {
    local first=1 ref
    while IFS= read -r ref; do
        [ -z "$ref" ] && continue
        [ "$first" -eq 0 ] && printf ', '
        link "$ref"
        first=0
    done
}

refs_line=""
if [ -n "$session_id" ] && command -v erker >/dev/null 2>&1; then
    session=$(erker session show --claude "$session_id" --json 2>/dev/null)
    for_refs=$(jq -r '.for[]? // empty' <<<"$session" 2>/dev/null | links)
    result_refs=$(jq -r '.result[]? // empty' <<<"$session" 2>/dev/null | links)
    if [ -n "$for_refs" ] || [ -n "$result_refs" ]; then
        refs_line="${DIM}For${RST} ${CYAN}${for_refs:-·}${RST} ${DIM}│ Result${RST} ${GREEN}${result_refs:-·}${RST}"
    fi
fi

pct_color() {
    local pct=$1
    if [ "$pct" -lt 50 ]; then
        printf '%b' "$BGREEN"
    elif [ "$pct" -lt 70 ]; then
        printf '%b' "$GREEN"
    elif [ "$pct" -lt 85 ]; then
        printf '%b' "$BYELLOW"
    elif [ "$pct" -lt 95 ]; then
        printf '%b' "$BRED"
    else
        printf '%b' "\033[1;5;31m"
    fi
}

ctx=""
if [ -n "$used_pct" ]; then
    pct_int="${used_pct%.*}"
    ctx="${DIM}ctx${RST} $(pct_color "$pct_int")${pct_int}${RST}${DIM}%${RST}"
fi

# The visible width of a rendered segment: colours and hyperlink targets take
# no columns.
visible() {
    local plain
    plain=$(printf '%b' "$1" | sed -E 's/\x1b\[[0-9;]*m//g; s/\x1b\]8;;[^\x07]*\x07//g')
    printf '%s' "${#plain}"
}

# Claude Code passes the terminal width in COLUMNS; its own frame takes a few
# columns, so the right side ends short of the edge. Without a width, or when
# both sides do not fit, the right side follows after a separator.
cols=$(( ${COLUMNS:-0} - 4 ))
row() {
    local left=$1 right=$2 gap
    printf '%b' "$left"
    [ "$(visible "$right")" -eq 0 ] && return
    gap=$(( cols - $(visible "$left") - $(visible "$right") ))
    if [ "$cols" -gt 0 ] && [ "$gap" -ge 2 ]; then
        printf "%${gap}s" ""
    else
        printf '%b' " ${DIM}│${RST} "
    fi
    printf '%b' "$right"
}

short_cwd="${cwd/#$HOME/\~}"
line1_right="${BCYAN}${model}${RST}"
[ -n "$ctx" ] && line1_right="$line1_right ${DIM}│${RST} $ctx"
line2_left="${DIM}${short_cwd}${RST}"
[ -n "$vcs" ] && line2_left="$line2_left ${DIM}(${RST}$vcs${DIM})${RST}"

row "${BOLD}${session_title}${RST}" "$line1_right"
echo
row "$line2_left" "${BYELLOW}${peer_name}${RST}"
if [ -n "$refs_line" ] || [ -n "$mode" ]; then
    echo
    row "$refs_line" "${YELLOW}${mode}${RST}"
fi
