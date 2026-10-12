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
    Connections {
        target: CompositorService.isHyprland ? Hyprland : null
        function onFocusedWindowChanged() { root._scheduleFocusUpdate() }
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
            Hyprland.dispatch("dpms off")
    }

    function powerOnMonitors(): void {
        if (CompositorService.isHyprland)
            Hyprland.dispatch("dpms on")
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
