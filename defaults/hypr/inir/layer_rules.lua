--[[
    Layer rules — port of niri 80-layer-rules.kdl
    https://wiki.hypr.land/Configuring/Basics/Window-Rules/ (layer rules section)
    API: hl.layer_rule(spec) — verified fields: name, match (namespace regex),
    blur, blur_popups, xray, no_anim, no_screen_share, above_lock, order.

    Layer ordering: iNiR's backdrop/wallpaper surfaces are layer-shell surfaces
    on the "background" layer, which Hyprland renders behind windows natively.
    niri's place-within-backdrop therefore needs no rule here — the layer
    chosen by the client produces the same stacking.
--]]

-- iNiR "ii" family backdrop (wallpaper surface). niri pairs it with
-- place-within-backdrop true and opacity 1.0; both are Hyprland defaults for
-- a background-layer surface, so the rule is a no-op placeholder that keeps
-- the namespace documented and catchable by future rules.
hl.layer_rule({
    name  = "ii-backdrop",
    match = { namespace = "^quickshell:iiBackdrop$" },
})

-- iNiR "waffle" family backdrop (wallpaper surface), same as above.
hl.layer_rule({
    name  = "waffle-backdrop",
    match = { namespace = "^quickshell:wBackdrop$" },
})

-- iRiS surfaces: niri background-effect { xray false } makes the blur sample
-- windows, not only the wallpaper. Hyprland's layer blur equivalent is
--   hl.layer_rule({ match = { namespace = "^quickshell:iris-" }, blur = true, xray = false })
-- but iNiR drives the blur dynamically from Settings → Appearance
-- (scripts/niri-config.py edits the niri rule). A Hyprland adapter for that
-- toggle is remaining work — until then the rule stays commented so iris
-- surfaces are never blurred unconditionally.
-- hl.layer_rule({
--     name  = "iris-blur",
--     match = { namespace = "^quickshell:iris-" },
--     blur  = true,
--     xray  = false,
-- })

-- ── Examples (from the niri source) ─────────────────────────────────────────
-- Make a specific layer surface semi-transparent:
-- hl.layer_rule({ name = "waybar-alpha", match = { namespace = "^waybar$" }, opacity = 0.9 })
--   (niri's layer-rule opacity maps to hl.layer_rule's opacity support once
--    verified against a live session; the stub does not declare it.)
--
-- Block a layer surface from screen capture: niri block-out-from has no layer
-- rule equivalent; Hyprland's permission system authorizes binaries instead.
