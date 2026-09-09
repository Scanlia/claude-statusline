#!/bin/bash
# Claude Code status line.
# Config: settings.json -> "statusLine": {"type":"command","command":"bash \"$HOME/.claude/statusline-command.sh\""}
# Requires: jq. Renders every turn, so it stays cheap (one jq pass, no network).

# --- toggles ---------------------------------------------------------------
SHOW_GIT=1          # branch + dirty dot
SHOW_MODEL=1        # model name + effort level + fast-mode flag
SHOW_CONTEXT=1      # context gauge, percentage, token count
SHOW_COST=1         # session cost in USD
SHOW_DIFF=1         # +added/-removed lines this session
SHOW_LIMITS=1       # 5h / 7d rate-limit usage, countdown when high
LIMIT_WARN=75       # show reset countdown once a limit passes this %
USE_UNICODE=1       # 0 = plain ASCII separators and gauge
GAUGE_CELLS=8       # width of the context gauge
# ---------------------------------------------------------------------------

input=$(cat)

# Soft 256-colour palette; easier on the eye than bold ANSI.
R=$'\033[0m'
C_HOST=$'\033[38;5;114m'; C_PATH=$'\033[38;5;75m';  C_GIT=$'\033[38;5;180m'
C_MODEL=$'\033[38;5;110m'; C_COST=$'\033[38;5;176m'; C_DIM=$'\033[38;5;242m'
C_TRACK=$'\033[38;5;238m'
C_OK=$'\033[38;5;114m';   C_WARN=$'\033[38;5;179m'; C_BAD=$'\033[38;5;210m'

if [ "$USE_UNICODE" = 1 ]; then
    SEP="│"; FILL="▰"; EMPTY="▱"; DOT="●"; MID="·"
else
    SEP="|"; FILL="#"; EMPTY="-"; DOT="*"; MID="."
fi

if ! command -v jq >/dev/null 2>&1; then
    printf '%s%s@%s%s %s%s%s %s(jq not installed)%s' \
        "$C_HOST" "$(whoami)" "$(hostname -s)" "$R" \
        "$C_PATH" "${PWD/#$HOME/\~}" "$R" "$C_BAD" "$R"
    exit 0
fi

