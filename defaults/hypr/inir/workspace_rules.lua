--[[
    Workspace rules — scaffold
    https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
    API: hl.workspace_rule(spec) — verified fields: workspace, gaps_in, gaps_out,
    border_size, no_border, no_rounding, no_shadow, default_name, persistent,
    layout, monitor, on_created_empty, default, decorate, float_gaps, animation.

    The niri config ships no active workspace rules (only examples in
    90-user-extra.kdl), so this file starts empty of active rules.
--]]

-- niri 90-user-extra examples, ported:
-- Named workspaces (sticky, always present):
-- hl.workspace_rule({ workspace = "name:browser", persistent = true })
-- hl.workspace_rule({ workspace = "name:code",    persistent = true })

-- Per-workspace layout override (global default is "scrolling"):
-- hl.workspace_rule({ workspace = "2", layout = "dwindle" })

-- Smart gaps: no gaps when only one tiled window is present:
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })

-- Hyprland-only concept (no niri counterpart): the special workspace
-- (scratchpad) toggled with a bind:
-- hl.workspace_rule({ workspace = "special", gaps_in = 0, gaps_out = 0, border_size = 0, rounding = 0 })
