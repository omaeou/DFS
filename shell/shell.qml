import QtQuick
import QtWebSockets
import "components"

QtObject {
    id: dfsMain

    // --- ГЛОБАЛЬНОЕ СОСТОЯНИЕ (STATE) ---
    property string currentWorkspace: "Try to connect to the realm..."
    property string activeWindow: "Hearing Wayland spirits"

    // --- ЕДИНАЯ ТОЧКА СВЯЗИ С БЭКЕНДОМ ---
    property WebSocket globalSocket: WebSocket {
        url: "ws://localhost:7777/ws"
        active: true
        
        onTextMessageReceived: (message) => {
            let payload = JSON.parse(message)

            if (payload.event === "workspace") {
                dfsMain.currentWorkspace = "Realm: " + payload.data
            } else if (payload.event === "activewindow") {
                let windowName = payload.data.split(",")[0]
                dfsMain.activeWindow = windowName ? windowName : "Void"
            }
            // В будущем добавим сюда: else if (payload.event === "network") ...
        }
    }

    // --- ИНТЕРФЕЙС ---
    // Вызываем панель и прокидываем в нее текущее состояние
    property TopBar topBar: TopBar {
        workspaceRuneText: dfsMain.currentWorkspace
        activeEntityText: dfsMain.activeWindow
    }
    
    // property NetworkMenu netMenu: NetworkMenu {
    //     wifiStatus: dfsMain.currentWifi
    // }
}