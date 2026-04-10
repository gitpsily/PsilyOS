#!/usr/bin/env bash
# ┌──────────────────────────────────────────┐
# │  PsilyOS install.sh — Pre-push Tests    │
# │  Run: bash tests/test_install.sh        │
# └──────────────────────────────────────────┘

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0
WARN=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
warn() { echo "  WARN: $1"; WARN=$((WARN + 1)); }

echo ""
echo ":: PsilyOS install.sh validation"
echo "   Dotfiles: $DOTFILES"
echo ""

# ═══════════════════════════════════════════
# Section 1: Script Integrity
# ═══════════════════════════════════════════
echo "── Script Integrity ──"

# 1.1: bash -n syntax check
if bash -n "$DOTFILES/install.sh" 2>/dev/null; then
    pass "install.sh passes bash -n syntax check"
else
    fail "install.sh has syntax errors (bash -n)"
fi

# 1.2: install.sh is executable
if [ -x "$DOTFILES/install.sh" ]; then
    pass "install.sh is executable"
else
    fail "install.sh is not executable (chmod +x)"
fi

# 1.3: starts with correct shebang
if head -1 "$DOTFILES/install.sh" | grep -q '^#!/usr/bin/env bash'; then
    pass "install.sh has #!/usr/bin/env bash shebang"
else
    fail "install.sh has wrong or missing shebang"
fi

# 1.4: no set -e (script handles errors per-function)
if grep -q '^set -e' "$DOTFILES/install.sh"; then
    fail "install.sh has set -e (should handle errors per-function)"
else
    pass "install.sh does not use set -e (correct — per-function error handling)"
fi

# 1.5: shellcheck (optional)
if command -v shellcheck &>/dev/null; then
    errors=$(shellcheck -S error "$DOTFILES/install.sh" 2>&1 | grep -c "error" || true)
    if [ "$errors" -eq 0 ]; then
        pass "shellcheck found no errors"
    else
        fail "shellcheck found $errors errors"
    fi
else
    warn "shellcheck not installed — skipping lint"
fi

echo ""

# ═══════════════════════════════════════════
# Section 2: No Hardcoded Paths
# ═══════════════════════════════════════════
echo "── Hardcoded Path Check ──"

# 2.1: no /home/psily
matches=$(grep -n '/home/psily' "$DOTFILES/install.sh" | grep -v '^\s*#' || true)
if [ -n "$matches" ]; then
    echo "$matches" | head -5
    fail "install.sh contains hardcoded /home/psily"
else
    pass "no hardcoded /home/psily in install.sh"
fi

# 2.2: no /home/claude
matches=$(grep -n '/home/claude' "$DOTFILES/install.sh" | grep -v '^\s*#' || true)
if [ -n "$matches" ]; then
    echo "$matches" | head -5
    fail "install.sh contains hardcoded /home/claude"
else
    pass "no hardcoded /home/claude in install.sh"
fi

# 2.3: uses $HOME or $DOTFILES, not absolute home paths
hardcoded_homes=$(grep -nE '"/home/[a-z]+' "$DOTFILES/install.sh" | grep -v '^#' | grep -v 'backup_home' | grep -v 'has_home_dir' | grep -v 'tmpdir' || true)
if [ -n "$hardcoded_homes" ]; then
    echo "$hardcoded_homes"
    fail "install.sh has hardcoded /home/username paths"
else
    pass "all home paths use \$HOME or \$DOTFILES"
fi

echo ""

# ═══════════════════════════════════════════
# Section 3: Function Definitions
# ═══════════════════════════════════════════
echo "── Function Definitions ──"

expected_functions=(
    preflight
    install_packages
    link_config
    symlink_configs
    set_shell
    set_permissions
    setup_nvidia
    setup_cooling
    setup_vm
    setup_smb
    create_dirs
    restore_claude
    fix_sddm_session
    install_claude_code
    setup_libvirt
    download_wallpapers
    setup_claude_backup
    enable_services
    main
)

for fn in "${expected_functions[@]}"; do
    if grep -q "^${fn}()" "$DOTFILES/install.sh"; then
        pass "function $fn() is defined"
    else
        fail "function $fn() is MISSING"
    fi
