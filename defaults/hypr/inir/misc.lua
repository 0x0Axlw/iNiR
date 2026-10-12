--[[
    Miscellaneous compositor settings — Hyprland-native options mapped from
    niri behavior (niri has no single "misc" section to port).
    https://wiki.hypr.land/Configuring/Basics/Variables/
--]]

hl.config({
    misc = {
        -- niri Mod+Shift+O power-off-monitors: "Any input wakes them up."
        -- These make any mouse motion or key press re-enable the outputs.
        mouse_move_enables_dpms = true,
        key_press_enables_dpms  = true,

        -- Approximation of niri's debug { honor-xdg-activation-with-invalid-serial }
        -- (let apps like VS Code or Firefox take focus when they request it,
        -- e.g. Nautilus open-with). Hyprland's focus_on_activate lets windows
        -- that send an activation request receive focus.
        focus_on_activate = true,
    },

    binds = {
        -- niri rate-limits its wheel binds with cooldown-ms=150; Hyprland
        -- rate-limits all scroll binds globally (default 300ms).
        scroll_event_delay = 150,

        -- Static escape hatch corresponding to niri's
        -- toggle-keyboard-shortcuts-inhibit (niri can toggle this at runtime;
        -- Hyprland only has this global switch):
        -- disable_keybind_grabbing = false,
    },

    xwayland = {
        -- Hyprland-specific: scale XWayland apps through Wayland instead of
        -- Xft.dpi double-scaling on fractional-scale monitors.
        force_zero_scaling = true,
    },
})
