import QtQuick
import "../../core/platform"
import "../shared"

Item {
    id: root

    readonly property var settings: GlobalState.config.modules.Workspaces || ({})
    readonly property var theme: GlobalState.effectiveTheme
    readonly property int workspaceCount: Math.max(1, Math.min(10, Number(settings.count) || 10))
    readonly property int buttonWidth: 27
    readonly property int buttonGap: 4
    readonly property int motionBase: Math.max(0, Number(settings.animationDuration) || 250)

    implicitWidth: workspaceRow.implicitWidth
    implicitHeight: workspaceRow.implicitHeight
    width: implicitWidth
    height: implicitHeight

    function toRoman(num) {
        const romanMap = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
        return settings.romanNumerals === false ? String(num) : (romanMap[num] || String(num))
    }

    Row {
        id: workspaceRow
        spacing: root.buttonGap
        anchors.centerIn: parent

        Repeater {
            model: root.workspaceCount

            delegate: Item {
                id: workspaceButton
                required property int index
                readonly property int workspaceId: index + 1
                readonly property bool isActive: CompositorAdapter.focusedWorkspace !== null &&
                                                 CompositorAdapter.focusedWorkspace !== undefined &&
                                                 Number(CompositorAdapter.focusedWorkspace.id) === workspaceId
                property bool hovered: false

                width: root.buttonWidth
                height: 29
                scale: hovered && !isActive ? 1.04 : 1.0
                Behavior on scale { NumberAnimation { duration: GlobalState.animationDuration(root.motionBase * 0.48); easing.type: Easing.OutCubic } }

                // The unchanging outer footprint keeps the panel centered while
                // workspaces switch; only inner engraving/metal tint animates.
                Rectangle {
                    id: plate
                    anchors.fill: parent
                    radius: 5
                    color: workspaceButton.isActive ? root.theme.borderActive :
                           (workspaceButton.hovered ? root.theme.bgHover : root.theme.bgAlt)
                    border.width: 1
                    border.color: workspaceButton.isActive ? root.theme.accentActive : root.theme.frame
                    Behavior on color { ColorAnimation { duration: GlobalState.animationDuration(root.motionBase * 0.60) } }
                    Behavior on border.color { ColorAnimation { duration: GlobalState.animationDuration(root.motionBase * 0.60) } }
                }

                Rectangle {
                    anchors.fill: plate
                    anchors.margins: 3
                    radius: 3
                    color: "transparent"
                    border.width: GlobalState.ornamentsEnabled ? 1 : 0
                    border.color: root.theme.rune
                    opacity: workspaceButton.isActive ? 0.55 : 0.2
                }

                // Small metal rivets at the top corners; no blur/shadow layers.
                Rectangle {
                    x: 4; y: 4; width: 3; height: 3; rotation: 45
                    visible: GlobalState.ornamentsEnabled
                    color: workspaceButton.isActive ? root.theme.accentGlow : root.theme.rune
                    opacity: workspaceButton.isActive ? 0.95 : 0.55
                }
                Rectangle {
                    x: workspaceButton.width - 7; y: 4; width: 3; height: 3; rotation: 45
                    visible: GlobalState.ornamentsEnabled
                    color: workspaceButton.isActive ? root.theme.accentGlow : root.theme.rune
                    opacity: workspaceButton.isActive ? 0.95 : 0.55
                }

                Text {
                    anchors.centerIn: parent
                    text: root.toRoman(workspaceButton.workspaceId)
                    color: workspaceButton.isActive ? root.theme.textLight : root.theme.textDark
                    font.family: root.theme.font
                    font.pixelSize: workspaceButton.isActive ? 11 : 10
                    font.bold: workspaceButton.isActive
                    Behavior on color { ColorAnimation { duration: GlobalState.animationDuration(root.motionBase * 0.60) } }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1
                    width: workspaceButton.isActive ? 11 : 3
                    height: 2
                    radius: 1
                    color: root.theme.accentGlow || root.theme.accentActive
                    opacity: workspaceButton.isActive ? 0.95 : 0.3
                    Behavior on width { NumberAnimation { duration: GlobalState.animationDuration(root.motionBase * 0.64); easing.type: Easing.OutCubic } }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 5
                    color: "transparent"
                    border.width: 1
                    border.color: root.theme.accentGlow || root.theme.accentActive
                    opacity: 0
                    SequentialAnimation on opacity {
                        running: workspaceButton.isActive && GlobalState.idleEffectsEnabled
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.18; duration: GlobalState.animationDuration(root.motionBase * 5.2); easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.55; duration: GlobalState.animationDuration(root.motionBase * 5.2); easing.type: Easing.InOutSine }
                    }
                }

                MouseArea {
                    id: workspaceHit
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: workspaceButton.hovered = true
                    onExited: workspaceButton.hovered = false
                    onClicked: CompositorAdapter.focusWorkspace(workspaceButton.workspaceId)
                }
                ThemeToolTip {
                    targetItem: workspaceHit
                    visible: workspaceHit.containsMouse
                    text: "Перейти к рабочему столу " + workspaceButton.workspaceId
                }
            }
        }
    }
}
