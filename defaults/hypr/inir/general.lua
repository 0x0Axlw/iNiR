--[[
    Layout, gaps & borders — port of niri 20-layout-and-overview.kdl
    https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/

    niri is a scrollable-tiling compositor; Hyprland's "scrolling" layout is
    its direct counterpart (columns on an infinite horizontal tape, consume /
    expel / swapcol dispatchers).
--]]

hl.config({
    general = {
        -- niri: layout { gaps 25 } — one value for window-to-window and
        -- window-to-edge gaps; Hyprland splits these into gaps_in / gaps_out.
        gaps_in  = 25,
        gaps_out = 25,

        -- niri draws neither a focus ring nor a border (both "off"; iNiR's
        -- shell draws its own highlights), so windows are borderless here too.
        -- Set to 1+ and add general.col colors to get Hyprland borders instead.
        border_size = 0,

        -- niri: scrollable-tiling layout.
        layout = "scrolling",
    },
})

hl.config({
    scrolling = {
        -- niri: default-column-width { proportion 0.5 }
        column_width = 0.5,

        -- niri: preset-column-widths { 0.33333, 0.5, 0.66667 } — cycled by Mod+R.
        explicit_column_widths = "0.33333, 0.5, 0.66667",

        -- niri: center-focused-column "never" (keep the focused column at the
        -- edge when it already fits). 0 = always center, 1 = fit into view.
        focus_fit_method = 1,

        -- niri: default-column-width applies to every column, including the
        -- only one on a workspace, so a lone column does not stretch.
        fullscreen_on_one_column = false,

        -- niri's always-center-single-column has no per-condition equivalent
        -- here; with the settings above a lone column keeps its width and is
        -- scrolled into view like any other column.
    },
})

-- niri's background-color "transparent" needs no port: Hyprland draws no
-- workspace background of its own, so iNiR's backdrop layer shows through.
--
-- niri struts are commented out in the source config; iNiR's bar is a
-- layer-shell surface, so no Hyprland reserved area is configured either
-- (see inir/monitors.lua for the per-output `reserved` option).
