--[[
    Input devices, touchpad, cursor & gestures — port of niri 10-input-and-cursor.kdl
    https://wiki.hypr.land/Configuring/Basics/Variables/ (input / touchpad / cursor)

    Cursor theme & size are set via env in hyprland.lua (XCURSOR_THEME / XCURSOR_SIZE),
    matching niri's xcursor-theme / xcursor-size settings.
--]]

hl.config({
    input = {
        -- niri: xkb { layout "us" } (variant/model/options/rules left empty
        -- so the system locale1 defaults apply; same behavior here).
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        -- niri: numlock is commented out → numlock stays off at login.
        -- Hyprland's default (false) matches; uncomment to enable.
        -- numlock_by_default = true,

        -- niri: repeat-delay 250 / repeat-rate 50
        repeat_delay = 250,  -- ms before a held key repeats
        repeat_rate  = 50,   -- repeats per second

        -- niri: mouse { accel-profile "flat" } — raw movement, no acceleration curve.
        accel_profile = "flat",

        -- niri leaves focus-follows-mouse commented out = click-to-focus.
        -- Hyprland's default is focus-follows-mouse (1); 0 = cursor movement
        -- does not change focus, matching niri.
        follow_mouse = 0,

        touchpad = {
            -- niri: tap (tap-to-click) and tap-button-map "left-right-middle"
            tap_to_click   = true,
            tap_button_map = "lrm",
            -- niri leaves natural-scroll, dwt etc. commented → libinput /
            -- Hyprland defaults apply.
        },
    },
})

-- ── Cursor behavior ─────────────────────────────────────────────────────────
hl.config({
    cursor = {
        -- niri: hide-when-typing. Hyprland's closest option hides the cursor
        -- on any key press until the mouse moves (docs: cursor.hide_on_key_press).
        hide_on_key_press = true,
    },
})

-- ── Gestures ────────────────────────────────────────────────────────────────
-- niri only configures hot corners (cursor in the top-left corner opens its
-- overview); Hyprland has no hot corners and no built-in overview, so that
-- behavior has no equivalent here (iNiR's own overview stays on Mod+Space).
--
-- The 3-finger workspace swipe is a Hyprland-native addition: niri has no
-- touchpad workspace navigation to port.
hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})
