pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: service
    property alias history: historyModel
    readonly property var trackedNotifications: notificationServer.trackedNotifications

    ListModel { id: historyModel }

    NotificationServer {
        id: notificationServer
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        keepOnReload: true
        onNotification: notification => service.recordNotification(notification)
    }

    IpcHandler {
        target: "notifications"
        function receive(appName: string, summary: string, body: string, sourceId: int): void {
            service.recordMirroredNotification(appName, summary, body, sourceId)
        }
    }

    function recordNotification(notification) {
        notification.tracked = true
        insertHistory(notification.id, notification.appName, notification.summary, notification.body)
    }

    function recordMirroredNotification(appName, summary, body, sourceId) {
        const id = Number(sourceId) > 0 ? -Number(sourceId) : -Date.now()
        insertHistory(id, appName, summary, body)
    }

    function insertHistory(notificationId, appName, summary, body) {
        for (let i = historyModel.count - 1; i >= 0; --i) {
            if (historyModel.get(i).notificationId === notificationId) historyModel.remove(i)
        }
        historyModel.insert(0, {
            notificationId: notificationId,
            appName: appName || "Уведомление",
            summary: summary || "",
            bodyText: body || ""
        })
        while (historyModel.count > 40) historyModel.remove(historyModel.count - 1)
    }

    function dismissNotification(notificationId) {
        const tracked = notificationServer.trackedNotifications.values
        for (let i = 0; i < tracked.length; ++i) {
            if (tracked[i].id === notificationId) {
                tracked[i].dismiss()
                break
            }
        }
        for (let i = historyModel.count - 1; i >= 0; --i) {
            if (historyModel.get(i).notificationId === notificationId) historyModel.remove(i)
        }
    }
}
