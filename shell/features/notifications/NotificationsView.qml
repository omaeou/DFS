import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../shared"
import "../../core/services"

PanelWindow {
    id: root
    visible: GlobalState.isNotificationsOpen
    anchors.top: true
    anchors.right: true
    exclusionMode: ExclusionMode.Normal
    margins.top: GlobalState.popupTopMargin
    margins.right: GlobalState.config.geometry.marginRight
    implicitWidth: 340
    implicitHeight: 430
    color: "transparent"
    Rectangle {
        anchors.fill: parent; radius: GlobalState.effectiveTheme.radius
        color: GlobalState.effectiveTheme.bg; border.color: GlobalState.effectiveTheme.frame
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 14; spacing: 10
            RowLayout {
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: "ВЕСТИ · " + NotificationService.history.count; color: GlobalState.effectiveTheme.rune; font.pixelSize: 11; font.letterSpacing: 1 }
                Text {
                    text: "×"; color: GlobalState.effectiveTheme.textMain; font.pixelSize: 20
                    MouseArea { id: closeHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: GlobalState.isNotificationsOpen = false }
                    ThemeToolTip { targetItem: closeHit; visible: closeHit.containsMouse; text: "Закрыть список уведомлений" }
                }
            }
            ListView {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 7; clip: true
                model: NotificationService.history
                delegate: Rectangle {
                    required property int notificationId
                    required property string appName
                    required property string summary
                    required property string bodyText
                    width: ListView.view.width; height: Math.min(105, body.implicitHeight + 45); radius: 7
                    color: GlobalState.effectiveTheme.bgAlt; border.color: GlobalState.effectiveTheme.border
                    Column {
                        anchors.fill: parent; anchors.margins: 10; spacing: 4
                        Text { width: parent.width; text: appName; color: GlobalState.effectiveTheme.rune; font.pixelSize: 9 }
                        Text { width: parent.width; text: summary; color: GlobalState.effectiveTheme.textLight; font.pixelSize: 12; font.bold: true; elide: Text.ElideRight }
                        Text { id: body; width: parent.width; text: bodyText; color: GlobalState.effectiveTheme.textMain; font.pixelSize: 10; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight; textFormat: Text.PlainText }
                    }
                    MouseArea {
                        id: notificationHit
                        anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.RightButton
                        onClicked: NotificationService.dismissNotification(notificationId)
                    }
                    ThemeToolTip { targetItem: notificationHit; visible: notificationHit.containsMouse; text: "Нажмите правой кнопкой, чтобы убрать уведомление" }
                }
                Text { anchors.centerIn: parent; visible: NotificationService.history.count === 0; text: "Пока тихо"; color: GlobalState.effectiveTheme.textDark; font.pixelSize: 11 }
            }
        }
    }
}
