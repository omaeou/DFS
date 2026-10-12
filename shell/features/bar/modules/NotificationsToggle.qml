import QtQuick
import QtQuick.Controls
import "../../shared"
import "../../../core/services"

Item {
    implicitWidth: 28
    implicitHeight: 28
    Rectangle {
        anchors.fill: parent; radius: 7
        color: hit.containsMouse ? GlobalState.effectiveTheme.bgHover : GlobalState.effectiveTheme.bgAlt
        border.color: GlobalState.effectiveTheme.frame
        Text {
            anchors.centerIn: parent
            text: NotificationService.history.count > 0 ? "✦" : "♧"
            color: GlobalState.effectiveTheme.rune
            font.pixelSize: 15
        }
        Text {
            visible: NotificationService.history.count > 0
            anchors.right: parent.right; anchors.top: parent.top
            text: NotificationService.history.count
            color: GlobalState.effectiveTheme.accentActive
            font.pixelSize: 8
        }
        MouseArea { id: hit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: GlobalState.isNotificationsOpen = !GlobalState.isNotificationsOpen }
        ThemeToolTip { targetItem: hit; visible: hit.containsMouse; text: "Открыть уведомления · " + NotificationService.history.count }
    }
}
