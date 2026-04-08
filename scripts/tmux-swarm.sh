#!/usr/bin/env bash
# ┌──────────────────────────────────────────┐
# │  tsl (Tmux Swarm Layout)        │
# │  N tiled panes running the same command  │
# │  Perfect for spinning up multiple agents │
# │                                          │
# │  ┌──────┬──────┬──────┐                  │
# │  │ ag1  │ ag2  │ ag3  │                  │
# │  ├──────┼──────┼──────┤                  │
# │  │ ag4  │ ag5  │ ag6  │                  │
# │  └──────┴──────┴──────┘                  │
# └──────────────────────────────────────────┘
#
# Usage: tsl <count> [command] [session-name]
# Examples:
#   tsl 4 "claude code"        — 4 Claude agents
#   tsl 6 "aider" swarm        — 6 aider agents in "swarm" session

COUNT="${1:-4}"
CMD="${2:-}"
SESSION="${3:-swarm}"
DIR="$(pwd)"

if [ "$COUNT" -lt 1 ] || [ "$COUNT" -gt 12 ]; then
    echo "Usage: tsl <count 1-12> [command] [session-name]"
    exit 1
fi

tmux new-session -d -s "$SESSION" -c "$DIR"

# Create additional panes
for ((i = 1; i < COUNT; i++)); do
    tmux split-window -t "$SESSION" -c "$DIR"
    tmux select-layout -t "$SESSION" tiled
done

# Run command in all panes if provided
if [ -n "$CMD" ]; then
    for ((i = 0; i < COUNT; i++)); do
        tmux send-keys -t "$SESSION:.$i" "$CMD" Enter
    done
fi

tmux select-pane -t "$SESSION:.0"
tmux attach-session -t "$SESSION"
