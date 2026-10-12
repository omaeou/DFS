import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "../../shared"

Item {
    id: root
    implicitWidth: 28
    implicitHeight: 28
    property int selectedWallpaper: -1
    Process { id: wallpaperProcess }
    Rectangle {
        anchors.fill: parent; radius: 7
        color: hit.containsMouse ? GlobalState.effectiveTheme.bgHover : GlobalState.effectiveTheme.bgAlt
        border.color: GlobalState.effectiveTheme.frame
        Text { anchors.centerIn: parent; text: "◐"; color: GlobalState.effectiveTheme.rune; font.pixelSize: 16 }
        MouseArea {
            id: hit
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: {
                const files = GlobalState.config.wallpapers || []
                if (files.length === 0) {
                    console.warn("[DFS:wallpaper] Add image paths to wallpapers in config.json")
                    return
                }
                root.selectedWallpaper = (root.selectedWallpaper + 1) % files.length
                wallpaperProcess.command = ["swww", "img", "--transition-type", "wipe", files[root.selectedWallpaper]]
                wallpaperProcess.running = false
                wallpaperProcess.running = true
            }
        }
        ThemeToolTip { targetItem: hit; visible: hit.containsMouse; text: "Сменить обои на следующий вариант из списка" }
    }
}
