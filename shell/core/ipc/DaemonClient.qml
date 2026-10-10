// DaemonClient.qml
pragma Singleton
import QtQuick
import QtWebSockets

QtObject {
    id: client

    signal eventReceived(string event, string data)

    property WebSocket socket: WebSocket {
        id: ws
        url: "ws://127.0.0.1:7777/ws"
        active: true

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
                console.warn("[DaemonClient] Socket error:", ws.errorString)
            } else if (ws.status === WebSocket.Open) {
                console.log("[DaemonClient] Connected to Go Daemon!")
            }
        }
    }

    property Timer reconnectTimer: Timer {
        interval: 3000
        repeat: true
        running: socket.status === WebSocket.Closed || socket.status === WebSocket.Error
        onTriggered: {
            console.log("[DaemonClient] Attempting to reconnect...")
            socket.active = false
            socket.active = true
        }
    }
}