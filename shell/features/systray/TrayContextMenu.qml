import QtQuick
import QtQuick.Controls
import Quickshell
import "../shared"

PopupWindow {
    id: root

    property var menuHandle: null
    property Item anchorItem: null
    property var parentMenuWindow: null
    property var rootMenuWindow: null
    property bool requestedOpen: false
    property var openSubmenu: null
    readonly property bool isSubmenu: parentMenuWindow !== null
    readonly property var theme: GlobalState.effectiveTheme

    visible: requestedOpen && (!parentMenuWindow || parentMenuWindow.visible)
    grabFocus: true
    color: "transparent"
    width: 292
    height: Math.max(44, Math.min(520, menuList.implicitHeight + 16))

    anchor.item: anchorItem
    anchor.edges: isSubmenu ? (Edges.Right | Edges.Top) : (Edges.Bottom | Edges.Left)
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.adjustment: PopupAdjustment.All

    QsMenuOpener {
        id: menuOpener
        menu: root.menuHandle
    }

    onVisibleChanged: {
        if (!visible) {
            requestedOpen = false
            openSubmenu = null
        }
    }

    function closeTree() {
        const owner = rootMenuWindow || root
        owner.requestedOpen = false
    }

    function showFor(targetItem, targetMenu) {
        if (visible && anchorItem === targetItem) {
            requestedOpen = false
            return
        }

        const wasVisible = visible
        requestedOpen = false
        anchorItem = targetItem
        menuHandle = targetMenu

        if (wasVisible) {
            // PopupWindow snapshots its anchor when it opens.
            Qt.callLater(function() { root.requestedOpen = true })
        } else {
            requestedOpen = true
        }
    }

    function closeSiblingSubmenus(except) {
        if (openSubmenu && openSubmenu !== except)
            openSubmenu.requestedOpen = false
        openSubmenu = except || null
    }

    Rectangle {
        id: menuFrame
        anchors.fill: parent
        radius: Math.max(6, Number(root.theme.elementRadius) || 8)
        color: root.theme.bg
        border.width: 1
        border.color: root.theme.frame
        antialiasing: true

        gradient: Gradient {
            GradientStop { position: 0; color: root.theme.surfaceTop }
            GradientStop { position: 0.5; color: root.theme.bgAlt }
            GradientStop { position: 1; color: root.theme.surfaceBottom }
        }

        Rectangle {
            x: 14
            y: 0
            width: 34
            height: 2
            radius: 1
            color: root.theme.accentGlow
            opacity: GlobalState.config.appearance.glow ? 0.82 : 0.42
        }

        Text {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.rightMargin: 11
            text: "ᛉ"
            visible: GlobalState.ornamentsEnabled
            color: root.theme.rune
            font.family: root.theme.font
            font.pixelSize: 9
            opacity: 0.8
        }

        Flickable {
            id: menuFlick
            anchors.fill: parent
            anchors.margins: 8
            clip: true
            contentWidth: width
            contentHeight: menuList.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: menuList
                width: menuFlick.width
                spacing: 2

                Repeater {
                    model: menuOpener.children

                    delegate: Item {
                        id: menuEntry
                        required property var modelData
                        readonly property bool separator: modelData.isSeparator
                        readonly property bool hasSubmenu: modelData.hasChildren
                        readonly property var submenuWindow: submenuLoader.item

                        width: menuList.width
                        implicitHeight: separator ? 9 : 30
                        height: implicitHeight

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 1
                            visible: menuEntry.separator
                            color: root.theme.frame
                            opacity: 0.72
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: 5
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: 3
                            rotation: 45
                            visible: menuEntry.separator && GlobalState.ornamentsEnabled
                            color: root.theme.rune
                        }

                        Rectangle {
                            id: rowPlate
                            anchors.fill: parent
                            visible: !menuEntry.separator
                            radius: Math.max(3, Number(root.theme.elementRadius) - 3)
                            color: rowMouse.containsMouse ? root.theme.bgHover : "transparent"
                            border.width: rowMouse.containsMouse ? 1 : 0
                            border.color: rowMouse.containsMouse ? root.theme.accentActive : root.theme.frame
                            opacity: menuEntry.modelData.enabled ? 1 : 0.52
                            Behavior on color { ColorAnimation { duration: GlobalState.animationDuration(90) } }

                            Rectangle {
                                x: 4
                                y: 4
                                width: 2
                                height: parent.height - 8
                                radius: 1
                                visible: rowMouse.containsMouse
                                color: root.theme.accentGlow
                                opacity: 0.85
                            }
                        }

                        Item {
                            id: entryGlyph
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20
                            height: 20
                            visible: !menuEntry.separator

                            Image {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                visible: menuEntry.modelData.icon !== ""
                                source: menuEntry.modelData.icon
                                sourceSize.width: width
                                sourceSize.height: height
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                mipmap: true
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: menuEntry.modelData.icon === ""
                                    && menuEntry.modelData.buttonType !== QsMenuButtonType.None
                                text: menuEntry.modelData.buttonType === QsMenuButtonType.RadioButton
                                    ? (menuEntry.modelData.checkState === Qt.Checked ? "◆" : "◇")
                                    : (menuEntry.modelData.checkState === Qt.Checked ? "✓"
                                        : (menuEntry.modelData.checkState === Qt.PartiallyChecked ? "−" : ""))
                                color: menuEntry.modelData.checkState === Qt.Checked ? root.theme.accentGlow : root.theme.rune
                                font.family: root.theme.font
                                font.pixelSize: 14
                            }
                        }

                        Text {
                            id: entryLabel
                            anchors.left: entryGlyph.right
                            anchors.leftMargin: 5
                            anchors.right: submenuMark.left
                            anchors.rightMargin: 7
                            anchors.verticalCenter: parent.verticalCenter
                            text: menuEntry.modelData.text
                            color: rowMouse.containsMouse ? root.theme.textLight : root.theme.textMain
                            font.family: root.theme.font
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            id: submenuMark
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            visible: menuEntry.hasSubmenu
                            text: "›"
                            color: rowMouse.containsMouse ? root.theme.accentGlow : root.theme.rune
                            font.family: root.theme.font
                            font.pixelSize: 18
                        }

                        LazyLoader {
                            id: submenuLoader
                            active: menuEntry.hasSubmenu
                            source: active ? Qt.resolvedUrl("TrayContextMenu.qml") : ""
                            onActiveChanged: {
                                if (active) {
                                    Qt.callLater(function() {
                                        if (!item)
                                            return
                                        item.menuHandle = menuEntry.modelData
                                        item.anchorItem = menuEntry
                                        item.parentMenuWindow = root
                                        item.rootMenuWindow = root.rootMenuWindow || root
                                    })
                                }
                            }
                        }

                        Timer {
                            id: submenuDelay
                            interval: 120
                            repeat: false
                            onTriggered: {
                                if (submenuLoader.item && menuEntry.modelData.enabled) {
                                    root.closeSiblingSubmenus(submenuLoader.item)
                                    submenuLoader.item.requestedOpen = true
                                }
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            visible: !menuEntry.separator
                            enabled: menuEntry.modelData.enabled
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton
                            cursorShape: Qt.PointingHandCursor

                            onEntered: {
                                root.closeSiblingSubmenus(menuEntry.hasSubmenu ? submenuLoader.item : null)
                                if (menuEntry.hasSubmenu)
                                    submenuDelay.restart()
                            }
                            onExited: submenuDelay.stop()
                            onClicked: {
                                if (menuEntry.hasSubmenu) {
                                    submenuDelay.stop()
                                    root.closeSiblingSubmenus(submenuLoader.item)
                                    if (submenuLoader.item)
                                        submenuLoader.item.requestedOpen = true
                                } else {
                                    menuEntry.modelData.triggered()
                                    root.closeTree()
                                }
                            }
                        }

                        ThemeToolTip {
                            targetItem: rowMouse
                            visible: rowMouse.containsMouse && entryLabel.truncated
                            text: menuEntry.modelData.text
                        }
                    }
                }
            }
        }
    }
}
