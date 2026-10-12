--[[
    Monitor configuration — port of niri's commented output blocks
    https://wiki.hypr.land/Configuring/Basics/Monitors/
    API: hl.monitor(spec) — verified fields: output, mode, position, scale,
    transform, mirror, bitdepth, reserved.

    niri ships no active output config (its output blocks are commented
    examples), so the default below keeps Hyprland's behavior: every output
    gets its preferred mode, automatic position and automatic scale.
--]]

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

-- Per-output examples, ported from niri 10-input-and-cursor.kdl:
-- hl.monitor({ output = "eDP-1",   mode = "1920x1080@60", scale = 1, position = "0 0" })
-- hl.monitor({ output = "HDMI-A-1", mode = "2560x1440@144", scale = 1, position = "1920 0" })
--
-- niri struts (layout { struts }) map to Hyprland's per-monitor reserved area,
-- e.g. reserved = { top = 64, bottom = 64, left = 0, right = 0 } to keep the
-- tiling area clear of panel space. iNiR's panels are layer-shell surfaces
-- that Hyprland already reserves space for, so this is not needed.
