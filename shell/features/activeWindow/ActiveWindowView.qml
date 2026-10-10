import QtQuick
import QtQuick.Layouts
import "../../core/ipc"
import "../shared"

Text {
    id: root

    property string windowTitle: "Void"
    readonly property var settings: GlobalState.config.modules.ActiveWindow || ({})
    text: windowTitle
    color: GlobalState.effectiveTheme.accentActive
    font.family: GlobalState.effectiveTheme.font
    font.bold: true
    font.pixelSize: 12
    Layout.maximumWidth: Number(settings.maxWidth) || 250
    elide: Text.ElideRight

    Connections {
        target: DaemonClient
        function onEventReceived(event, data) {
            if (event === "activewindow") {
                const comma = data.indexOf(",")
                const title = comma >= 0 ? data.slice(comma + 1) : data
                root.windowTitle = title || "Void"
            }
        }
    }
}