done

echo ""

# ═══════════════════════════════════════════
# Section 4: main() calls all setup functions
# ═══════════════════════════════════════════
echo "── main() Orchestration ──"

# Extract main function body
main_body=$(sed -n '/^main()/,/^}/p' "$DOTFILES/install.sh")

main_calls=(
    preflight
    install_packages
    install_claude_code
    create_dirs
    symlink_configs
    set_permissions
    set_shell
    setup_nvidia
    setup_cooling
    setup_vm
    setup_smb
    restore_claude
    setup_claude_backup
    setup_libvirt
    fix_sddm_session
    enable_services
    download_wallpapers
)

for fn in "${main_calls[@]}"; do
    if echo "$main_body" | grep -q "$fn"; then
        pass "main() calls $fn"
    else
        fail "main() does NOT call $fn"
    fi
done

echo ""

# ═══════════════════════════════════════════
# Section 5: Execution Order (critical deps)
# ═══════════════════════════════════════════
echo "── Execution Order ──"

# SMB must come before restore_claude (backup may be on NAS)
smb_line=$(grep -n 'setup_smb' "$DOTFILES/install.sh" | tail -1 | cut -d: -f1)
claude_line=$(grep -n 'restore_claude' "$DOTFILES/install.sh" | tail -1 | cut -d: -f1)
if [ -n "$smb_line" ] && [ -n "$claude_line" ] && [ "$smb_line" -lt "$claude_line" ]; then
    pass "setup_smb runs before restore_claude (backup may be on NAS)"
else
    fail "setup_smb must run BEFORE restore_claude"
fi

# symlink_configs before fix_sddm_session
sym_line=$(grep -n 'symlink_configs' "$DOTFILES/install.sh" | tail -1 | cut -d: -f1)
sddm_line=$(grep -n 'fix_sddm_session' "$DOTFILES/install.sh" | tail -1 | cut -d: -f1)
if [ -n "$sym_line" ] && [ -n "$sddm_line" ] && [ "$sym_line" -lt "$sddm_line" ]; then
    pass "symlink_configs runs before fix_sddm_session"
else
    fail "symlink_configs must run BEFORE fix_sddm_session"
fi

# install_packages before everything that needs binaries
pkg_line=$(grep -n 'install_packages' "$DOTFILES/install.sh" | tail -1 | cut -d: -f1)
if [ -n "$pkg_line" ] && [ -n "$sym_line" ] && [ "$pkg_line" -lt "$sym_line" ]; then
    pass "install_packages runs before symlink_configs"
else
    fail "install_packages must run early"
fi

echo ""

# ═══════════════════════════════════════════
# Section 6: fix_sddm_session Logic
# ═══════════════════════════════════════════
echo "── fix_sddm_session Logic ──"

# 6.1: Handles Exec=Hyprland (bare)
if grep -q 'Exec=.*Hyprland' "$DOTFILES/install.sh"; then
    pass "fix_sddm_session matches Exec=Hyprland"
else
    fail "fix_sddm_session doesn't match Exec=Hyprland"
fi

# 6.2: Handles Exec=/usr/bin/Hyprland (full path)
if grep -qE 'Exec=\(/usr/bin/\)\?Hyprland|/usr/bin/\).*Hyprland' "$DOTFILES/install.sh"; then
    pass "fix_sddm_session matches Exec=/usr/bin/Hyprland"
else
    fail "fix_sddm_session doesn't match full-path Exec=/usr/bin/Hyprland"
fi

# 6.3: Checks for start-hyprland FIRST (idempotent)
sddm_func=$(sed -n '/^fix_sddm_session()/,/^}/p' "$DOTFILES/install.sh")
# Look at the conditional checks (grep -q lines), not echo statements
first_check=$(echo "$sddm_func" | grep -n 'grep.*start-hyprland' | head -1 | cut -d: -f1)
hyprland_check=$(echo "$sddm_func" | grep -n 'grep.*Hyprland"' | head -1 | cut -d: -f1)
if [ -n "$first_check" ] && [ -n "$hyprland_check" ] && [ "$first_check" -le "$hyprland_check" ]; then
    pass "fix_sddm_session checks for start-hyprland first (idempotent)"
