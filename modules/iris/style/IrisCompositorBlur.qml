pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services

Singleton {
    id: root

    property bool available: true
    property bool enabled: true
    property string strength: "balanced"
    property real noise: 0.02
    property real saturation: 1.5
    property var elsewhere: []
    readonly property bool usable: root.available && root.enabled

    // Stay synchronized with changes made outside the Settings app: any
    // config reload (file save, hyprctl reload, another tool) re-reads the
    // compositor's actual blur state.
    Connections {
        target: CompositorService.isHyprland || CompositorService.isNiri ? Hyprland : null
        enabled: CompositorService.isHyprland || CompositorService.isNiri

        function onRawEvent(event) {
            if (event.name === "configreloaded") root.reload()
        }
    }

    function reload(): void {
        if (root.reader.running) return
        if (CompositorService.isNiri) {
            root.reader.command = ["python3", Quickshell.shellPath("scripts/niri-config.py"), "get-blur"]
            root.reader.running = true
        } else if (CompositorService.isHyprland) {
            // Same JSON shape (scripts/hyprland-config.py get-blur): reads
            // decoration:blur:* via `hyprctl getoption -j` — runtime truth.
            root.reader.command = ["python3", Quickshell.shellPath("scripts/hyprland-config.py"), "get-blur"]
            root.reader.running = true
        }
    }
    Component.onCompleted: root.reload()

    Process {
        id: reader
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const state = JSON.parse(text)
                    if (state.error) return
                    root.available = state.available
                    root.enabled = state.enabled
                    root.strength = state.strength
                    root.noise = state.noise
                    root.saturation = state.saturation
                    root.elsewhere = state.elsewhere ?? []
                } catch (e) {}
            }
        }
    }
}
