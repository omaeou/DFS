pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// One set of NetworkManager polls is shared by every bar and control panel.
Singleton {
    id: service

    property string activeSsid: ""
    property bool wifiEnabled: false
    property bool wiredConnected: false

    function parseTerseFields(line) {
        const fields = []
        let value = ""
        let escaped = false
        for (let i = 0; i < line.length; ++i) {
            const ch = line[i]
            if (escaped) {
                value += (ch === ":" || ch === "\\") ? ch : "\\" + ch
                escaped = false
            } else if (ch === "\\") {
                escaped = true
            } else if (ch === ":") {
                fields.push(value)
                value = ""
            } else {
                value += ch
            }
        }
        if (escaped)
            value += "\\"
        fields.push(value)
        return fields
    }

    function readWifiList(output) {
        let selected = ""
        const lines = String(output || "").split(/\r?\n/)
        for (let i = 0; i < lines.length; ++i) {
            const fields = parseTerseFields(lines[i])
            if (fields.length >= 2 && fields[0].trim() === "yes") {
                selected = fields[1].trim()
                break
            }
        }
        activeSsid = selected
    }

    function readWifiRadio(output) {
        wifiEnabled = String(output || "").trim() === "enabled"
    }

    function readDevices(output) {
        let connected = false
        const lines = String(output || "").split(/\r?\n/)
        for (let i = 0; i < lines.length; ++i) {
            const fields = parseTerseFields(lines[i])
            if (fields.length >= 2 && fields[0].toLowerCase().indexOf("ethernet") >= 0 &&
                fields[1].toLowerCase().indexOf("connected") === 0) {
                connected = true
                break
            }
        }
        wiredConnected = connected
    }

    function refresh() {
        if (!wifiListProcess.running)
            wifiListProcess.running = true
        if (!wifiRadioProcess.running)
            wifiRadioProcess.running = true
        if (!devicesProcess.running)
            devicesProcess.running = true
    }

    Process {
        id: wifiListProcess
        command: ["nmcli", "-t", "-f", "active,ssid", "device", "wifi"]
        stdout: StdioCollector { onStreamFinished: service.readWifiList(text) }
    }

    Process {
        id: wifiRadioProcess
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector { onStreamFinished: service.readWifiRadio(text) }
    }

    Process {
        id: devicesProcess
        command: ["nmcli", "-t", "-f", "TYPE,STATE", "device"]
        stdout: StdioCollector { onStreamFinished: service.readDevices(text) }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: service.refresh()
    }
}
