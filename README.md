# claude-statusline

A status line for [Claude Code](https://claude.com/claude-code): one line showing
where you are, which model is running, how full the context is, what the session
has cost, how much of your rate limits you have burned, and whether you are on
pace to run out before they reset.

```
user@host ~/.claude │ main ● │ Opus 5.5 · xhigh │ ▰▱▱▱▱▱▱▱ 6% · 56k │ $0.73 │ 5h ▰▰▰▰▰▰▱▱ 70% slow down out ~51m, resets 3h00m  7d ▰▰▰▰▰▰▱▱ 74% speed up ~78% by reset 10h22m
```

Left to right:

| Segment | Meaning |
| --- | --- |
| `user@host ~/.claude` | user, short hostname, working directory with `$HOME` shortened to `~` |
| `main ●` | git branch (short SHA if detached). The amber dot means uncommitted changes |
| `Opus 5.5 · xhigh` | model, plus `fast` when fast mode is on and the thinking effort level when it is not the default |
| `▰▱▱▱▱▱▱▱ 6% · 56k` | context gauge, percentage used, and tokens in context |
| `$0.73` | session cost so far, followed by `+142/-17` lines changed once you have edited anything |
| `5h ▰▰▰▰▰▰▱▱ 70% …  7d ▰▰▰▰▰▰▱▱ 74% …` | rate limit usage for the 5 hour and 7 day windows, each with its own gauge and a [pace hint](#pace-hint) |

Percentages and gauges are green below 50%, amber below 80%, red above.

## Pace hint

Each rate limit window ends with a hint that compares your burn rate with the
time left. It takes your average usage since the window opened (the reset time
minus 5 hours or 7 days) and projects it forward to the reset:

| Hint | When | Example |
| --- | --- | --- |
| **slow down** (red) | you will hit 100% before the reset | `70% slow down out ~51m, resets 3h00m` |
| **on pace** (dim) | you will finish between 80% and 100% | `50% on pace ~90% by reset 2h15m` |
| **speed up** (green) | you will finish under 80%, so there is room to spare | `20% speed up ~25% by reset 1h00m` |
| **out** (red) | the window is used up | `100% out resets 40m` |

It is an average over the whole window, not your burn in the last hour, so a
heavy spurt after a quiet stretch will not flip it to "slow down" straight away.
For the first 5% of a window (about 15 minutes of the 5 hour window, 8 hours of
the week) one reading is too noisy to project from, so no hint is shown and the
plain reset countdown appears instead once usage passes 75%.

## Install

On a machine with the GitHub CLI or plain curl:

```bash
curl -fsSL https://raw.githubusercontent.com/Scanlia/claude-statusline/main/install.sh | bash
```

That drops the script at `~/.claude/statusline-command.sh` and merges this block
into `~/.claude/settings.json`, leaving your other settings untouched:

```json
"statusLine": {
  "type": "command",
  "command": "bash \"$HOME/.claude/statusline-command.sh\""
}
```

Or clone and run it:

```bash
git clone https://github.com/Scanlia/claude-statusline.git
bash claude-statusline/install.sh
```

### Asking Claude Code to do it

Paste this into Claude Code on the other machine:

> Install the status line from https://github.com/Scanlia/claude-statusline by
> running its install.sh, then confirm the statusLine block is in my settings.json.

## Requirements

- `bash`
- `jq`
- A terminal with 256 colours. For the gauge and separators to render you also
  need a font with box drawing glyphs, otherwise set `USE_UNICODE=0` (below).

## Configuration

The toggles live at the top of `statusline-command.sh`, so you can trim the line
per machine without touching the body:

| Variable | Default | Effect |
| --- | --- | --- |
| `SHOW_GIT` | `1` | branch and dirty dot |
| `SHOW_MODEL` | `1` | model name, effort level, fast mode flag |
| `SHOW_CONTEXT` | `1` | gauge, percentage, token count |
| `SHOW_COST` | `1` | session cost in USD |
| `SHOW_DIFF` | `1` | lines added and removed |
| `SHOW_LIMITS` | `1` | 5 hour and 7 day rate limit gauges and usage |
| `LIMIT_WARN` | `75` | percentage at which the reset countdown appears when there is no pace hint |
| `SHOW_PACE` | `1` | slow down / on pace / speed up hint for each window |
| `PACE_LOW` | `80` | projected usage at reset below which the hint says "speed up" |
| `PACE_MIN` | `5` | percentage of a window that must have elapsed before projecting |
| `USE_UNICODE` | `1` | set to `0` for ASCII separators and gauges |
| `GAUGE_CELLS` | `8` | width of the context and rate limit gauges |

## Notes

Claude Code feeds the script a JSON blob on stdin and prints the first line of
stdout. This one takes a single `jq` pass over that blob and makes no network
calls, so it renders in roughly 20ms.

It degrades quietly: no `jq` prints a plain prompt with a warning, and an older
Claude Code that does not send `rate_limits`, `effort` or `cost` simply drops
those segments. The two rate limit windows render independently, because
Claude Code can send one without the other (2.1.316 was seen sending
`seven_day` with no `five_hour`).

To see the payload your version sends, add this as the second line of the script
and read the file after a render:

```bash
input=$(cat); printf '%s' "$input" > /tmp/statusline-input.json
```
