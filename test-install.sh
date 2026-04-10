#!/usr/bin/env bash
# Test suite for install.sh — validates known issues are fixed
# Run: bash test-install.sh
# Exit 0 = all pass, Exit 1 = failures

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$DOTFILES/install.sh"
PASS=0
FAIL=0

assert() {
    local name="$1"
    local result="$2"  # 0 = pass, nonzero = fail
    if [ "$result" -eq 0 ]; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== PsilyOS install.sh test suite ==="
echo ""

# ── Issue 2: Cooling service %i specifier ────────
# The system service template uses %i (instance) instead of correct specifier.
# Since it's dead code (user service is used instead), it should be removed entirely
# OR use correct specifier.
echo "-- Cooling service --"
if grep -q '/home/%i/' "$SCRIPT"; then
    assert "No broken %i specifier in cooling service" "1"
else
    assert "No broken %i specifier in cooling service" "0"
fi

# ── Issue 3: mkinitcpio MODULES sed fragile ──────
# The sed assumes MODULES=() exactly — should handle existing modules
echo ""
echo "-- mkinitcpio MODULES handling --"
# Check that the script doesn't use a rigid MODULES=() replacement
if grep -q "s/MODULES=()/MODULES=(nvidia" "$SCRIPT"; then
    assert "mkinitcpio handles pre-existing MODULES entries" "1"
else
    assert "mkinitcpio handles pre-existing MODULES entries" "0"
fi

# ── Issue 4: SessionStart hook command mismatch ──
# restore_claude injects a different command format than our working settings.json
echo ""
echo "-- SessionStart hook command --"
# The hook should use: python3 $HOME/.claude/memory-compiler/hooks/session-start.py
# NOT: cd $HOME/.claude/memory-compiler && .venv/bin/python hooks/session-start.py
if grep -q '\.venv/bin/python hooks/session-start' "$SCRIPT"; then
    assert "SessionStart hook uses correct command format" "1"
else
    assert "SessionStart hook uses correct command format" "0"
fi

# Also check that the command matches our known-working format
# In install.sh it's escaped as \$HOME, so we match the literal backslash-dollar
if grep -q 'python3 \\$HOME/.claude/memory-compiler/hooks/session-start.py' "$SCRIPT"; then
    assert "SessionStart hook matches working settings.json format" "0"
else
    assert "SessionStart hook matches working settings.json format" "1"
fi

# ── Issue 5: set_shell should offer to switch ────
# It currently only prints instructions — should at least ask
echo ""
echo "-- Shell switching --"
if grep -q 'chsh.*zsh' "$SCRIPT" | grep -v "echo\|#" 2>/dev/null; then
    assert "set_shell actually switches to zsh (or prompts)" "0"
else
    # Check if there's a read prompt or actual chsh call (not just echo)
    if grep -A5 'set_shell()' "$SCRIPT" | grep -q 'read\|chsh -s'; then
        assert "set_shell offers interactive switch or switches automatically" "0"
    else
        assert "set_shell offers interactive switch or switches automatically" "1"
    fi
fi

# ── Issue 6: Wallpaper fallback ──────────────────
# Should handle download failures gracefully and not leave empty wallpaper dir
echo ""
echo "-- Wallpaper resilience --"
# Check that wallust run only happens if wallpapers actually exist (not just empty dir)
if grep -q 'find.*wallpapers.*-type f' "$SCRIPT"; then
    assert "Wallust only runs if wallpaper files actually exist" "0"
else
    assert "Wallust only runs if wallpaper files actually exist" "1"
fi

# ── Issue 7: All symlinked config dirs exist ────
# Every directory referenced in symlink_configs() must exist in the repo
echo ""
echo "-- Config directory existence --"
for dir in hypr waybar rofi mako ghostty foot tmux wallust wlogout yazi btop scripts starship; do
    if [ -d "$DOTFILES/$dir" ]; then
        assert "Config dir exists: $dir" "0"
    else
        assert "Config dir exists: $dir" "1"
    fi
done

# ── Issue 8: Wallust template targets are writable ──
# wallust.toml references target dirs — they must exist so wallust run succeeds
echo ""
echo "-- Wallust target dirs exist --"
# Parse wallust.toml targets and check their parent dirs exist in PsilyOS
for target_dir in hypr waybar mako rofi ghostty tmux wlogout; do
    if [ -d "$DOTFILES/$target_dir" ]; then
        assert "Wallust target dir exists: $target_dir" "0"
    else
        assert "Wallust target dir exists: $target_dir" "1"
    fi
done

# ── Issue 9: Shell configs handle bwrap sandbox ──
# symlink_configs creates symlinks for .zshrc/.zprofile, but Claude Code's
# bwrap sandbox can't bind-mount symlinks. install.sh must create real files
# that source the PsilyOS versions instead.
echo ""
echo "-- Shell config bwrap compatibility --"
# Check that symlink_configs does NOT use link_config for shell files
# Instead it should create sourcing shims (real files)
if grep -A5 'Shell configs' "$SCRIPT" | grep -q 'link_config.*zsh'; then
    assert "Shell configs use sourcing shims, not symlinks (bwrap compat)" "1"
else
    assert "Shell configs use sourcing shims, not symlinks (bwrap compat)" "0"
fi

# ── Issue 10: set_shell actually switches ────────
echo ""
echo "-- set_shell interactivity --"
if grep -A10 'set_shell()' "$SCRIPT" | grep -q 'chsh\|read.*-r'; then
    assert "set_shell offers to switch or switches interactively" "0"
else
    assert "set_shell offers to switch or switches interactively" "1"
fi

# ── Issue 11: Claude backup automation ───────────
# There should be a systemd timer that runs claude-backup on a schedule
echo ""
echo "-- Claude backup automation --"
if grep -q 'claude-backup\.timer\|enable.*claude-backup\|timer.*claude.*backup' "$SCRIPT"; then
    assert "Claude backup has systemd timer" "0"
else
    assert "Claude backup has systemd timer" "1"
fi

# ── Summary ──────────────────────────────────────
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
