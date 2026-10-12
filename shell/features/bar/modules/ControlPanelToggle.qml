import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../shared"

Item {
    id: root
    implicitWidth: 28
    implicitHeight: 27
    width: implicitWidth
    height: implicitHeight
    property bool hovered: false

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: GlobalState.isControlPanelOpen ? GlobalState.effectiveTheme.borderActive :
               (root.hovered ? GlobalState.effectiveTheme.bgHover : GlobalState.effectiveTheme.bgAlt)
        border.width: 1
        border.color: GlobalState.isControlPanelOpen ? GlobalState.effectiveTheme.accentActive : GlobalState.effectiveTheme.frame
        Behavior on color { ColorAnimation { duration: GlobalState.animationDuration(120) } }
        Behavior on border.color { ColorAnimation { duration: GlobalState.animationDuration(120) } }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: 4
            color: "transparent"
            border.width: GlobalState.ornamentsEnabled ? 1 : 0
            border.color: GlobalState.effectiveTheme.rune
            opacity: 0.2
        }

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
