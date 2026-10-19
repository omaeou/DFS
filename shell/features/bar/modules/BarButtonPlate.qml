import QtQuick
import "../../shared"

Item {
    id: root

    default property alias contentData: content.data
    property bool active: false
    property bool hovered: false
    property int cornerRadius: 7

    implicitWidth: 28
    implicitHeight: 28

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.hovered ? GlobalState.effectiveTheme.bgHover : GlobalState.effectiveTheme.bgAlt
        border.width: 1
        border.color: root.active ? GlobalState.effectiveTheme.rune : (root.hovered ? GlobalState.effectiveTheme.accent : GlobalState.effectiveTheme.frame)
        gradient: Gradient {
            GradientStop { position: 0; color: root.active ? GlobalState.effectiveTheme.accent : (root.hovered ? GlobalState.effectiveTheme.bgHover : GlobalState.effectiveTheme.bgAlt) }
            GradientStop { position: 1; color: root.active ? GlobalState.effectiveTheme.surfaceBottom : GlobalState.effectiveTheme.bgAlt }
        }
        Behavior on border.color { ColorAnimation { duration: GlobalState.animationDuration(100) } }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        radius: Math.max(2, root.cornerRadius - 3)
        color: "transparent"
        border.width: GlobalState.ornamentsEnabled ? 1 : 0
        border.color: GlobalState.effectiveTheme.rune
        opacity: root.active ? 0.38 : 0.2
    }

    Item {
        id: content
        anchors.fill: parent
    }
}
