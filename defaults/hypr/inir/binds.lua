--[[
    Key bindings — port of niri 70-binds.kdl
    https://wiki.hypr.land/Configuring/Basics/Binds/
    Dispatchers: https://wiki.hypr.land/Configuring/Basics/Dispatchers/
    API: hl.bind(keys, dispatcher, opts?) — verified against the shipped example.

    niri's "Mod" is Super on bare metal; here it is always SUPER.
    iNiR actions route through the `inir` launcher (Quickshell IPC), exactly
    like in the niri config. Hyprland-native actions use hl.dsp.* dispatchers.

    Bind flags: niri repeat=false is Hyprland's default (non-repeating);
    niri binds repeat by default, so volume/brightness pass repeating = true.
    niri allow-when-locked=true → locked = true.
    niri allow-inhibiting=false → dont_inhibit = true.
--]]

local M = "SUPER"
local fileManager = "dolphin"

-- ═══════════════════════════════════════════════════════════════════════════
-- Session & compositor
-- ═══════════════════════════════════════════════════════════════════════════

-- niri Mod+Tab toggle-overview: Hyprland has no built-in overview (documented
-- gap). iNiR's own overview stays on Mod+Space below.

-- niri Mod+Shift+E quit: niri shows a confirmation dialog; hl.dsp.exit()
-- quits Hyprland directly. The wiki recommends a session-terminating command
-- for uwsm-managed sessions: hl.dsp.exec_cmd("loginctl terminate-user \"\"").
hl.bind(M .. " + SHIFT + E", hl.dsp.exit())

-- niri Mod+Escape toggle-keyboard-shortcuts-inhibit: no toggle dispatcher
-- exists; see the commented binds.disable_keybind_grabbing in inir/misc.lua.