else
    fail "fix_sddm_session should check start-hyprland BEFORE trying to fix"
fi

# 6.4: Replacement uses /usr/bin/start-hyprland (full path)
if echo "$sddm_func" | grep -q 'Exec=/usr/bin/start-hyprland'; then
    pass "fix_sddm_session replaces with full path /usr/bin/start-hyprland"
else
    fail "fix_sddm_session should use /usr/bin/start-hyprland (full path)"
fi

# 6.5: Has fallback for unknown Exec line
if echo "$sddm_func" | grep -q 'Unknown Exec\|check manually'; then
    pass "fix_sddm_session has fallback for unknown Exec lines"
else
    fail "fix_sddm_session silently ignores unrecognized Exec lines"
fi

echo ""

# ═══════════════════════════════════════════
# Section 7: setup_vm Logic
# ═══════════════════════════════════════════
echo "── setup_vm Logic ──"

vm_func=$(sed -n '/^setup_vm()/,/^}/p' "$DOTFILES/install.sh")

# 7.1: Sets WLR_NO_HARDWARE_CURSORS
if echo "$vm_func" | grep -q 'WLR_NO_HARDWARE_CURSORS'; then
    pass "setup_vm sets WLR_NO_HARDWARE_CURSORS"
else
    fail "setup_vm missing WLR_NO_HARDWARE_CURSORS"
fi

# 7.2: Sets WLR_RENDERER_ALLOW_SOFTWARE
if echo "$vm_func" | grep -q 'WLR_RENDERER_ALLOW_SOFTWARE'; then
    pass "setup_vm sets WLR_RENDERER_ALLOW_SOFTWARE"
else
    fail "setup_vm missing WLR_RENDERER_ALLOW_SOFTWARE"
fi

# 7.3: Masks hyprland-update-screen
if echo "$vm_func" | grep -q 'hyprland-update-screen'; then
    pass "setup_vm masks hyprland-update-screen"
else
    fail "setup_vm doesn't handle hyprland-update-screen crash"
fi

# 7.4: dpkg-divert fallback to mv (Arch doesn't have dpkg)
if echo "$vm_func" | grep -q 'dpkg-divert.*||' || echo "$vm_func" | grep -q 'mv.*hyprland-update-screen'; then
    pass "setup_vm has mv fallback for Arch (no dpkg-divert)"
else
    fail "setup_vm relies on dpkg-divert without mv fallback"
fi

# 7.5: Handles vmware, kvm/qemu, oracle VMs
for virt in vmware "kvm|qemu" oracle; do
    if echo "$vm_func" | grep -q "$virt"; then
        pass "setup_vm handles $virt"
    else
        fail "setup_vm missing handler for $virt"
    fi
done

echo ""

# ═══════════════════════════════════════════
# Section 8: Config Files
# ═══════════════════════════════════════════
echo "── Config File Validation ──"

# 8.1: hyprland.conf exists
if [ -f "$DOTFILES/hypr/hyprland.conf" ]; then
    pass "hypr/hyprland.conf exists"
else
    fail "hypr/hyprland.conf missing"
fi

# 8.2: hyprland.conf has disable_watchdog_warning
if grep -q "disable_watchdog_warning.*=.*true" "$DOTFILES/hypr/hyprland.conf" 2>/dev/null; then
    pass "hyprland.conf has disable_watchdog_warning = true"
else
    fail "hyprland.conf missing disable_watchdog_warning (causes crash dialog)"
fi

# 8.3: autostart.conf doesn't launch hyprland-update-screen
if [ -f "$DOTFILES/hypr/autostart.conf" ]; then
    if grep -q "hyprland-update" "$DOTFILES/hypr/autostart.conf"; then
        fail "autostart.conf launches hyprland-update-screen (crashes in VMs)"
    else
        pass "autostart.conf does not launch hyprland-update-screen"
    fi
else
    fail "hypr/autostart.conf missing"
fi

