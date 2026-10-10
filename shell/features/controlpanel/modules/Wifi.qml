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

    property string activeSsid: ""
    property bool wifiEnabled: false
    property bool wiredConnected: false
    property bool isActive: wifiEnabled && activeSsid !== ""

    Timer {
        interval: 2000
        running: panel && panel.visible && !panel.isMenuOpen
        repeat: true
        triggeredOnStart: true
        onTriggered: { wifiProc.running = false; wifiProc.running = true }
    }

    Process {
        id: wifiProc
        command: ["sh", "-c", "printf '%s|%s|%s\\n' \"$(nmcli -t -f active,ssid dev wifi | awk -F: '$1 ~ /^yes$/ {print substr($0, index($0, \":\") + 1); exit}')\" \"$(nmcli radio wifi)\" \"$(nmcli -t -f TYPE,STATE dev | awk -F: '$1 ~ /ethernet/ && $2 ~ /connected/ {print 1; exit}')\""]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split("|")
                if (parts.length >= 3) {
                    wifiMod.activeSsid = parts[0]
                    wifiMod.wifiEnabled = (parts[1] === "enabled")
                    wifiMod.wiredConnected = (parts[2] === "1")
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
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    spacing: 8
                    Text {
                        visible: modConf.showIcon !== false
                        text: ""
                        color: isActive ? theme.textLight : theme.textMain
                        font.family: theme.font
                        font.pixelSize: 17
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 2
                        Text {
                            text: "Wi-Fi"
                            color: isActive ? theme.textLight : theme.textMain
                            font.family: theme.font
                            font.pixelSize: 12
                            font.bold: true
                        }
                        Text {
                            visible: modConf.showSsid !== false
                            text: activeSsid || (wifiEnabled ? "Не подключено" : "Wi-Fi выключен")
                            color: isActive ? theme.textLight : theme.textDark
                            font.family: theme.font
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                    Rectangle {
                        visible: wifiMod.wiredConnected
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 18
                        radius: 4
                        color: theme.bgAlt
                        border.width: 1
                        border.color: theme.frame
                        Text {
                            anchors.centerIn: parent
                            text: "ETH ✓"
                            color: theme.rune || theme.textDark
                            font.family: theme.font
                            font.pixelSize: 8
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: panel.runCommand(["nmcli", "radio", "wifi", wifiEnabled ? "off" : "on"])
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
