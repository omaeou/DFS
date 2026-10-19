import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../../shared"
import "../../../core/services"

PopupWindow {
    id: root

    property Item anchorItem: null
    property bool requestedOpen: false
    readonly property var theme: GlobalState.effectiveTheme

    visible: requestedOpen
    grabFocus: true
    color: "transparent"
    implicitWidth: 318
    implicitHeight: 414
    anchor.item: anchorItem
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.adjustment: PopupAdjustment.All

    onVisibleChanged: {
        if (!visible)
            requestedOpen = false
    }

    function showFor(targetItem) {
        if (visible && anchorItem === targetItem) {
            requestedOpen = false
            return
        }

        WallpaperService.refreshWallpapers()
        const wasVisible = visible
        requestedOpen = false
        anchorItem = targetItem
        if (wasVisible)
            Qt.callLater(function() { root.requestedOpen = true })
        else
            requestedOpen = true
    }

    Rectangle {
        anchors.fill: parent
        radius: Math.max(7, Number(root.theme.radius) || 10)
        color: root.theme.bg
        border.width: 1
        border.color: root.theme.frame
        antialiasing: true

        gradient: Gradient {
            GradientStop { position: 0; color: root.theme.surfaceTop }
            GradientStop { position: 1; color: root.theme.surfaceBottom }
        }

        Rectangle {
            x: 15; y: 0; width: 42; height: 2; radius: 1
            color: root.theme.accentGlow
            opacity: GlobalState.config.appearance.glow ? 0.88 : 0.4
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 9

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: "ОБИТЕЛЬ · ОБОИ"
                        color: root.theme.rune
                        font.family: root.theme.font
                        font.pixelSize: 9
                        font.letterSpacing: 1
                    }
                    Text {
                        text: WallpaperService.scanning ? "Поиск изображений в каталогах…" : WallpaperService.wallpapers.length + " найденных изображений"
                        color: root.theme.textDark
                        font.family: root.theme.font
                        font.pixelSize: 9
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 29
                    Layout.preferredHeight: 28
                    radius: 5
                    color: closeHit.containsMouse ? root.theme.bgHover : root.theme.bgAlt
                    border.width: 1
                    border.color: closeHit.containsMouse ? root.theme.accentActive : root.theme.frame
                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: root.theme.textLight
                        font.pixelSize: 18
                    }
                    MouseArea {
                        id: closeHit
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.requestedOpen = false
                    }
                    ThemeToolTip { targetItem: closeHit; visible: closeHit.containsMouse; text: "Закрыть выбор обоев" }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: root.theme.frame
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 7

                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 27
                    radius: 5
                    color: previousHit.containsMouse ? root.theme.bgHover : root.theme.bgAlt
                    border.width: 1
                    border.color: root.theme.frame
                    Text { anchors.centerIn: parent; text: "‹"; color: root.theme.textLight; font.pixelSize: 19 }
                    MouseArea {
                        id: previousHit
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: WallpaperService.previous()
                    }
                    ThemeToolTip { targetItem: previousHit; visible: previousHit.containsMouse; text: "Применить предыдущие обои" }
                }

                Text {
                    Layout.fillWidth: true
                    text: WallpaperService.currentPath || "Выберите изображение"
                    textFormat: Text.PlainText
                    color: root.theme.textMain
                    font.family: root.theme.font
                    font.pixelSize: 9
                    elide: Text.ElideMiddle
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 27
                    radius: 5
                    color: nextHit.containsMouse ? root.theme.bgHover : root.theme.bgAlt
                    border.width: 1
                    border.color: root.theme.frame
                    Text { anchors.centerIn: parent; text: "›"; color: root.theme.textLight; font.pixelSize: 19 }
                    MouseArea {
                        id: nextHit
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: WallpaperService.next()
                    }
                    ThemeToolTip { targetItem: nextHit; visible: nextHit.containsMouse; text: "Применить следующие обои" }
                }
            }

            GridView {
                id: wallpaperGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                cellWidth: 146
                cellHeight: 108
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: WallpaperService.wallpapers

                delegate: Rectangle {
                    id: wallpaperCard
                    required property int index
                    required property var modelData
                    width: wallpaperGrid.cellWidth - 8
                    height: wallpaperGrid.cellHeight - 8
                    radius: 6
                    color: WallpaperService.selectedIndex === wallpaperCard.index ? root.theme.bgHover : root.theme.bgAlt
                    border.width: WallpaperService.selectedIndex === wallpaperCard.index ? 2 : 1
                    border.color: WallpaperService.selectedIndex === wallpaperCard.index ? root.theme.accentActive : root.theme.frame
                    clip: true

                    Image {
                        id: wallpaperPreview
                        anchors.fill: parent
                        anchors.margins: 3
                        source: "file://" + WallpaperService.resolvePath(wallpaperCard.modelData)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 27
                        color: root.theme.bg
                        opacity: 0.9
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 7
                        text: String(wallpaperCard.modelData).split("/").pop()
                        color: root.theme.textLight
                        font.family: root.theme.font
                        font.pixelSize: 8
                        elide: Text.ElideMiddle
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: wallpaperPreview.status !== Image.Ready
                        text: "✦"
                        color: root.theme.rune
                        font.pixelSize: 24
                    }

                    MouseArea {
                        id: chooseHit
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: WallpaperService.applyIndex(wallpaperCard.index)
                    }
                    ThemeToolTip {
                        targetItem: chooseHit
                        visible: chooseHit.containsMouse
                        text: WallpaperService.resolvePath(wallpaperCard.modelData)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: WallpaperService.wallpapers.length === 0
                    width: parent.width - 24
                    text: WallpaperService.scanning ? "Ищем изображения в указанных каталогах…" : "Добавьте пути к файлам или каталогам с изображениями в wallpapers файла config.json."
                    color: root.theme.textDark
                    font.family: root.theme.font
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Text {
                Layout.fillWidth: true
                visible: WallpaperService.lastError !== ""
                text: WallpaperService.lastError
                textFormat: Text.PlainText
                color: root.theme.rune
                font.family: root.theme.font
                font.pixelSize: 9
                wrapMode: Text.Wrap
            }
        }
    }
}