# 8.4: .env.example exists
if [ -f "$DOTFILES/.env.example" ]; then
    pass ".env.example exists"
else
    fail ".env.example missing (users need a template)"
fi

# 8.5: wallust templates exist
if ls "$DOTFILES/wallust/templates/"* &>/dev/null; then
    pass "wallust/templates/ has template files"
else
    warn "wallust/templates/ is empty or missing"
fi

echo ""

# ═══════════════════════════════════════════
# Section 9: .gitignore
# ═══════════════════════════════════════════
echo "── .gitignore ──"

if [ -f "$DOTFILES/.gitignore" ]; then
    pass ".gitignore exists"

    # .env must be ignored
    if grep -q '\.env$\|^\.env' "$DOTFILES/.gitignore"; then
        pass ".gitignore ignores .env"
    else
        fail ".gitignore does NOT ignore .env (secrets will leak!)"
    fi

    # wallust-generated files
    if grep -q 'foot.ini\|wallust.*generat\|# wallust' "$DOTFILES/.gitignore" 2>/dev/null; then
        pass ".gitignore ignores wallust-generated files"
    else
        warn ".gitignore may not cover wallust-generated configs"
    fi
else
    fail ".gitignore MISSING — .env and generated files will be committed!"
fi

echo ""

# ═══════════════════════════════════════════
# Section 10: Symlink Safety
# ═══════════════════════════════════════════
echo "── Symlink Structure ──"

# Check that config dirs that should be symlinked are actually dirs in the repo
config_dirs=(hypr waybar rofi mako ghostty foot tmux wallust wlogout yazi btop scripts)
for dir in "${config_dirs[@]}"; do
    if [ -d "$DOTFILES/$dir" ]; then
        pass "$dir/ exists in repo"
    else
        fail "$dir/ missing from repo"
    fi
done

# Check for circular symlinks in the repo (the untracked ones we saw)
circulars=0
for dir in "${config_dirs[@]}"; do
    if [ -L "$DOTFILES/$dir/$dir" ]; then
        circulars=$((circulars + 1))
    fi
done
if [ "$circulars" -gt 0 ]; then
    warn "$circulars circular symlinks found (e.g. hypr/hypr -> PsilyOS/hypr) — gitignore them"
else
    pass "no circular symlinks in repo dirs"
fi

# 10.2: link_config uses ln -sfn (not ln -sf) to prevent circular symlinks on re-run
if grep -q 'ln -sfn' "$DOTFILES/install.sh"; then
    pass "link_config uses ln -sfn (safe for re-runs)"
else
    fail "link_config uses ln -sf (creates circular symlinks on re-run — use ln -sfn)"
fi

echo ""

# ═══════════════════════════════════════════
# Section 11: Security
# ═══════════════════════════════════════════
echo "── Security ──"

# 11.1: .env is not tracked
if git -C "$DOTFILES" ls-files --error-unmatch .env 2>/dev/null; then
    fail ".env is tracked by git (secrets will be pushed!)"
else
    pass ".env is not tracked by git"
fi

# 11.2: SMB credentials file gets 600 perms
if grep -q 'chmod 600.*credfile\|chmod 600.*smbcredentials' "$DOTFILES/install.sh"; then
    pass "SMB credentials file gets chmod 600"
else
    fail "SMB credentials file missing chmod 600"
fi

# 11.3: SSH key gets generated with ed25519
if grep -q 'ssh-keygen.*ed25519' "$DOTFILES/install.sh"; then
    pass "SSH key uses ed25519"
else
    fail "SSH key should use ed25519"
fi

echo ""

# ═══════════════════════════════════════════
# Section 12: All scripts syntax check
# ═══════════════════════════════════════════
echo "── Script Syntax (all .sh files) ──"

find "$DOTFILES/scripts" -name "*.sh" -type f 2>/dev/null | while read -r script; do
    name=$(basename "$script")
    if bash -n "$script" 2>/dev/null; then
        pass "$name passes syntax check"
    else
        fail "$name has syntax errors"
    fi
done

echo ""

# ═══════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════
echo "════════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL failed, $WARN warnings"
echo "════════════════════════════════════════"
echo ""

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
