--[[
    Window decoration & animations — port of niri 20-layout (radius/shadow) and
    60-animations.kdl
    https://wiki.hypr.land/Configuring/Basics/Variables/ (decoration)
    https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
--]]

hl.config({
    decoration = {
        -- niri window-rule: geometry-corner-radius 16 on every window.
        rounding = 16,

        -- niri window-rule: match is-active=false → opacity 0.9.
        -- Hyprland applies this globally to unfocused windows.
        inactive_opacity = 0.9,

        -- niri layout { shadow { ... } } (not "off"):
        shadow = {
            enabled = true,
            range   = 30,               -- niri softness 30 (shadow reach, approx.)
            offset  = { 0, 5 },         -- niri offset x=0 y=5
            color   = "rgba(00000077)", -- niri color "#0007"
            -- niri's shadow spread has no Hyprland equivalent.
        },

        -- niri ships no window blur: its only blur mechanism is the
        -- background-effect window rule, which iNiR toggles at runtime from
        -- Settings → Appearance (scripts/niri-config.py). The iNiR default is
        -- blur off, so Hyprland's blur starts disabled here too. A future
        -- Hyprland adapter must write this flag the same way.
        blur = {
            enabled = false,
        },
    },
})

-- ── Curves ──────────────────────────────────────────────────────────────────
-- Duration-based curves from niri's 60-animations.kdl:
hl.curve("inirWindowOpen",  { type = "bezier", points = { {0.05, 0.7}, {0.1,  1.0} } }) -- niri window-open  cubic-bezier 0.05 0.7 0.1 1.0
hl.curve("inirWindowClose", { type = "bezier", points = { {0.2,  0.0}, {0.0,  1.0} } }) -- niri window-close cubic-bezier 0.2 0 0 1

-- Auxiliary curves (same values as the shipped Hyprland example config):
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5,  0.5},  {0.75, 1}    } })

-- Spring curves, converted from niri's spring physics:
--   niri   damping-ratio ζ + stiffness k  (mass 1, epsilon 0.0001)
--   Hyprland dampening c = 2 · ζ · √(k · m), mass 1  →  c = 2 · ζ · √k
-- niri workspace-switch   { damping-ratio=1.0   stiffness=1000 }
hl.curve("niriWorkspaceSwitch", { type = "spring", mass = 1, stiffness = 1000, dampening = 63.2456 })
-- niri window-movement    { damping-ratio=0.92  stiffness=850  }
hl.curve("niriWindowMove",      { type = "spring", mass = 1, stiffness = 850,  dampening = 53.6448 })

-- ── Animations ──────────────────────────────────────────────────────────────
-- speed is measured in deciseconds (1 = 100ms). For springs it is set near the
-- physical settle time of the niri spring (≈9.2/(ζ·√k) seconds).

hl.animation({ leaf = "global",  enabled = true, speed = 10, bezier = "default" })

-- niri window-open (220 ms) / window-close (160 ms):
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 2.2, bezier = "inirWindowOpen" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.6, bezier = "inirWindowClose" })

-- niri window-movement / window-resize springs (Hyprland animates moves,
-- drags and resizes under one leaf).
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3.4, spring = "niriWindowMove" })

-- niri has no separate fade animations; track the window open/close timings so
-- the inactive-opacity fade (decoration.inactive_opacity) stays snappy.
hl.animation({ leaf = "fade",    enabled = true, speed = 2,   bezier = "almostLinear" })
hl.animation({ leaf = "fadeIn",  enabled = true, speed = 2.2, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.6, bezier = "almostLinear" })

-- niri workspace-switch spring (scrolling horizontally between workspaces):
hl.animation({ leaf = "workspaces",    enabled = true, speed = 2.9, spring = "niriWorkspaceSwitch", style = "slide" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 2.9, spring = "niriWorkspaceSwitch", style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 2.9, spring = "niriWorkspaceSwitch", style = "slide" })

-- iNiR panels are layer-shell surfaces that animate themselves in QML; keep
-- compositor-side layer animations short and simple.
hl.animation({ leaf = "layers",        enabled = true, speed = 4,   bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,   bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 2.4, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.5, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.5, bezier = "almostLinear" })

-- Borders are not rendered (general.border_size = 0, mirroring niri).
hl.animation({ leaf = "border", enabled = false })

-- niri animations without a Hyprland counterpart: config-notification-*
-- (niri config error popups), screenshot-ui-open (niri's screenshot UI),
-- overview-open-close / recent-windows-close (niri built-in overview and
-- Alt+Tab preview). iNiR's overlays animate in QML.
