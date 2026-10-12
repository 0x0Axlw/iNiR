--[[
    Window rules — port of niri 30-window-rules.kdl
    https://wiki.hypr.land/Configuring/Basics/Window-Rules/
    API: hl.window_rule(spec) — verified against the shipped example config.

    The niri global geometry-corner-radius rule maps to decoration.rounding
    (see inir/decoration.lua): one global value instead of a catch-all rule.
--]]

-- Gaming surfaces: avoid rounding so fullscreen games stay eligible for direct
-- scanout (niri additionally disables clip-to-geometry; Hyprland has no
-- content-clipping feature, so nothing to port for that half).
hl.window_rule({
    name  = "gaming-no-rounding",
    match = {
        class = "^(gamescope|steam_app_[0-9]+|dota2|lutris|net\\.lutris\\..*|heroic|com\\.heroicgameslauncher\\.hgl|org\\.prismlauncher\\.PrismLauncher|minecraft|wine|wine64)$",
    },
    rounding = 0,
})

-- WezTerm: niri works around an initial-configure bug with an empty
-- default-column-width {}. Hyprland has no per-window default-size rule;
-- nothing to port (documented in docs/HYPRLAND_PORT.md).

-- Firefox / Zen: picture-in-picture window opens floating (niri open-floating).
hl.window_rule({
    name  = "firefox-pip",
    match = { class = "firefox", title = "^Picture-in-Picture$" },
    float = true,
})
hl.window_rule({
    name  = "zen-pip",
    match = { class = "zen", title = "^Picture-in-Picture$" },
    float = true,
})

-- Steam notifications: niri opens them floating, unfocused, anchored to the
-- bottom-right corner. The anchor is approximate — the toast width varies.
hl.window_rule({
    name  = "steam-notifications",
    match = { class = "^steam$", title = "^notificationtoasts_[0-9]+_desktop$" },
    float   = true,
    no_focus = true,
    move    = "monitor_w-420 monitor_h-160",
})

-- KDE's XEmbed→SNI bridge exposes a transient X11 window during tray watcher
-- restarts. Keep it floating, transparent and unfocused so it never flashes
-- (niri: open-floating / open-focused false / opacity 0.0 / no ring, border,
-- shadow).
hl.window_rule({
    name  = "xembedsniproxy",
    match = { class = "^xembedsniproxy$" },
    float      = true,
    no_focus   = true,
    opacity    = 0.0,
    border_size = 0,
    no_shadow  = true,
})

-- niri's block-out-from "screen-capture" privacy rules (KeePassXC, GNOME
-- Secrets) have no per-window equivalent: Hyprland's permission system
-- (hl.permission) authorizes binaries, not capture-blocking of windows.
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/

-- ── Floating apps (commented examples, same as the niri source) ─────────────
-- hl.window_rule({
--     name  = "float-pavucontrol",
--     match = { class = "^pavucontrol$" },
--     float = true,
-- })
-- hl.window_rule({
--     name  = "float-nm-connection-editor",
--     match = { class = "^nm-connection-editor$" },
--     float = true,
-- })
-- hl.window_rule({
--     name  = "float-gnome-calculator",
--     match = { class = "^org\\.gnome\\.Calculator$" },
--     float = true,
-- })
