#!/usr/bin/env bash
# Migration 045: deliver the Hyprland session bootstrap to existing installs.
#
# ./setup update never sourced the Hyprland installer stage (3.files.sh runs
# only on install/reinstall), and the installer's preserve-gate kept any
# pre-existing ~/.config/hypr/hyprland.lua untouched — so existing installs
# never received the session bootstrap (defaults/hypr/inir/autostart.lua)
# that publishes the Wayland environment and starts inir-hyprland.service,
# nor the inir/ modules the config requires. This migration reconciles the
# tree ONLY when iNiR owns it (a .inir-manifest is present); user-owned
# Hyprland configs (no manifest) are left untouched, same contract as before.

MIGRATION_ID="045-hyprland-session-bootstrap"
MIGRATION_TITLE="Hyprland sessions start iNiR automatically"
MIGRATION_DESCRIPTION="Existing iNiR-managed Hyprland configs are reconciled with the repo: the session bootstrap that publishes WAYLAND_DISPLAY into the user manager and starts inir-hyprland.service is delivered, along with the config modules."
MIGRATION_TARGET_FILE="~/.config/hypr/"
MIGRATION_REQUIRED=true

migration_check() {
    local repo_root="${REPO_ROOT:-}"
    local hypr_target="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"

    [[ -f "$hypr_target/.inir-manifest" ]] || return 1
    [[ -d "$repo_root/defaults/hypr" ]] || return 1

    # Needs run when the deployed bootstrap or any manifest-tracked file
    # differs from the repo.
    local file rel deployed source
    while IFS= read -r file; do
        rel="${file#"$repo_root/defaults/hypr/"}"
        [[ -n "$rel" ]] || continue
        deployed="$hypr_target/$rel"
        source="$file"
        if [[ ! -f "$deployed" ]] || ! cmp -s "$deployed" "$source"; then
            return 0
        fi
    done < <(find "$repo_root/defaults/hypr" -type f ! -name ".inir-manifest*" 2>/dev/null)

    # Manifest-tracked files that no longer exist in the repo also need cleanup.
    while IFS= read -r rel; do
        case "$rel" in "#"*) continue ;; esac
        [[ -n "$rel" ]] || continue
        if [[ ! -e "$repo_root/defaults/hypr/$rel" && -e "$hypr_target/$rel" ]]; then
            return 0
        fi
    done < <(tail -n +4 "$hypr_target/.inir-manifest" 2>/dev/null)

    return 1
}

migration_preview() {
    local repo_root="${REPO_ROOT:-}"
    local hypr_target="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
    printf 'Reconcile %s with %s (manifest-tracked files only)\n' "$hypr_target" "$repo_root/defaults/hypr"
}

migration_diff() {
    local repo_root="${REPO_ROOT:-}"
    local hypr_target="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
    diff -rq "$repo_root/defaults/hypr" "$hypr_target" 2>/dev/null | grep -v "\.inir-manifest" || true
}

migration_apply() {
    local repo_root="${REPO_ROOT:-}"
    local hypr_target="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"

    [[ -f "$hypr_target/.inir-manifest" ]] || return 0
    [[ -d "$repo_root/defaults/hypr" ]] || return 0

    # functions.sh (install_dir__sync) and robust-update.sh (generate_manifest,
    # cleanup_orphans) are sourced by setup before migrations run. setup also
    # sources environment-variables.sh, which defines INSTALLED_LISTFILE used
    # by the sync bookkeeping; set a fallback for direct invocation contexts.
    export INSTALLED_LISTFILE="${INSTALLED_LISTFILE:-${XDG_CONFIG_HOME:-$HOME/.config}/inir-installed.listfile}"

    # Sync first, then write the manifest: install_dir__sync runs rsync
    # --delete, which would remove a manifest generated before it.
    install_dir__sync "$repo_root/defaults/hypr" "$hypr_target" || return 1
    generate_manifest "$repo_root" "$hypr_target/.inir-manifest.new" || return 1
    mv "$hypr_target/.inir-manifest.new" "$hypr_target/.inir-manifest"
    cleanup_orphans "$hypr_target" "$hypr_target/.inir-manifest" || return 1
    return 0
}
