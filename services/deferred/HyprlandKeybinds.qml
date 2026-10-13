pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services

/**
 * A service that provides access to the ACTIVE Hyprland keybinds for the
 * cheatsheet and Settings shortcuts display.
 *
 * Source of truth: scripts/hyprland-config.py get-binds — parses the active
 * config sources (inir/binds.lua + custom/overrides.lua, multi-line
 * hl.bind(...) aware) and validates every parsed bind against
 * `hyprctl -j binds`, so parsed-but-inactive entries never display. Re-reads
 * on the socket2 "configreloaded" event, so edits made outside the Settings
 * app stay in sync.
 */
Singleton {
    id: root
    property string configScriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/hyprland-config.py`)
    property var keybinds: {"children": []}

    Connections {
        target: CompositorService.isHyprland ? Hyprland : null
        enabled: CompositorService.isHyprland

        function onRawEvent(event) {
            if (event.name == "configreloaded") {
                reader.running = true
            }
        }
    }

    Process {
        id: reader
        running: false
        command: ["python3", root.configScriptPath, "get-binds"]

        stdout: SplitParser {
            onRead: data => {
                try {
                    const parsed = JSON.parse(data)
                    if (parsed.error) {
                        console.error("[HyprlandKeybinds]", parsed.error)
                        return
                    }
                    root.keybinds = parsed
                } catch (e) {
                    console.error("[HyprlandKeybinds] Error parsing keybinds:", e)
                }
            }
        }
    }

    Timer {
        id: initTimer
        interval: 600
        repeat: false
        onTriggered: {
            if (!CompositorService.isHyprland) return
            reader.running = true
        }
    }

    Connections {
        target: CompositorService
        function onIsHyprlandChanged() {
            if (CompositorService.isHyprland) {
                initTimer.start()
            }
        }
    }

    Component.onCompleted: {
        if (CompositorService.isHyprland) initTimer.start()
    }
}

