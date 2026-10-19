import QtQuick
import Quickshell
import "../../shared"
import "../../../core/services"
import "."

Item {
    id: root
    implicitWidth: 28
    implicitHeight: 28

    Loader {
        id: pickerLoader
        active: true
        source: Qt.resolvedUrl("WallpaperPicker.qml")
    }

    BarButtonPlate {
        anchors.fill: parent
        active: WallpaperService.selectedIndex >= 0
        hovered: hit.containsMouse

        Text {
            anchors.centerIn: parent
            text: "◐"
            color: GlobalState.effectiveTheme.rune
            font.family: GlobalState.effectiveTheme.font
            font.pixelSize: 16
        }

        MouseArea {
            id: hit
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    WallpaperService.next()
                    return
                }
                if (pickerLoader.item)
                    pickerLoader.item.showFor(root)
            }
        }

        ThemeToolTip {
            targetItem: hit
            visible: hit.containsMouse
            text: WallpaperService.wallpapers.length === 0
                ? "Выбор обоев · добавьте пути в wallpapers в config.json"
                : "Выбрать обои · правый клик — следующие"
                    + (WallpaperService.currentPath ? "\nСейчас: " + WallpaperService.currentPath : "")
        }
    }
}
