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

    function safeIconSource(value) {
        const icon = String(value || "")
        if (!icon)
            return ""
        if (icon.startsWith("image://") || icon.startsWith("file:///"))
            return icon
        if (icon.startsWith("/"))
            return "file://" + icon
        if (icon.indexOf("/") < 0 && icon.indexOf(":") < 0)
            return Quickshell.iconPath(icon, true)
        return ""
    }

    LazyLoader {
        id: trayMenuLoader
        active: true
        source: Qt.resolvedUrl("TrayContextMenu.qml")
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

            ThemeToolTip {
                targetItem: itemArea
                visible: itemArea.containsMouse && modelData.title !== ""
                text: modelData.title
            }

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
                } else if (mouse.button === Qt.RightButton && modelData.hasMenu && modelData.menu) {
                    const menu = trayMenuLoader.item
                    if (!menu)
                        return

                    menu.showFor(itemArea, modelData.menu)
                } else if (mouse.button === Qt.MiddleButton) {
                    modelData.secondaryActivate()
                } else if (mouse.button === Qt.RightButton) {
                    modelData.secondaryActivate()
                } else if (modelData.hasMenu && modelData.menu) {
                    // Menu-only tray entries (for example some status icons)
                    // expose their menu as the primary action.
                    const menu = trayMenuLoader.item
                    if (menu)
                        menu.showFor(itemArea, modelData.menu)
                }
            }

            Image {
                anchors.centerIn: parent
                width: itemArea.iconSize
                height: itemArea.iconSize
                source: root.safeIconSource(modelData.icon)
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