# Single jq pass: one value per line, fixed order.
{
    IFS= read -r cwd
    IFS= read -r model
    IFS= read -r used_pct
    IFS= read -r ctx_tokens
    IFS= read -r cost
    IFS= read -r added
    IFS= read -r removed
    IFS= read -r fast_mode
    IFS= read -r effort
    IFS= read -r rl5
    IFS= read -r rl5_reset
    IFS= read -r rl7
    IFS= read -r rl7_reset
} < <(printf '%s' "$input" | jq -r '
    [ (.workspace.current_dir // .cwd // ""),
      (.model.display_name // ""),
      (.context_window.used_percentage // ""),
      (.context_window.total_input_tokens // ""),
      (.cost.total_cost_usd // ""),
      (.cost.total_lines_added // 0),
      (.cost.total_lines_removed // 0),
      (.fast_mode // false),
      (.effort.level // ""),
      (.rate_limits.five_hour.used_percentage // ""),
      (.rate_limits.five_hour.resets_at // ""),
      (.rate_limits.seven_day.used_percentage // ""),
      (.rate_limits.seven_day.resets_at // "")
    ] | .[] | tostring')

# green under 50%, amber under 80%, red above
pct_colour() {
    local p=${1%%.*}
    if   [ "${p:-0}" -ge 80 ]; then printf '%s' "$C_BAD"
    elif [ "${p:-0}" -ge 50 ]; then printf '%s' "$C_WARN"
    else                            printf '%s' "$C_OK"; fi
}

human_tokens() {
    local t=${1%%.*}
    if   [ "${t:-0}" -ge 1000000 ]; then printf '%d.%dM' $((t/1000000)) $(((t%1000000)/100000))
    elif [ "${t:-0}" -ge 1000 ];    then printf '%dk' $((t/1000))
    else                                 printf '%d' "${t:-0}"; fi
}

time_until() {
    local now delta
    now=$(date +%s); delta=$(( ${1%%.*} - now ))
    [ "$delta" -le 0 ] && return
    if [ "$delta" -lt 3600 ]; then printf '%dm' $((delta/60))
    else printf '%dh%02dm' $((delta/3600)) $(((delta%3600)/60)); fi
}

# Filled portion coloured by load, remainder in a dark track.
gauge() {
    local pct=${1%%.*} filled i out=""
    filled=$(( (pct * GAUGE_CELLS + 99) / 100 ))
    [ "$filled" -gt "$GAUGE_CELLS" ] && filled=$GAUGE_CELLS
    out="$(pct_colour "$pct")"
    for ((i = 0; i < GAUGE_CELLS; i++)); do
        [ "$i" = "$filled" ] && out+="$C_TRACK"
        if [ "$i" -lt "$filled" ]; then out+="$FILL"; else out+="$EMPTY"; fi
    done
    printf '%s%s' "$out" "$R"
}

seg=()

# user@host  ~/path
seg+=("${C_HOST}$(whoami)@$(hostname -s)${R} ${C_PATH}${cwd/#$HOME/\~}${R}")

# branch ●
if [ "$SHOW_GIT" = 1 ] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
             || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
    dirty=""
    git -C "$cwd" diff --quiet --ignore-submodules HEAD 2>/dev/null \
        || dirty=" ${C_WARN}${DOT}${R}"
    seg+=("${C_GIT}${branch}${R}${dirty}")
fi

# model · effort
if [ "$SHOW_MODEL" = 1 ] && [ -n "$model" ]; then
    m="${C_MODEL}${model/ (1M context)/ 1M}${R}"
    [ "$fast_mode" = "true" ] && m+=" ${C_WARN}fast${R}"
    [ -n "$effort" ] && [ "$effort" != "medium" ] && m+=" ${C_DIM}${MID} ${effort}${R}"
    seg+=("$m")
fi

# ▰▰▱▱▱▱▱▱ 6% · 56k
if [ "$SHOW_CONTEXT" = 1 ] && [ -n "$used_pct" ]; then
    c="$(gauge "$used_pct") $(pct_colour "$used_pct")${used_pct%%.*}%${R}"
    [ -n "$ctx_tokens" ] && c+=" ${C_DIM}${MID} $(human_tokens "$ctx_tokens")${R}"
    seg+=("$c")
fi

# $0.73  +142/-17
money=""
[ "$SHOW_COST" = 1 ] && [ -n "$cost" ] && money="${C_COST}$(printf '$%.2f' "$cost")${R}"
if [ "$SHOW_DIFF" = 1 ] && { [ "${added:-0}" -gt 0 ] || [ "${removed:-0}" -gt 0 ]; }; then
    [ -n "$money" ] && money+=" "
    money+="${C_OK}+${added}${R}${C_DIM}/${R}${C_BAD}-${removed}${R}"
fi
[ -n "$money" ] && seg+=("$money")

# 5h 87% (1h27m) · 7d 33%
if [ "$SHOW_LIMITS" = 1 ] && [ -n "$rl5" ]; then
    l="${C_DIM}5h${R} $(pct_colour "$rl5")${rl5%%.*}%${R}"
    if [ "${rl5%%.*}" -ge "$LIMIT_WARN" ] && [ -n "$rl5_reset" ]; then
        left=$(time_until "$rl5_reset"); [ -n "$left" ] && l+=" ${C_DIM}(${left})${R}"
    fi
    if [ -n "$rl7" ]; then
        l+="  ${C_DIM}7d${R} $(pct_colour "$rl7")${rl7%%.*}%${R}"
        if [ "${rl7%%.*}" -ge "$LIMIT_WARN" ] && [ -n "$rl7_reset" ]; then
            left=$(time_until "$rl7_reset"); [ -n "$left" ] && l+=" ${C_DIM}(${left})${R}"
        fi
    fi
    seg+=("$l")
fi

# Join segments with a dim divider.
out=""
for s in "${seg[@]}"; do
    [ -n "$out" ] && out+=" ${C_DIM}${SEP}${R} "
    out+="$s"
done
printf '%s' "$out"