-- niri Mod+Shift+O power-off-monitors (any input wakes the screens). The
-- wiki warns against binding dpms directly; this timer pattern is the
-- documented form.
hl.bind(M .. " + SHIFT + O", function()
    hl.timer(function()
        hl.dispatch(hl.dsp.dpms({ action = "disable" }))
    end, { timeout = 500, type = "oneshot" })
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- iNiR shell overlays & tools (unchanged from niri)
-- ═══════════════════════════════════════════════════════════════════════════

hl.bind("SUPER + G", hl.dsp.exec_cmd("inir overlay toggle"))           -- crosshair overlay
hl.bind(M .. " + SPACE",    hl.dsp.exec_cmd("inir overview toggle"))   -- app launcher / overview
hl.bind(M .. " + V",        hl.dsp.exec_cmd("inir clipboard toggle"))  -- clipboard history

-- Lock screen (also reachable while the session is locked).
hl.bind(M .. " + ALT + L",         hl.dsp.exec_cmd("inir lock activate"), { locked = true, dont_inhibit = true })
hl.bind(M .. " + CTRL + SHIFT + L", hl.dsp.exec_cmd("inir lock focus"),    { locked = true, dont_inhibit = true })

-- Region selector: screenshot / OCR / Google Lens search.
hl.bind(M .. " + SHIFT + S", hl.dsp.exec_cmd("inir region menu"))
hl.bind(M .. " + SHIFT + X", hl.dsp.exec_cmd("inir region ocr"))
hl.bind(M .. " + SHIFT + A", hl.dsp.exec_cmd("inir region search"))
hl.bind("CTRL + SHIFT + S",  hl.dsp.exec_cmd("inir region menu"))

-- Wallpaper picker, settings, cheatsheet, panel family switch.
hl.bind("CTRL + ALT + T",  hl.dsp.exec_cmd("inir wallpaperSelector toggle"))
hl.bind(M .. " + COMMA",   hl.dsp.exec_cmd("inir settings"))
hl.bind(M .. " + SLASH",   hl.dsp.exec_cmd("inir cheatsheet toggle"))
hl.bind(M .. " + SHIFT + W", hl.dsp.exec_cmd("inir panelFamily cycle"))

-- Session / power dialog.
hl.bind(M .. " + SHIFT + Q", hl.dsp.exec_cmd("inir session toggle"))

-- Optional EasyEffects equalizer (reserved chord, as in the niri config).
hl.bind("CTRL + ALT + F", hl.dsp.exec_cmd("inir equalizer toggle"))

-- ═══════════════════════════════════════════════════════════════════════════
-- App launchers
-- ═══════════════════════════════════════════════════════════════════════════

hl.bind(M .. " + T",     hl.dsp.exec_cmd("inir terminal"))
hl.bind(M .. " + RETURN", hl.dsp.exec_cmd("inir terminal"))
hl.bind("SUPER + E",     hl.dsp.exec_cmd(fileManager))
hl.bind("SUPER + W",     hl.dsp.exec_cmd("inir browser"))

-- ═══════════════════════════════════════════════════════════════════════════
-- Window management
-- ═══════════════════════════════════════════════════════════════════════════

-- Close window (iNiR's close with confirmation dialog for unsaved work).
hl.bind(M .. " + Q", hl.dsp.exec_cmd("inir close-window"), { dont_inhibit = true })

-- Maximize column (fills the screen width). niri's maximize-column is a
-- toggle; Hyprland's colresize is stateless — Mod+R cycles the presets back.
hl.bind(M .. " + D", hl.dsp.layout("colresize 1.0"))

-- Fullscreen (layout-aware: the scrolling layout scrolls the column out of
-- view instead of covering neighbours, like niri's fullscreen-window).
hl.bind(M .. " + F", hl.dsp.window.fullscreen())

-- Toggle floating / tiling.
hl.bind(M .. " + A", hl.dsp.window.float({ action = "toggle" }))

-- niri Mod+Shift+V switch-focus-between-floating-and-tiling: no equivalent
-- dispatcher exists (documented gap).

-- ═══════════════════════════════════════════════════════════════════════════
-- Column layout (scrolling layout messages)
-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- ═══════════════════════════════════════════════════════════════════════════

-- Cycle through preset column widths (niri switch-preset-column-width).
hl.bind(M .. " + R", hl.dsp.layout("colresize +conf"))

-- Screen recording — region select with audio (niri, unchanged).
hl.bind(M .. " + SHIFT + R", hl.dsp.exec_cmd("inir region recordWithSound"))

-- niri Mod+Ctrl+R reset-window-height: Hyprland scrolling has no window-height
-- model (documented gap).

-- Center the focused column on screen (niri center-column). fit_into_view is
-- the closest scrolling-layout message (brings the column fully into view).
hl.bind(M .. " + C", hl.dsp.layout("fit_into_view"))

-- niri Mod+Ctrl+C center-visible-columns and Mod+Ctrl+F
-- expand-column-to-available-width: no equivalent messages.

-- Fine-grained width adjustment (niri set-column-width ±10% of the screen).
hl.bind(M .. " + MINUS",    hl.dsp.layout("colresize -0.1"))
hl.bind(M .. " + EQUAL",    hl.dsp.layout("colresize +0.1"))
-- niri Mod+Shift+Minus / Mod+Shift+Equal set-window-height ±10%: no height
-- model in the scrolling layout (documented gap).

-- Consume the neighbouring window into the focused column (stacking it
-- vertically) or expel the last one to its own column.
hl.bind(M .. " + BRACKETLEFT",  hl.dsp.layout("consume_or_expel prev"))
hl.bind(M .. " + BRACKETRIGHT", hl.dsp.layout("consume_or_expel next"))

-- niri Mod+W toggle-column-tabbed-display stays commented as in the niri
-- source; Hyprland's tabbed groups (hl.dsp.group.*) are a different model.

-- ═══════════════════════════════════════════════════════════════════════════
-- Focus navigation (arrows + Vim keys)
-- ═══════════════════════════════════════════════════════════════════════════

hl.bind(M .. " + LEFT",  hl.dsp.focus({ direction = "left" }))
hl.bind(M .. " + RIGHT", hl.dsp.focus({ direction = "right" }))
hl.bind(M .. " + UP",    hl.dsp.focus({ direction = "up" }))
hl.bind(M .. " + DOWN",  hl.dsp.focus({ direction = "down" }))
hl.bind(M .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(M .. " + J", hl.dsp.focus({ direction = "down" }))
hl.bind(M .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(M .. " + L", hl.dsp.focus({ direction = "right" }))

-- niri Mod+Home / Mod+End focus-column-first / focus-column-last: no
-- first/last dispatcher exists (documented gap).

-- ═══════════════════════════════════════════════════════════════════════════
-- Move windows (arrows + Vim keys)
-- ═══════════════════════════════════════════════════════════════════════════

-- Move (swap) the focused column left / right.
hl.bind(M .. " + SHIFT + LEFT",  hl.dsp.layout("swapcol l"))
hl.bind(M .. " + SHIFT + RIGHT", hl.dsp.layout("swapcol r"))
hl.bind(M .. " + SHIFT + H", hl.dsp.layout("swapcol l"))
hl.bind(M .. " + SHIFT + L", hl.dsp.layout("swapcol r"))

-- niri Mod+Shift+Up/Down (and J/K) move-window-up/down reorder windows inside
-- a column; the scrolling layout has no such message (documented gap).

-- niri Mod+Ctrl+Home/End move-column-to-first/last: no equivalent dispatcher
-- (swapcol wraps one step at a time).

-- ═══════════════════════════════════════════════════════════════════════════
-- Multi-monitor
-- ═══════════════════════════════════════════════════════════════════════════

hl.bind(M .. " + CTRL + LEFT",  hl.dsp.focus({ monitor = "l" }))
hl.bind(M .. " + CTRL + RIGHT", hl.dsp.focus({ monitor = "r" }))
hl.bind(M .. " + CTRL + UP",    hl.dsp.focus({ monitor = "u" }))
hl.bind(M .. " + CTRL + DOWN",  hl.dsp.focus({ monitor = "d" }))

hl.bind(M .. " + CTRL + SHIFT + LEFT",  hl.dsp.window.move({ monitor = "l" }))
hl.bind(M .. " + CTRL + SHIFT + RIGHT", hl.dsp.window.move({ monitor = "r" }))
hl.bind(M .. " + CTRL + SHIFT + UP",    hl.dsp.window.move({ monitor = "u" }))
hl.bind(M .. " + CTRL + SHIFT + DOWN",  hl.dsp.window.move({ monitor = "d" }))

-- ═══════════════════════════════════════════════════════════════════════════
-- Workspaces
-- ═══════════════════════════════════════════════════════════════════════════

for i = 1, 9 do
    local key = tostring(i)
    hl.bind(M .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(M .. " + CTRL + " .. key,  hl.dsp.window.move({ workspace = i }))
end

-- Navigate workspaces sequentially (niri focus-workspace-down/up with
-- dynamic workspaces; e+1 / e-1 select the next open workspace).
hl.bind(M .. " + PAGE_DOWN",     hl.dsp.focus({ workspace = "e+1" }))
hl.bind(M .. " + PAGE_UP",       hl.dsp.focus({ workspace = "e-1" }))
-- Move the column to the adjacent workspace, creating it if needed (r+1
-- includes empty workspaces, matching niri's dynamic workspace model).
hl.bind(M .. " + CTRL + PAGE_DOWN", hl.dsp.window.move({ workspace = "r+1" }))
hl.bind(M .. " + CTRL + PAGE_UP",   hl.dsp.window.move({ workspace = "r-1" }))

-- Mouse wheel workspace navigation. niri rate-limits these binds with
-- cooldown-ms=150; Hyprland applies binds.scroll_event_delay globally
-- (see inir/misc.lua).
hl.bind(M .. " + mouse_down",      hl.dsp.focus({ workspace = "e+1" }))
hl.bind(M .. " + mouse_up",        hl.dsp.focus({ workspace = "e-1" }))
hl.bind(M .. " + CTRL + mouse_down", hl.dsp.window.move({ workspace = "r+1" }))
hl.bind(M .. " + CTRL + mouse_up",   hl.dsp.window.move({ workspace = "r-1" }))

-- niri Mod+WheelScrollRight / Mod+WheelScrollLeft (horizontal wheel) have no
-- Hyprland bind syntax (documented gap).

-- ═══════════════════════════════════════════════════════════════════════════
-- Window switcher (niri recent-windows binds)
-- ═══════════════════════════════════════════════════════════════════════════

-- niri Alt+Tab next-window / Alt+Shift+Tab previous-window come with a live
-- preview popup; Hyprland cycles without previews.
hl.bind("ALT + Tab",         hl.dsp.window.cycle_next())
hl.bind("ALT + SHIFT + Tab", hl.dsp.focus({ last = true }))

-- ═══════════════════════════════════════════════════════════════════════════
-- Screenshots (niri has native screenshot actions; Hyprland has none)
-- ═══════════════════════════════════════════════════════════════════════════

-- All four niri binds (Print = interactive UI, Ctrl/Mod+Print = screen,
-- Alt+Print = window) route to iNiR's unified snip menu, whose toolbar picks
-- the action and scope.
hl.bind("Print",         hl.dsp.exec_cmd("inir region menu"))
hl.bind("CTRL + Print",  hl.dsp.exec_cmd("inir region menu"))
hl.bind(M .. " + Print", hl.dsp.exec_cmd("inir region menu"))
hl.bind("ALT + Print",   hl.dsp.exec_cmd("inir region menu"))

-- ═══════════════════════════════════════════════════════════════════════════
-- Hardware keys → iNiR IPC (with OSD feedback)
-- ═══════════════════════════════════════════════════════════════════════════

-- Volume (routed through iNiR for OSD + EasyEffects-aware sink resolution).
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("inir audio volumeUp"),   { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("inir audio volumeDown"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("inir audio mute"),       { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("inir audio micMute"),    { locked = true, repeating = true })

-- Brightness.
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("inir brightness increment"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("inir brightness decrement"), { locked = true, repeating = true })

-- Media playback (MPRIS — works with any player: Spotify, Firefox, mpv…).
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("inir mpris playPause"))
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("inir mpris playPause"))
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("inir mpris next"))
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("inir mpris previous"))

-- Keyboard shortcuts for media (when no media keys are available).
hl.bind(M .. " + CTRL + SPACE", hl.dsp.exec_cmd("inir mpris playPause"))
hl.bind(M .. " + ALT + N",      hl.dsp.exec_cmd("inir mpris next"))
hl.bind(M .. " + ALT + P",      hl.dsp.exec_cmd("inir mpris previous"))
hl.bind(M .. " + SHIFT + M",    hl.dsp.exec_cmd("inir audio mute"))
hl.bind(M .. " + SHIFT + P",    hl.dsp.exec_cmd("inir mpris playPause"))
hl.bind(M .. " + SHIFT + N",    hl.dsp.exec_cmd("inir mpris next"))
hl.bind(M .. " + SHIFT + B",    hl.dsp.exec_cmd("inir mpris previous"))
