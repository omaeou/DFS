import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../shared"

Item {
    id: root
    property var panel: null
    property var theme: GlobalState.effectiveTheme
    property var modConf: ({})

    implicitWidth: 292
    implicitHeight: 90

    readonly property var skinIds: ["bloodsteel", "ashen", "obsidian", "verdigris", "alchemy", "runes", "custom"]
    readonly property var skinNames: ["Bloodsteel", "Ashen", "Obsidian", "Verdigris", "Alchemy", "Runes", "Custom"]
    readonly property var schemeIds: ["crimson", "violet", "frost", "jade", "amber"]
    readonly property var schemeNames: ["Crimson", "Violet", "Frost", "Jade", "Amber"]
    readonly property var animationIds: ["full", "balanced", "reduced", "off"]
    readonly property var animationNames: ["Full", "Balanced", "Reduced", "Off"]

    Rectangle {
        anchors.fill: parent
        radius: Number(root.theme.elementRadius) || 8
        color: root.theme.surfaceBottom || root.theme.bg
        border.width: 1
        border.color: root.theme.frame || root.theme.border
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: Math.max(2, (Number(root.theme.elementRadius) || 8) - 3)
        color: "transparent"
        border.width: GlobalState.ornamentsEnabled ? 1 : 0
        border.color: root.theme.rune || root.theme.frame
        opacity: 0.16
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 7
        anchors.bottomMargin: 7
        spacing: 5

        RowLayout {
            Layout.fillWidth: true
            spacing: 5
            Text {
                text: "ᛉ  APPEARANCE FORGE"
                color: root.theme.rune || root.theme.textDark
                font.family: root.theme.font
                font.pixelSize: 8
                font.letterSpacing: 1
            }
            Item { Layout.fillWidth: true }
            Text {
                text: GlobalState.config.appearance.animations.toUpperCase()
                color: root.theme.textDark
                font.family: root.theme.font
                font.pixelSize: 7
                font.letterSpacing: 0.5
            }
            Rectangle {
                id: ornamentsToggle
                property bool active: GlobalState.config.appearance.ornaments === true
                width: 43; height: 20; radius: 4
                color: active ? root.theme.bgHover : root.theme.bgAlt
                border.width: active ? 1.5 : 1
                border.color: active ? (root.theme.accentActive || root.theme.accent) : root.theme.frame
                scale: ornamentsMouse.pressed ? 0.96 : 1.0
                Behavior on color { ColorAnimation { duration: GlobalState.animationDuration(110) } }
                Behavior on border.color { ColorAnimation { duration: GlobalState.animationDuration(110) } }
                Behavior on scale { NumberAnimation { duration: GlobalState.animationDuration(100); easing.type: Easing.OutCubic } }
                Text {
                    anchors.centerIn: parent
                    text: "ᛟ " + (ornamentsToggle.active ? "ON" : "OFF")
                    color: ornamentsToggle.active ? (root.theme.accentGlow || root.theme.textLight) : root.theme.textDark
                    font.family: root.theme.font
                    font.pixelSize: 7
                    font.bold: ornamentsToggle.active
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 2
                    radius: 1
                    color: root.theme.accentActive || root.theme.accent
                    visible: ornamentsToggle.active
                }
                MouseArea {
                    id: ornamentsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: GlobalState.updateAppearance("ornaments", !GlobalState.config.appearance.ornaments)
                }
                ThemeToolTip { targetItem: ornamentsMouse; visible: ornamentsMouse.containsMouse; text: "Металлические украшения: " + (ornamentsToggle.active ? "включены" : "выключены") }
            }
            Rectangle {
                id: glowToggle
                property bool active: GlobalState.config.appearance.glow === true
                width: 43; height: 20; radius: 4
                color: active ? root.theme.bgHover : root.theme.bgAlt
                border.width: active ? 1.5 : 1
                border.color: active ? (root.theme.accentActive || root.theme.accent) : root.theme.frame
                scale: glowMouse.pressed ? 0.96 : 1.0
                Behavior on color { ColorAnimation { duration: GlobalState.animationDuration(110) } }
                Behavior on border.color { ColorAnimation { duration: GlobalState.animationDuration(110) } }
                Behavior on scale { NumberAnimation { duration: GlobalState.animationDuration(100); easing.type: Easing.OutCubic } }
                Text {
                    anchors.centerIn: parent
                    text: "✧ " + (glowToggle.active ? "ON" : "OFF")
                    color: glowToggle.active ? (root.theme.accentGlow || root.theme.textLight) : root.theme.textDark
                    font.family: root.theme.font
                    font.pixelSize: 7
                    font.bold: glowToggle.active
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 2
                    radius: 1
                    color: root.theme.accentActive || root.theme.accent
                    visible: glowToggle.active
                }
                MouseArea {
                    id: glowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: GlobalState.updateAppearance("glow", !GlobalState.config.appearance.glow)
                }
                ThemeToolTip { targetItem: glowMouse; visible: glowMouse.containsMouse; text: "Свечение рун: " + (glowToggle.active ? "включено" : "выключено") }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            ComboBox {
                id: skinCombo
                hoverEnabled: true
                Layout.fillWidth: true
                Layout.preferredWidth: 98
                Layout.minimumWidth: 80
                implicitWidth: 98
                implicitHeight: 28
                model: root.skinNames
                currentIndex: Math.max(0, root.skinIds.indexOf(GlobalState.config.appearance.skin))
                onActivated: function(index) { GlobalState.updateAppearance("skin", root.skinIds[index]) }
                contentItem: Text {
                    leftPadding: 7
                    rightPadding: 16
                    text: skinCombo.displayText
                    color: root.theme.textMain
                    font.family: root.theme.font
                    font.pixelSize: 9
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                indicator: Text {
                    x: skinCombo.width - width - 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: "⌄"
                    color: root.theme.rune || root.theme.textDark
                    font.pixelSize: 12
                }
                background: Rectangle {
                    radius: 5
                    color: root.theme.bgAlt
                    border.width: 1
                    border.color: skinCombo.popup.visible ? (root.theme.accentActive || root.theme.frame) : root.theme.frame
                }
                delegate: ItemDelegate {
                    required property string modelData
                    width: skinCombo.width
                    height: 29
                    highlighted: skinCombo.highlightedIndex === index
                    contentItem: Text {
                        text: modelData
                        color: parent.highlighted ? root.theme.textLight : root.theme.textMain
                        font.family: root.theme.font
                        font.pixelSize: 10
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 3
                        color: parent.highlighted ? root.theme.bgHover : "transparent"
                    }
                }
                popup: Popup {
                    y: skinCombo.height - 1
                    width: skinCombo.width
                    padding: 4
                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: skinCombo.popup.visible ? skinCombo.delegateModel : null
                        currentIndex: skinCombo.highlightedIndex
                        interactive: false
                    }
                    background: Rectangle {
                        radius: 6
                        color: root.theme.bg
                        border.width: 1
                        border.color: root.theme.frame
                    }
                }
                ThemeToolTip { targetItem: skinCombo; visible: skinCombo.hovered; text: "Выбрать материал оболочки: сталь, обсидиан, нефрит и другие темы" }
            }

            ComboBox {
                id: schemeCombo
                hoverEnabled: true
                Layout.fillWidth: true
                Layout.preferredWidth: 98
                Layout.minimumWidth: 80
                implicitWidth: 98
                implicitHeight: 28
                model: root.schemeNames
                currentIndex: Math.max(0, root.schemeIds.indexOf(GlobalState.config.appearance.colorScheme))
                onActivated: function(index) { GlobalState.updateAppearance("colorScheme", root.schemeIds[index]) }
                contentItem: Text {
                    leftPadding: 7
                    rightPadding: 16
                    text: schemeCombo.displayText
                    color: root.theme.textMain
                    font.family: root.theme.font
                    font.pixelSize: 9
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                indicator: Text {
                    x: schemeCombo.width - width - 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: "⌄"
                    color: root.theme.rune || root.theme.textDark
                    font.pixelSize: 12
                }
                background: Rectangle {
                    radius: 5
                    color: root.theme.bgAlt
                    border.width: 1
                    border.color: schemeCombo.popup.visible ? (root.theme.accentActive || root.theme.frame) : root.theme.frame
                }
                delegate: ItemDelegate {
                    required property string modelData
                    width: schemeCombo.width
                    height: 29
                    highlighted: schemeCombo.highlightedIndex === index
                    contentItem: Text {
                        text: modelData
                        color: parent.highlighted ? root.theme.textLight : root.theme.textMain
                        font.family: root.theme.font
                        font.pixelSize: 10
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 3
                        color: parent.highlighted ? root.theme.bgHover : "transparent"
                    }
                }
                popup: Popup {
                    y: schemeCombo.height - 1
                    width: schemeCombo.width
                    padding: 4
                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: schemeCombo.popup.visible ? schemeCombo.delegateModel : null
                        currentIndex: schemeCombo.highlightedIndex
                        interactive: false
                    }
                    background: Rectangle {
                        radius: 6
                        color: root.theme.bg
                        border.width: 1
                        border.color: root.theme.frame
                    }
                }
                ThemeToolTip { targetItem: schemeCombo; visible: schemeCombo.hovered; text: "Выбрать цвет свечения и активных рун" }
            }

            ComboBox {
                id: animationCombo
                hoverEnabled: true
                Layout.fillWidth: true
                Layout.preferredWidth: 98
                Layout.minimumWidth: 80
                implicitWidth: 98
                implicitHeight: 28
                model: root.animationNames
                currentIndex: Math.max(0, root.animationIds.indexOf(GlobalState.config.appearance.animations))
                onActivated: function(index) { GlobalState.updateAppearance("animations", root.animationIds[index]) }
                contentItem: Text {
                    leftPadding: 7
                    rightPadding: 16
                    text: animationCombo.displayText
                    color: root.theme.textMain
                    font.family: root.theme.font
                    font.pixelSize: 9
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                indicator: Text {
                    x: animationCombo.width - width - 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: "⌄"
                    color: root.theme.rune || root.theme.textDark
                    font.pixelSize: 12
                }
                background: Rectangle {
                    radius: 5
                    color: root.theme.bgAlt
                    border.width: 1
                    border.color: animationCombo.popup.visible ? (root.theme.accentActive || root.theme.frame) : root.theme.frame
                }
                delegate: ItemDelegate {
                    required property string modelData
                    width: animationCombo.width
                    height: 29
                    highlighted: animationCombo.highlightedIndex === index
                    contentItem: Text {
                        text: modelData
                        color: parent.highlighted ? root.theme.textLight : root.theme.textMain
                        font.family: root.theme.font
                        font.pixelSize: 10
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 3
                        color: parent.highlighted ? root.theme.bgHover : "transparent"
                    }
                }
                popup: Popup {
                    y: animationCombo.height - 1
                    width: animationCombo.width
                    padding: 4
                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: animationCombo.popup.visible ? animationCombo.delegateModel : null
                        currentIndex: animationCombo.highlightedIndex
                        interactive: false
                    }
                    background: Rectangle {
                        radius: 6
                        color: root.theme.bg
                        border.width: 1
                        border.color: root.theme.frame
                    }
                }
                ThemeToolTip { targetItem: animationCombo; visible: animationCombo.hovered; text: "Настроить интенсивность анимаций оболочки" }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Rectangle {
                Layout.preferredWidth: 5
                Layout.preferredHeight: 5
                radius: 1
                rotation: 45
                color: root.theme.accentActive || root.theme.accent
            }
            Text {
                Layout.fillWidth: true
                text: "ACTIVE · " + String(GlobalState.config.appearance.skin).toUpperCase() +
                      " / " + String(GlobalState.config.appearance.colorScheme).toUpperCase() +
                      " / " + String(GlobalState.config.appearance.animations).toUpperCase()
                color: root.theme.rune || root.theme.textDark
                font.family: root.theme.font
                font.pixelSize: 7
                font.letterSpacing: 0.35
                elide: Text.ElideRight
            }
        }

    }
}
