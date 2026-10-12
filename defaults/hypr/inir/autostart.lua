--[[
    Processes spawned at login — port of niri 50-startup.kdl
    https://wiki.hypr.land/Configuring/Basics/Autostart/

    hl.exec_cmd runs the command through sh -c, matching niri's
    spawn-sh-at-startup semantics (pipelines, &&, backgrounding all work).
--]]

hl.on("hyprland.start", function()
    -- Session bootstrap (single authoritative iNiR launch path):
    -- 1. Publish the full session environment to the systemd user manager AND
    --    the D-Bus activation environment. Plain Hyprland sessions (no UWSM)
    --    never activate graphical-session.target, so without this import the
    --    user manager has no WAYLAND_DISPLAY and any systemd/dbus-started
    --    Quickshell crashes with "Failed to create wl_display".
    -- 2. Clear a rate-limited/failed state left by a previous session's
    --    shutdown, then start inir-hyprland.service. systemd guarantees a
    --    single instance (start on an active service is a no-op), so Hyprland
    --    config reloads and repeated logins cannot spawn duplicate shells.
    -- The wants-link wiring to graphical-session.target was removed: that
    -- target refuses manual starts (RefuseManualStart=yes) and is never
    -- active on plain Hyprland, so it can never launch the shell here.
    hl.exec_cmd("command -v dbus-update-activation-environment >/dev/null 2>&1 && dbus-update-activation-environment --systemd XDG_MENU_PREFIX XDG_CURRENT_DESKTOP XDG_SESSION_TYPE WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE || systemctl --user import-environment XDG_MENU_PREFIX XDG_CURRENT_DESKTOP XDG_SESSION_TYPE WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE; systemctl --user reset-failed inir-hyprland.service 2>/dev/null; systemctl --user start inir-hyprland.service || true; kbuildsycoca6 >/dev/null 2>&1 || true")

    -- Clipboard history: wl-paste watches the clipboard and iNiR's store
    -- scripts keep cliphist updated. Text goes through clipboard-store.py,
    -- which strips browser markup (see the comments in niri 50-startup.kdl).
    -- Access via iNiR's clipboard overlay (Mod+V).
    hl.exec_cmd("wl-paste --no-newline --type text --watch ~/.config/quickshell/inir/scripts/clipboard-store.py &")
    hl.exec_cmd("wl-paste --type image --watch ~/.config/quickshell/inir/scripts/clipboard-image-store.sh &")

    -- Polkit: the iNiR shell is the authentication agent (its dialogs follow
    -- the family you use). Spawning another agent here would take its place.

    -- iNiR shell: launched above via the user systemd service
    -- (inir-hyprland.service). Do not add a compositor startup entry for the
    -- shell here or you'll get two shells.
end)
