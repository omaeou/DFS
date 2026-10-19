pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import QtWebSockets

Singleton {
    id: client

    signal eventReceived(string event, string data)
    property string authToken: ""
    property bool connectionEnabled: true

    function reloadAuthToken() {
        const value = tokenFile.loaded ? tokenFile.text().trim() : ""
        authToken = /^[0-9a-f]{64}$/.test(value) ? value : ""
    }

    FileView {
        id: tokenFile
        readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || ""
        path: runtimeDir.startsWith("/") ? runtimeDir + "/dfs-daemon-websocket.token" : ""
        watchChanges: true
        printErrors: false
        onLoaded: client.reloadAuthToken()
        onFileChanged: reload()
        onLoadFailed: client.authToken = ""
    }

    Timer {
        interval: 1000
        running: client.authToken === ""
        repeat: true
        triggeredOnStart: true
        onTriggered: tokenFile.reload()
    }

    property WebSocket socket: WebSocket {
        id: ws
        url: client.authToken
            ? "ws://127.0.0.1:7777/ws?token=" + encodeURIComponent(client.authToken)
            : "ws://127.0.0.1:7777/ws"
        active: client.authToken.length === 64 && client.connectionEnabled

        onTextMessageReceived: (message) => {
            try {
                let payload = JSON.parse(message)
                client.eventReceived(payload.event, payload.data)
            } catch(e) {
                console.warn("[DaemonClient] JSON parse error:", e)
            }
        }

        onStatusChanged: {
            if (ws.status === WebSocket.Error) {
                console.warn("[DaemonClient] WebSocket connection failed")
            } else if (ws.status === WebSocket.Open) {
                console.log("[DaemonClient] Connected to Go Daemon!")
            }
        }
    }

    property Timer reconnectTimer: Timer {
        interval: 3000
        repeat: true
        running: client.authToken.length === 64 && (socket.status === WebSocket.Closed || socket.status === WebSocket.Error)
        onTriggered: {
            console.log("[DaemonClient] Attempting to reconnect...")
            client.connectionEnabled = false
            Qt.callLater(function() { client.connectionEnabled = true })
        }
    }
}
