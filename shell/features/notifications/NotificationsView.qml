import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
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
    implicitWidth: 392
    implicitHeight: 520
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: GlobalState.effectiveTheme.radius
        color: GlobalState.effectiveTheme.bg
        border.width: 1
        border.color: GlobalState.effectiveTheme.frame
        antialiasing: true

        gradient: Gradient {
            GradientStop { position: 0; color: GlobalState.effectiveTheme.surfaceTop }
            GradientStop { position: 0.5; color: GlobalState.effectiveTheme.bgAlt }
            GradientStop { position: 1; color: GlobalState.effectiveTheme.surfaceBottom }
        }

        Rectangle {
            x: 18; y: 0; width: 46; height: 2; radius: 1
            color: GlobalState.effectiveTheme.accentGlow
            opacity: GlobalState.config.appearance.glow ? 0.9 : 0.45
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 13
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 9

                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 6
                    color: GlobalState.effectiveTheme.bg
                    border.width: 1
                    border.color: GlobalState.effectiveTheme.frame
                    Text {
                        anchors.centerIn: parent
                        text: "ᛉ"
                        color: GlobalState.effectiveTheme.rune
                        font.family: GlobalState.effectiveTheme.font
                        font.pixelSize: 18
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: "ВЕСТИ"
                        color: GlobalState.effectiveTheme.textLight
                        font.family: GlobalState.effectiveTheme.font
                        font.pixelSize: 13
                        font.bold: true
                        font.letterSpacing: 1
                    }
                    Text {
                        text: NotificationService.history.count + " · в истории"
                        color: GlobalState.effectiveTheme.textDark
                        font.family: GlobalState.effectiveTheme.font
                        font.pixelSize: 9
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 31
                    Layout.preferredHeight: 29
                    visible: NotificationService.history.count > 0
                    radius: 5
                    color: clearMouse.containsMouse ? GlobalState.effectiveTheme.bgHover : GlobalState.effectiveTheme.bgAlt
                    border.width: 1
                    border.color: clearMouse.containsMouse ? GlobalState.effectiveTheme.accentActive : GlobalState.effectiveTheme.frame
                    Text {
                        anchors.centerIn: parent
                        text: "⌫"
                        color: GlobalState.effectiveTheme.rune
                        font.pixelSize: 15
                    }
                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotificationService.dismissAll()
                    }
                    ThemeToolTip { targetItem: clearMouse; visible: clearMouse.containsMouse; text: "Очистить историю уведомлений" }
                }

                Rectangle {
                    Layout.preferredWidth: 31
                    Layout.preferredHeight: 29
                    radius: 5
                    color: closeMouse.containsMouse ? GlobalState.effectiveTheme.bgHover : GlobalState.effectiveTheme.bgAlt
                    border.width: 1
                    border.color: closeMouse.containsMouse ? GlobalState.effectiveTheme.accentActive : GlobalState.effectiveTheme.frame
                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: GlobalState.effectiveTheme.textMain
                        font.pixelSize: 19
                    }
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: GlobalState.isNotificationsOpen = false
                    }
                    ThemeToolTip { targetItem: closeMouse; visible: closeMouse.containsMouse; text: "Закрыть уведомления" }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: GlobalState.effectiveTheme.frame
                opacity: 0.8
            }

            ListView {
                id: notificationList
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: NotificationService.history

                delegate: Rectangle {
                    id: notificationCard
                    required property int notificationId
                    required property string appName
                    required property string summary
                    required property string bodyText
                    required property string appIcon
                    required property string image
                    required property string desktopEntry
                    required property string actionsJson

                    readonly property var actionItems: {
                        try {
                            return JSON.parse(actionsJson || "[]").filter(action => action.identifier !== "default")
                        } catch (error) {
                            return []
                        }
                    }
                    readonly property string resolvedIcon: {
                        if (!appIcon)
                            return ""
                        if (appIcon.startsWith("file:///"))
                            return appIcon
                        if (appIcon.startsWith("/"))
                            return "file://" + appIcon
                        if (appIcon.indexOf("/") >= 0 || appIcon.indexOf(":") >= 0)
                            return ""
                        return Quickshell.iconPath(appIcon, true)
                    }
                    readonly property string safeImageSource: {
                        if (image.startsWith("file:///"))
                            return image
                        if (image.startsWith("/"))
                            return "file://" + image
                        return ""
                    }

                    width: ListView.view.width
                    height: cardContent.implicitHeight + 18
                    radius: 7
                    color: GlobalState.effectiveTheme.bgAlt
                    border.width: 1
                    border.color: cardHover.hovered ? GlobalState.effectiveTheme.accentActive : GlobalState.effectiveTheme.border
                    antialiasing: true
                    Behavior on border.color { ColorAnimation { duration: GlobalState.animationDuration(110) } }

                    Rectangle {
                        x: 0; y: 8; width: 2; height: parent.height - 16; radius: 1
                        color: GlobalState.effectiveTheme.rune
                        opacity: 0.62
                    }

                    ColumnLayout {
                        id: cardContent
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                                radius: 6
                                color: GlobalState.effectiveTheme.surfaceTop
                                border.width: 1
                                border.color: GlobalState.effectiveTheme.frame

                                IconImage {
                                    id: appIconImage
                                    anchors.centerIn: parent
                                    width: 22
                                    height: 22
                                    source: notificationCard.resolvedIcon
                                    visible: status === Image.Ready
                                    asynchronous: true
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: !notificationCard.resolvedIcon || appIconImage.status !== Image.Ready
                                    text: notificationCard.appName.length > 0 ? notificationCard.appName.substring(0, 1).toUpperCase() : "✦"
                                    textFormat: Text.PlainText
                                    color: GlobalState.effectiveTheme.rune
                                    font.family: GlobalState.effectiveTheme.font
                                    font.pixelSize: 15
                                    font.bold: true
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 2
                                Text {
                                    Layout.fillWidth: true
                                    text: notificationCard.appName
                                    textFormat: Text.PlainText
                                    color: GlobalState.effectiveTheme.rune
                                    font.family: GlobalState.effectiveTheme.font
                                    font.pixelSize: 9
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: notificationCard.summary
                                    textFormat: Text.PlainText
                                    color: GlobalState.effectiveTheme.textLight
                                    font.family: GlobalState.effectiveTheme.font
                                    font.pixelSize: 12
                                    font.bold: true
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 25
                                Layout.preferredHeight: 25
                                radius: 5
                                color: dismissMouse.containsMouse ? GlobalState.effectiveTheme.bgHover : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "×"
                                    color: GlobalState.effectiveTheme.textDark
                                    font.pixelSize: 17
                                }
                                MouseArea {
                                    id: dismissMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: NotificationService.dismissNotification(notificationCard.notificationId)
                                }
                                ThemeToolTip { targetItem: dismissMouse; visible: dismissMouse.containsMouse; text: "Убрать уведомление" }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: notificationCard.safeImageSource !== ""

                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                text: NotificationService.displayBody(notificationCard.bodyText)
                                color: GlobalState.effectiveTheme.textMain
                                font.family: GlobalState.effectiveTheme.font
                                font.pixelSize: 10
                                wrapMode: Text.Wrap
                                maximumLineCount: 4
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                            }
                            Image {
                                Layout.preferredWidth: 70
                                Layout.preferredHeight: 58
                                source: notificationCard.safeImageSource
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: status === Image.Ready
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: notificationCard.bodyText !== "" && notificationCard.safeImageSource === ""
                            text: NotificationService.displayBody(notificationCard.bodyText)
                            color: GlobalState.effectiveTheme.textMain
                            font.family: GlobalState.effectiveTheme.font
                            font.pixelSize: 10
                            wrapMode: Text.Wrap
                            maximumLineCount: 5
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }

                        Flow {
                            id: actionFlow
                            Layout.fillWidth: true
                            Layout.preferredHeight: childrenRect.height
                            spacing: 5

                            Repeater {
                                model: notificationCard.actionItems
                                delegate: Rectangle {
                                    required property var modelData
                                    width: Math.max(66, Math.min(142, actionLabel.implicitWidth + 20))
                                    height: 25
                                    radius: 5
                                    color: actionMouse.containsMouse ? GlobalState.effectiveTheme.borderActive : GlobalState.effectiveTheme.bg
                                    border.width: 1
                                    border.color: actionMouse.containsMouse ? GlobalState.effectiveTheme.accentActive : GlobalState.effectiveTheme.frame
                                    Text {
                                        id: actionLabel
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        text: modelData.text || "Действие"
                                        textFormat: Text.PlainText
                                        color: GlobalState.effectiveTheme.textMain
                                        font.family: GlobalState.effectiveTheme.font
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    MouseArea {
                                        id: actionMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: NotificationService.invokeAction(notificationCard.notificationId, modelData.identifier)
                                    }
                                }
                            }

                            Rectangle {
                                visible: NotificationService.canOpenApplication(
                                    notificationCard.notificationId,
                                    notificationCard.desktopEntry,
                                    notificationCard.appName)
                                width: 77
                                height: 25
                                radius: 5
                                color: openMouse.containsMouse ? GlobalState.effectiveTheme.borderActive : GlobalState.effectiveTheme.bg
                                border.width: 1
                                border.color: openMouse.containsMouse ? GlobalState.effectiveTheme.accentActive : GlobalState.effectiveTheme.frame
                                Text {
                                    anchors.centerIn: parent
                                    text: "Открыть  ↗"
                                    color: GlobalState.effectiveTheme.accentGlow
                                    font.family: GlobalState.effectiveTheme.font
                                    font.pixelSize: 9
                                }
                                MouseArea {
                                    id: openMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: NotificationService.activateNotification(
                                        notificationCard.notificationId,
                                        notificationCard.desktopEntry,
                                        notificationCard.appName)
                                }
                                ThemeToolTip { targetItem: openMouse; visible: openMouse.containsMouse; text: "Открыть " + notificationCard.appName }
                            }
                        }
                    }

                    HoverHandler { id: cardHover }
                }

                Text {
                    anchors.centerIn: parent
                    visible: NotificationService.history.count === 0
                    text: "Пока тихо\n\nЗдесь появятся уведомления приложений"
                    color: GlobalState.effectiveTheme.textDark
                    font.family: GlobalState.effectiveTheme.font
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.4
                }
            }
        }
    }
}
