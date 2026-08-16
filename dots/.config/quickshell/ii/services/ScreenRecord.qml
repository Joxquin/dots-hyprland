pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.modules.common
import qs.modules.common.functions
import qs.services
import qs

/**
 * Screen recording management service.
 * State is driven cleanly by Persistent.states.record.enable,
 * maintained by scripts/videos/record.sh.
 */
Singleton {
    id: root

    readonly property var opts: Config.options.screenRecord
    readonly property bool recording: Persistent.states.record?.enable ?? false

    function toggleRecordScreen() {
        const args = [Directories.recordScriptPath, "--fullscreen"]
        Quickshell.execDetached(args)
    }

    function stopRecord() {
        Quickshell.execDetached([Directories.recordScriptPath])
        Quickshell.execDetached(["bash", "-c", "pkill -INT wf-recorder 2>/dev/null; pkill -INT gpu-screen-recorder 2>/dev/null"])
        Persistent.states.record.enable = false
    }

    GlobalShortcut {
        name: "screenRecordToggle"
        description: "Starts/stops a fullscreen recording"
        onPressed: {
            if (root.recording) root.stopRecord()
            else root.toggleRecordScreen()
        }
    }

    IpcHandler {
        target: "record"

        function toggleScreen(): void { root.toggleRecordScreen() }
        function stop(): void { root.stopRecord() }
        function status(): string {
            return JSON.stringify({
                recording: root.recording
            })
        }
    }
}
