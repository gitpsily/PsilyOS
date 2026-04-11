#!/usr/bin/env bash
# Claude Code full environment backup
# Creates a portable tarball with everything needed to rebuild
# Usage: claude-backup [output-dir]

set -euo pipefail

OUTPUT_DIR="${1:-${CLAUDE_BACKUP_DIR:-$HOME}}"
TIMESTAMP=$(date +%Y-%m-%d)
BACKUP_FILE="$OUTPUT_DIR/claude-backup-${TIMESTAMP}.tar.gz"

echo ""
echo "  Backing up Claude Code environment..."
echo "  Output: $BACKUP_FILE"
echo ""

cd "$HOME"

# Build the include list (relative to $HOME)
INCLUDES=()

# ── Core Claude Config ──────────────────────────
# Settings, hooks, agents, commands, skills, memory-compiler, kernel state
[ -d ".claude" ] && INCLUDES+=(".claude")

# User-scope MCP config (Overseer MCP lives here)
[ -f ".claude.json" ] && INCLUDES+=(".claude.json")

# Global agent instructions
[ -f "CLAUDE.md" ] && INCLUDES+=("CLAUDE.md")

# ── Overseer Memory System ─────────────────────
# MCP server code + migration/backup scripts
[ -d "overseer" ] && INCLUDES+=("overseer")

# ChromaDB vector store (the actual memories)
[ -d ".local/share/overseer-chromadb" ] && INCLUDES+=(".local/share/overseer-chromadb")

# FTS5 keyword index
[ -f ".local/share/overseer-fts.db" ] && INCLUDES+=(".local/share/overseer-fts.db")

# Graph DB (entity relationships)
[ -f ".local/share/overseer-graph.db" ] && INCLUDES+=(".local/share/overseer-graph.db")

# ── claude-mem data (disabled but preserved) ───
[ -d ".claude-mem" ] && INCLUDES+=(".claude-mem")

if [ ${#INCLUDES[@]} -eq 0 ]; then
    echo "  Nothing to back up!"
    exit 1
fi

# ── Excludes (rebuilt on restore, platform-specific, or ephemeral) ──
EXCLUDES=(
    # Plugin caches (platform-specific, rebuilt on install)
    --exclude='.claude/plugins/cache'
    --exclude='.claude/plugins/install-counts-cache.json'

    # Auth (re-authenticate on new machine)
    --exclude='.claude/.credentials.json'

    # Ephemeral session data
    --exclude='.claude/sessions'
    --exclude='.claude/session-env'
    --exclude='.claude/file-history'
    --exclude='.claude/history.jsonl'
    --exclude='.claude/tmp'
    --exclude='.claude/traces'
    --exclude='.claude/errors'
    --exclude='.claude/agent-outputs'
    --exclude='.claude/debug'
    --exclude='.claude/downloads'
    --exclude='.claude/paste-cache'
    --exclude='.claude/shell-snapshots'
    --exclude='.claude/mcp-needs-auth-cache.json'
    --exclude='.claude/stats-cache.json'
    --exclude='.claude/verify-manifest.txt'

    # Large generated state (not needed for rebuild)
    --exclude='.claude/usage-data'
    --exclude='.claude/backups'

    # Venvs (rebuilt on restore)
    --exclude='.claude/memory-compiler/.venv'

    # Git repos (re-cloned or re-fetched)
    --exclude='.claude/memory-compiler/.git'
    --exclude='overseer/.git'

    # Old/superseded data
    --exclude='.claude/chromadb'
    --exclude='.claude/memory-service'
    --exclude='.claude/cache'

    # Python bytecode
    --exclude='__pycache__'
    --exclude='*.pyc'
)

# tar exit 1 = "file changed as we read it" which is normal for live session files
tar czf "$BACKUP_FILE" "${EXCLUDES[@]}" "${INCLUDES[@]}" 2>/dev/null || {
    local rc=$?
    if [ $rc -eq 1 ]; then
        true  # Files changed during backup — normal, backup is still usable
    else
        echo "  ERROR: tar failed with exit code $rc"
        exit $rc
    fi
}

SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "  Done. $BACKUP_FILE ($SIZE)"
echo ""
echo "  Contents:"
echo "    .claude/          settings, hooks, agents, skills, commands, memory-compiler"
echo "    .claude.json      user-scope MCP config (Overseer)"
echo "    CLAUDE.md         global agent instructions"
echo "    overseer/         MCP server code + scripts"
echo "    .local/share/     ChromaDB + FTS5 + graph ($(
    ~/.local/share/overseer-venv/bin/python3 -c "
import chromadb
c = chromadb.PersistentClient(path='$HOME/.local/share/overseer-chromadb')
col = c.get_collection('overseer_memories')
print(f'{col.count()} memories')
" 2>/dev/null || echo "? memories"
))"
echo "    .claude-mem/      claude-mem data (preserved)"
echo ""
echo "  NOT included (rebuilt on restore):"
echo "    plugins/cache     reinstall via: claude plugins install ..."
echo "    .credentials.json re-auth via: claude login"
echo "    overseer-venv     rebuild via: python -m venv + pip install chromadb"
echo "    memory-compiler   rebuild via: uv sync"
