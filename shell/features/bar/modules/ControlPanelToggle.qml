import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../shared"
import "."

Item {
    id: root
    implicitWidth: 28
    implicitHeight: 27
    width: implicitWidth
    height: implicitHeight
    property bool hovered: false

    BarButtonPlate {
        anchors.fill: parent
        active: GlobalState.isControlPanelOpen
        hovered: root.hovered
        cornerRadius: 6

        Text {
            anchors.centerIn: parent
            text: "⚙"
            color: GlobalState.isControlPanelOpen ? GlobalState.effectiveTheme.textLight : GlobalState.effectiveTheme.textMain
            font.family: GlobalState.effectiveTheme.font
            font.pixelSize: 14
        }

        MouseArea {
            id: controlHit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.hovered = true
            onExited: root.hovered = false
            onClicked: GlobalState.toggleControlPanel()
        }
        ThemeToolTip { targetItem: controlHit; visible: controlHit.containsMouse; text: GlobalState.isControlPanelOpen ? "Закрыть системную панель" : "Открыть системную панель" }
    }
}
