import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../shared"
import "../../../core/services"

Item {
    id: wifiMod
    implicitWidth: 150
    implicitHeight: 98
    property var panel: null
    property var theme: GlobalState.effectiveTheme
    property var modConf: ({})
    readonly property string activeSsid: ConnectivityService.activeSsid
    readonly property bool wifiEnabled: ConnectivityService.wifiEnabled
    readonly property bool wiredConnected: ConnectivityService.wiredConnected

    Rectangle {
        anchors.fill: parent
        radius: theme.elementRadius
        color: theme.bgAlt
        border.width: 1
        border.color: (wifiMod.activeSsid || wifiMod.wiredConnected) ? theme.accentActive : theme.frame
        gradient: Gradient {
            GradientStop { position: 0; color: (wifiMod.activeSsid || wifiMod.wiredConnected) ? theme.borderActive : theme.surfaceTop }
            GradientStop { position: 1; color: theme.surfaceBottom || theme.bgAlt }
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 5
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    text: wifiMod.wifiEnabled ? "" : "󰖪"
                    color: wifiMod.activeSsid ? theme.accentGlow : theme.rune
                    font.family: theme.font
                    font.pixelSize: 15
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 1
                    Text { text: "Wi-Fi"; color: theme.textMain; font.family: theme.font; font.pixelSize: 11; font.bold: true }
                    Text {
                        Layout.fillWidth: true
                        text: wifiMod.activeSsid || (wifiMod.wifiEnabled ? "Включён · нет сети" : "Выключен")
                        textFormat: Text.PlainText
                        color: wifiMod.activeSsid ? theme.textLight : theme.textDark
                        font.family: theme.font; font.pixelSize: 8; elide: Text.ElideRight
                    }
                }
                Rectangle {
                    Layout.preferredWidth: 37; Layout.preferredHeight: 21; radius: 5
                    color: wifiMod.wifiEnabled ? theme.borderActive : theme.bg
                    border.color: wifiMod.wifiEnabled ? theme.accentActive : theme.frame
                    Text { anchors.centerIn: parent; text: wifiMod.wifiEnabled ? "ВКЛ" : "ВЫКЛ"; color: theme.textMain; font.family: theme.font; font.pixelSize: 8 }
                    MouseArea {
                        id: wifiToggleHit
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: panel.runCommand(["nmcli", "radio", "wifi", wifiMod.wifiEnabled ? "off" : "on"])
                    }
                    ThemeToolTip { targetItem: wifiToggleHit; visible: wifiToggleHit.containsMouse; text: wifiMod.wifiEnabled ? "Выключить Wi-Fi" : "Включить Wi-Fi" }
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; opacity: 0.8 }
            RowLayout {
                Layout.fillWidth: true
                spacing: 5
                Text { text: "󰈀"; color: wifiMod.wiredConnected ? theme.accentGlow : theme.textDark; font.family: theme.font; font.pixelSize: 12 }
                Text {
                    Layout.fillWidth: true
                    text: "Ethernet · " + (wifiMod.wiredConnected ? "подключён" : "нет кабеля")
                    color: wifiMod.wiredConnected ? theme.textMain : theme.textDark
                    font.family: theme.font; font.pixelSize: 8; elide: Text.ElideRight
                }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 23; radius: 5
                color: scanArea.containsMouse ? theme.bgHover : theme.surfaceBottom
                border.color: scanArea.containsMouse ? theme.accent : theme.frame
                Text { anchors.centerIn: parent; text: "Сети Wi-Fi  ›"; color: theme.rune; font.family: theme.font; font.pixelSize: 9 }
                MouseArea {
                    id: scanArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: panel.openCustomMenu("wifi", "СЕТИ · WI-FI")
                }
                ThemeToolTip { targetItem: scanArea; visible: scanArea.containsMouse; text: "Открыть список доступных Wi-Fi сетей" }
            }
        }
    }
}
