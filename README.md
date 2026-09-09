# claude-statusline

A status line for [Claude Code](https://claude.com/claude-code): one line showing
where you are, which model is running, how full the context is, what the session
has cost, and how much of your rate limits you have burned.

```
user@host ~/.claude │ main ● │ Opus 5 1M · high │ ▰▱▱▱▱▱▱▱ 6% · 56k │ $0.73 │ 5h 87% (1h27m)  7d 33%
```

Left to right:

| Segment | Meaning |
| --- | --- |
| `user@host ~/.claude` | user, short hostname, working directory with `$HOME` shortened to `~` |
| `main ●` | git branch (short SHA if detached). The amber dot means uncommitted changes |
| `Opus 5 1M · high` | model, plus `fast` when fast mode is on and the thinking effort level when it is not the default |
| `▰▱▱▱▱▱▱▱ 6% · 56k` | context gauge, percentage used, and tokens in context |
| `$0.73` | session cost so far, followed by `+142/-17` lines changed once you have edited anything |
| `5h 87% (1h27m)  7d 33%` | rate limit usage. The countdown to reset appears once a window passes 75% |

Percentages are green below 50%, amber below 80%, red above.

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
| `SHOW_LIMITS` | `1` | 5 hour and 7 day rate limit usage |
| `LIMIT_WARN` | `75` | percentage at which the reset countdown appears |
| `USE_UNICODE` | `1` | set to `0` for ASCII separators and gauge |
| `GAUGE_CELLS` | `8` | width of the context gauge |

## Notes

Claude Code feeds the script a JSON blob on stdin and prints the first line of
stdout. This one takes a single `jq` pass over that blob and makes no network
calls, so it renders in roughly 20ms.

It degrades quietly: no `jq` prints a plain prompt with a warning, and an older
Claude Code that does not send `rate_limits`, `effort` or `cost` simply drops
those segments.

To see the payload your version sends, add this as the second line of the script
and read the file after a render:

```bash
input=$(cat); printf '%s' "$input" > /tmp/statusline-input.json
```
