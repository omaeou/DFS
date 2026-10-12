import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../shared"

Item {
    id: btMod
    implicitWidth: 150
    implicitHeight: 98

    property var panel: null
    property var theme: GlobalState.effectiveTheme
    property var modConf: ({})
    property bool bluetoothEnabled: false

    Timer {
        interval: 3000
        running: panel && panel.visible && !panel.isMenuOpen
        repeat: true
        triggeredOnStart: true
        onTriggered: { stateProcess.running = false; stateProcess.running = true }
    }

    Process {
        id: stateProcess
        command: ["sh", "-c", "bluetoothctl show 2>/dev/null | awk -F': ' '/Powered:/ {print $2; exit}'"]
        stdout: SplitParser {
            onRead: data => { btMod.bluetoothEnabled = data.trim() === "yes" }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: theme.elementRadius
        color: theme.bgAlt
        border.width: 1
        border.color: bluetoothEnabled ? theme.accentActive : theme.frame
        gradient: Gradient {
            GradientStop { position: 0.0; color: bluetoothEnabled ? theme.borderActive : theme.surfaceTop }
            GradientStop { position: 1.0; color: theme.surfaceBottom || theme.bgAlt }
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        visible: modConf.showIcon !== false
                        text: "󰂯"
                        color: bluetoothEnabled ? theme.textLight : theme.textMain
                        font.family: theme.font
                        font.pixelSize: 16
                    }
                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: "Bluetooth"
                            color: bluetoothEnabled ? theme.textLight : theme.textMain
                            font.family: theme.font
                            font.pixelSize: 12
                            font.bold: true
                        }
                        Text {
                            visible: modConf.showDevice !== false
                            text: bluetoothEnabled ? "Включён" : "Отключён"
                            color: bluetoothEnabled ? theme.textLight : theme.textDark
                            font.family: theme.font
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            Layout.maximumWidth: 82
                        }
                    }
                }
                MouseArea {
                    id: powerHit
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.runCommand(["bluetoothctl", "power", bluetoothEnabled ? "off" : "on"])
                }
                ThemeToolTip { targetItem: powerHit; visible: powerHit.containsMouse; text: bluetoothEnabled ? "Выключить Bluetooth" : "Включить Bluetooth" }
            }
            Rectangle { width: 1; Layout.fillHeight: true; Layout.margins: 6; color: theme.border }
            Item {
                Layout.preferredWidth: 34
                Layout.fillHeight: true
                Text { anchors.centerIn: parent; text: ""; color: theme.textMain; font.family: theme.font }
                MouseArea {
                    id: devicesHit
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.openCustomMenu("bt", "Bluetooth устройства")
                }
                ThemeToolTip { targetItem: devicesHit; visible: devicesHit.containsMouse; text: "Открыть список Bluetooth устройств" }
            }
        }
    }
}
