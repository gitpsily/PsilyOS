#!/usr/bin/env bash
# ┌──────────────────────────────────────────┐
# │  tdl (Tmux Dev Layout)          │
# │  3-pane layout for coding + AI           │
# │                                          │
# │  ┌────────────────┬───────────┐          │
# │  │                │  agent    │          │
# │  │   editor       ├───────────┤          │
# │  │                │  shell    │          │
# │  └────────────────┴───────────┘          │
# └──────────────────────────────────────────┘
#
# Usage: tdl [session-name] [directory]

SESSION="${1:-dev}"
DIR="${2:-$(pwd)}"

tmux new-session -d -s "$SESSION" -c "$DIR"
tmux split-window -h -t "$SESSION" -c "$DIR" -l 40%
tmux split-window -v -t "$SESSION:.1" -c "$DIR" -l 40%

# Left pane: editor
tmux send-keys -t "$SESSION:.0" "nvim" Enter

# Top-right: agent pane (ready for claude, aider, etc)
# Bottom-right: shell

tmux select-pane -t "$SESSION:.0"
tmux attach-session -t "$SESSION"
