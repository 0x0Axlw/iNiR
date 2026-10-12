pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.services

/**
 * Hyprland compositor service — exposes Hyprland window, workspace, monitor
 * and focus data via the native Quickshell.Hyprland reactive properties.
 *
 * This replaces the polling-based HyprlandData.qml with reactive bindings
 * to Hyprland.toplevels.values, Hyprland.workspaces.values, Hyprland.monitors.values.
 *
 * All consumers should use CompositorService which normalizes both Niri and
 * Hyprland data to the same interface.
 */
Singleton {
    id: root

    // Expose the raw Hyprland data structures for consumers that need them
    readonly property var toplevels: Hyprland.toplevels?.values ?? []
    readonly property var workspaces: Hyprland.workspaces?.values ?? []
    readonly property var monitors: Hyprland.monitors?.values ?? []

    // Active window (the one with focus)
    readonly property var activeWindow: root._activeWindow()
    // Focused workspace ID
    readonly property int focusedWorkspaceId: root._focusedWorkspaceId()
    // Display scales per monitor
    readonly property var displayScales: root._displayScales()

    // Timer to debounce focus changes
    property bool _focusUpdateScheduled: false
    Timer {
        id: focusUpdateTimer
        interval: 16 // ~60fps
        repeat: false
        onTriggered: {
            _focusUpdateScheduled = false
            activeWindowChanged()
            focusedWorkspaceIdChanged()
        }
    }

    function _scheduleFocusUpdate(): void {
        if (!_focusUpdateScheduled) {
            _focusUpdateScheduled = true
            focusUpdateTimer.restart()
        }
    }

    // React to Hyprland focus/workspace changes
    // Conditional target to avoid connecting on Niri (static analysis guard)
    // NOTE: Quickshell.Hyprland has no focusedWindow property signal (the
    // handler warned at runtime and was removed); focus updates also come
    // from the toplevels/workspaces value-change Connections below.
    Connections {
        target: CompositorService.isHyprland ? Hyprland : null
        function onFocusedMonitorChanged() { root._scheduleFocusUpdate() }
        function onFocusedWorkspaceChanged() { root._scheduleFocusUpdate() }
    }

    Connections {
        target: CompositorService.isHyprland ? Hyprland.toplevels : null
        function onValuesChanged() { root._scheduleFocusUpdate() }
    }

    Connections {
        target: CompositorService.isHyprland ? Hyprland.workspaces : null
        function onValuesChanged() { root._scheduleFocusUpdate() }
    }

    function _activeWindow(): var {
        if (!CompositorService.isHyprland || !Hyprland.toplevels || !Hyprland.toplevels.values)
            return null

        const hy = Array.from(Hyprland.toplevels.values)
        for (const t of hy) {
            if (_get(t, ["activated"], false)) {
                return t.wayland ?? t
            }
        }
        // Fallback: first window on focused workspace
        const focusedWs = _focusedWorkspaceId()
        if (focusedWs >= 0) {
            for (const t of hy) {
                const wsId = _get(t, ["workspace", "id"], -1)
                if (wsId === focusedWs)
                    return t.wayland ?? t
            }
        }
        return hy.length > 0 ? (hy[0].wayland ?? hy[0]) : null
    }

    function _focusedWorkspaceId(): int {
        if (!CompositorService.isHyprland || !Hyprland.workspaces || !Hyprland.workspaces.values)
            return -1

        const workspaces = Array.from(Hyprland.workspaces.values)
        // First check Hyprland.focusedWorkspace if available
        try {
            const focused = Hyprland.focusedWorkspace
            if (focused && typeof focused.id === "number")
                return focused.id
        } catch (e) {}

        // Fallback: find workspace with active window
        if (Hyprland.toplevels && Hyprland.toplevels.values) {
            const hy = Array.from(Hyprland.toplevels.values)
            for (const t of hy) {
                if (_get(t, ["activated"], false)) {
                    const wsId = _get(t, ["workspace", "id"], -1)
                    if (wsId >= 0) return wsId
                }
            }
        }

        // Last resort: first workspace on focused monitor
        const focusedMonitor = _get(Hyprland, ["focusedMonitor", "name"], "")
        if (focusedMonitor) {
            for (const ws of workspaces) {
                if (_get(ws, ["monitor"], "") === focusedMonitor) {
                    return _get(ws, ["id"], -1)
                }
            }
        }

        return workspaces.length > 0 ? _get(workspaces[0], ["id"], -1) : -1
    }

    function _displayScales(): var {
        if (!CompositorService.isHyprland || !Hyprland.monitors || !Hyprland.monitors.values)
            return {}

        const scales = {}
        const monitors = Array.from(Hyprland.monitors.values)
        for (const m of monitors) {
            const name = _get(m, ["name"], "")
            const scale = _get(m, ["scale"], 1.0)
            if (name) scales[name] = scale
        }
        return scales
    }

    // Null-safe property accessor
    function _get(o: var, path: list<string>, fallback: var): var {
        try {
            let v = o
            for (let i = 0; i < path.length; i++) {
                if (v === null || v === undefined) return fallback
                v = v[path[i]]
            }
            return (v === undefined || v === null) ? fallback : v
        } catch (e) { return fallback }
    }

    // Power management via Hyprland dispatcher
    function powerOffMonitors(): void {
        if (CompositorService.isHyprland)
            root.dispatch("dpms off")
    }

    function powerOnMonitors(): void {
        if (CompositorService.isHyprland)
            root.dispatch("dpms on")
    }

    // Dispatch compat for Hyprland >= 0.55 (Lua config): IPC dispatch requests
    // are evaluated as `return hl.dispatch(<request>)`, so the request must be
    // a Lua expression producing an HL.Dispatcher. Legacy "<name> <args>"
    // strings from the QML layer are translated here to the equivalent
    // hl.dsp.* forms — verified against Hyprland 0.56.2 and the shipped
    // /usr/share/hypr/hyprland.lua example (e.g.
    // `hyprctl dispatch 'hl.dsp.focus({ workspace = 3 })'` -> ok).
    // Unknown dispatchers pass through unchanged so failures surface loudly
    // in the journal instead of being silently mis-mapped.
    function dispatch(request: string): var {
        const parts = request.trim().split(/\s+/)
        const name = parts[0] ?? ""
        const arg = parts.slice(1).join(" ")
        switch (name) {
        case "workspace":
            if (arg.length === 0)
                return Hyprland.dispatch(request)
            // Numeric targets are Lua numbers; selectors like "r+1"/"e-1"
            // or named workspaces are Lua strings.
            const literal = /^-?\d+$/.test(arg) ? arg : JSON.stringify(arg)
            return Hyprland.dispatch(`hl.dsp.focus({ workspace = ${literal} })`)
        case "togglespecialworkspace":
            return Hyprland.dispatch(arg.length > 0
                ? `hl.dsp.workspace.toggle_special(${JSON.stringify(arg)})`
                : "hl.dsp.workspace.toggle_special()")
        case "dpms":
            return Hyprland.dispatch(`hl.dsp.dpms(${JSON.stringify(arg.length > 0 ? arg : "toggle")})`)
        default:
            return Hyprland.dispatch(request)
        }
    }

    // Hyprland-specific window filtering for current workspace on a screen
    function filterCurrentWorkspace(toplevels: var, screenName: string): var {
        if (!CompositorService.isHyprland || !toplevels || toplevels.length === 0)
            return toplevels

        let currentWorkspaceId = -1
        if (Hyprland.toplevels && Hyprland.toplevels.values) {
            const hy = Array.from(Hyprland.toplevels.values)
            for (const t of hy) {
                const monitor = _get(t, ["monitor", "name"], "")
                const wsId = _get(t, ["workspace", "id"], -1)
                const active = _get(t, ["activated"], false)
                if (monitor === screenName && wsId >= 0) {
                    if (active) {
                        currentWorkspaceId = wsId
                        break
                    }
                    if (currentWorkspaceId === -1)
                        currentWorkspaceId = wsId
                }
            }
        }

        if (currentWorkspaceId === -1 && Hyprland.workspaces && Hyprland.workspaces.values) {
            const workspaces = Array.from(Hyprland.workspaces.values)
            const focusedId = _get(Hyprland, ["focusedWorkspace", "id"], -1)
            for (const ws of workspaces) {
                const monitor = _get(ws, ["monitor"], "")
                const wsId = _get(ws, ["id"], -1)
                if (monitor === screenName && wsId >= 0) {
                    if (focusedId >= 0 && wsId === focusedId) {
                        currentWorkspaceId = wsId
                        break
                    }
                    if (currentWorkspaceId === -1)
                        currentWorkspaceId = wsId
                }
            }
        }

        if (currentWorkspaceId === -1)
            return toplevels

        const wsByToplevel = new Map()
        if (Hyprland.toplevels && Hyprland.toplevels.values) {
            const hy = Array.from(Hyprland.toplevels.values)
            for (const t of hy) {
                const wsId = _get(t, ["workspace", "id"], -1)
                if (t?.wayland && wsId >= 0)
                    wsByToplevel.set(t.wayland, wsId)
            }
        }

        return toplevels.filter(t => wsByToplevel.get(t) === currentWorkspaceId)
    }
}
