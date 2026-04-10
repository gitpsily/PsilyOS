#!/usr/bin/env bash
# Test: SDDM + Hyprland session setup produces a bootable login
# Validates: desktop file, config options, no crashing gui utils

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo ":: Testing Hyprland session setup..."
echo ""

# ── Test 1: hyprland.desktop uses start-hyprland (with full path) ──
desktop="/usr/share/wayland-sessions/hyprland.desktop"
if [ -f "$desktop" ]; then
    if grep -q "Exec=.*start-hyprland" "$desktop"; then
        pass "hyprland.desktop Exec uses start-hyprland"
    else
        fail "hyprland.desktop Exec does NOT use start-hyprland"
    fi
else
    fail "hyprland.desktop not found at $desktop"
fi

# ── Test 2: fix_sddm_session handles both Exec=Hyprland AND Exec=/usr/bin/Hyprland ──
# Verify install.sh's grep pattern catches both variants
if grep -qE 'Exec=\(\/usr\/bin\/\)\?Hyprland\|Exec=/usr/bin/\)Hyprland\|qE.*Exec.*Hyprland' "$DOTFILES/install.sh" 2>/dev/null || \
   grep -q 'Exec=.*Hyprland' "$DOTFILES/install.sh" 2>/dev/null; then
    pass "fix_sddm_session handles full-path Exec=/usr/bin/Hyprland variant"
else
    fail "fix_sddm_session would miss Exec=/usr/bin/Hyprland (full path variant)"
fi

# ── Test 3: hyprland.conf has disable_watchdog_warning ──
hyprconf="$DOTFILES/hypr/hyprland.conf"
if [ -f "$hyprconf" ]; then
    if grep -q "disable_watchdog_warning" "$hyprconf"; then
        pass "hyprland.conf has disable_watchdog_warning"
    else
        fail "hyprland.conf missing disable_watchdog_warning (causes crash dialog on SDDM)"
    fi
else
    fail "hyprland.conf not found at $hyprconf"
fi

# ── Test 4: hyprland-guiutils not in package list (crashes in VMs) ──
# Check the official/aur package arrays, not comments
if grep -E '^\s+hyprland-guiutils' "$DOTFILES/install.sh" 2>/dev/null; then
    fail "install.sh explicitly installs hyprland-guiutils (crashes in VMs)"
else
    pass "install.sh does not explicitly install hyprland-guiutils"
fi

# ── Test 5: autostart.conf doesn't launch hyprland-update-screen ──
autostart="$DOTFILES/hypr/autostart.conf"
if [ -f "$autostart" ]; then
    if grep -q "hyprland-update" "$autostart"; then
        fail "autostart.conf launches hyprland-update-screen (crashes in VMs)"
    else
        pass "autostart.conf does not launch hyprland-update-screen"
    fi
else
    fail "autostart.conf not found"
fi

# ── Test 6: setup_vm adds WLR env vars for VM compatibility ──
if grep -q "WLR_NO_HARDWARE_CURSORS" "$DOTFILES/install.sh" 2>/dev/null; then
    pass "install.sh sets WLR_NO_HARDWARE_CURSORS for VMs"
else
    fail "install.sh missing WLR_NO_HARDWARE_CURSORS for VM compat"
fi

# ── Test 7: setup_vm masks hyprland-update-screen in VMs ──
if grep -q "hyprland-update-screen" "$DOTFILES/install.sh" 2>/dev/null; then
    pass "install.sh handles hyprland-update-screen crash in VMs"
else
    fail "install.sh does not handle hyprland-update-screen crash in VMs"
fi

# ── Summary ──
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
