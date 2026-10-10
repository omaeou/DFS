import QtQuick
import "../../features/shared"

// Example external module. Plugin QML executes with the current user's
// permissions; only enable plugins whose source you trust.
Item {
    id: root

    property string moduleId: "example-clock"
    property var settings: ({})
    property var theme: GlobalState.effectiveTheme

    implicitWidth: label.implicitWidth + 16
    implicitHeight: Math.max(24, label.implicitHeight + 8)

    Rectangle {
        anchors.fill: parent
        radius: theme.elementRadius || 6
        color: theme.bgHover || "#1f0000"
        border.color: theme.border || "#333333"
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: settings.label || "Example plugin"
        color: theme.textLight || "#ffffff"
        font.family: theme.font || "monospace"
        font.pixelSize: 10
    }
}
