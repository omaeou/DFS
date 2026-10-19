pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Bluetooth power state is polled once for all control panels.
Singleton {
    id: service

    property bool powered: false

    function readState(output) {
        const match = String(output || "").match(/^Powered:\s*(yes|no)\s*$/im)
        powered = !!match && match[1].toLowerCase() === "yes"
    }

    Process {
        id: stateProcess
        command: ["bluetoothctl", "show"]
        stdout: StdioCollector { onStreamFinished: service.readState(text) }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!stateProcess.running) stateProcess.running = true
    }
}
