import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray
import "../shared"

RowLayout {
    id: root
    readonly property var settings: GlobalState.config.modules.SysTray || ({})
    readonly property var theme: GlobalState.effectiveTheme
    spacing: Math.max(3, Number(settings.spacing) || 7)

    QsMenuAnchor {
        id: trayMenuAnchor
        anchor.edges: Edges.Bottom | Edges.Left
    }

    Repeater {
        model: SystemTray.items

        delegate: MouseArea {
            id: itemArea
            required property var modelData
            readonly property int iconSize: Math.max(12, Math.min(28, Number(root.settings.iconSize) || 20))

            implicitWidth: iconSize + 6
            implicitHeight: iconSize + 6
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

            ToolTip.visible: containsMouse && modelData.title !== ""
            ToolTip.text: modelData.title
            ToolTip.delay: 450

            Rectangle {
                anchors.fill: parent
                radius: 4
                color: itemArea.containsMouse ? root.theme.bgHover : "transparent"
                border.width: itemArea.containsMouse ? 1 : 0
                border.color: root.theme.frame
                Behavior on color { ColorAnimation { duration: GlobalState.animationDuration(100) } }
            }

            onClicked: (mouse) => {
                if (mouse.button === Qt.LeftButton && !modelData.onlyMenu) {
                    modelData.activate()
                } else if (modelData.hasMenu && modelData.menu) {
                    trayMenuAnchor.anchor.item = itemArea
                    trayMenuAnchor.menu = modelData.menu
                    trayMenuAnchor.open()
                } else if (mouse.button === Qt.RightButton) {
                    modelData.secondaryActivate()
                }
            }

            Image {
                anchors.centerIn: parent
                width: itemArea.iconSize
                height: itemArea.iconSize
                source: modelData.icon
                fillMode: Image.PreserveAspectFit
                mipmap: true
                smooth: true
                cache: true
                asynchronous: true
                sourceSize.width: width
                sourceSize.height: height
                opacity: itemArea.containsMouse ? 0.78 : 1.0
                Behavior on opacity { NumberAnimation { duration: GlobalState.animationDuration(100) } }
            }
        }
    }
}
