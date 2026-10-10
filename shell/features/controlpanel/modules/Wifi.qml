import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../shared"

Item {
    id: wifiMod
    implicitWidth: 150
    implicitHeight: 52

    // API прокинутое из хоста
    property var panel: null
    property var theme: GlobalState.effectiveTheme
    property var modConf: ({})

    property string netType: "none"
    property string activeSsid: ""
    property bool wifiEnabled: false
    property bool isWired: netType === "802-3-ethernet" || netType === "ethernet"
    property bool isActive: isWired || (wifiEnabled && activeSsid !== "")

    Timer {
        interval: 2000
        running: panel && panel.visible && !panel.isMenuOpen
        repeat: true
        triggeredOnStart: true
        onTriggered: { wifiProc.running = false; wifiProc.running = true }
    }

    Process {
        id: wifiProc
        command: ["sh", "-c", "echo \"$(nmcli -t -f TYPE,STATE dev | awk -F: '/connected/ {print $1; exit}')|$(nmcli -t -f active,ssid dev wifi | awk -F: '/^yes/ {print $2; exit}')|$(nmcli radio wifi)\""]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split("|")
                if (parts.length >= 3) {
                    wifiMod.netType = parts[0]
                    wifiMod.activeSsid = parts[1]
                    wifiMod.wifiEnabled = (parts[2] === "enabled")
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent; radius: theme.elementRadius
        color: theme.bgAlt
        border.width: 1
        border.color: isActive ? theme.accentActive : theme.frame
        gradient: Gradient {
            GradientStop { position: 0.0; color: isActive ? theme.borderActive : theme.surfaceTop }
            GradientStop { position: 1.0; color: theme.surfaceBottom || theme.bgAlt }
        }

        RowLayout {
            anchors.fill: parent; spacing: 0
            Item {
                Layout.fillWidth: true; Layout.fillHeight: true
                RowLayout {
                    anchors.centerIn: parent; spacing: 8
                    Text { visible: modConf.showIcon !== false; text: isWired ? "󰈀" : ""; color: isActive ? theme.textLight : theme.textMain; font.family: theme.font; font.pixelSize: 16 }
                    ColumnLayout {
                        spacing: 2
                        Text { text: isWired ? "Ethernet" : "Wi-Fi"; color: isActive ? theme.textLight : theme.textMain; font.family: theme.font; font.pixelSize: 12; font.bold: true }
                        // Используем внутренний конфиг
                        Text { visible: modConf.showSsid !== false; text: isWired ? "Подключено" : (activeSsid || "Отключено"); color: isActive ? theme.textLight : theme.textDark; font.family: theme.font; font.pixelSize: 10; elide: Text.ElideRight; Layout.maximumWidth: 60 }
                    }
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: if (!isWired) panel.runCommand(["nmcli", "radio", "wifi", wifiEnabled ? "off" : "on"])
                }
            }
            Rectangle { width: 1; Layout.fillHeight: true; Layout.margins: 6; color: theme.border }
            Item {
                Layout.preferredWidth: 34; Layout.fillHeight: true
                Text { anchors.centerIn: parent; text: ""; color: theme.textMain; font.family: theme.font }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: panel.openCustomMenu("wifi", "Wi-Fi Сети") }
            }
        }
    }
}