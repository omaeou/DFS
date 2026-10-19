pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "../../features/shared"

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
        const actions = []
        const sourceActions = notification.actions || []
        for (let i = 0; i < sourceActions.length && i < 12; ++i) {
            actions.push({
                identifier: boundedText(sourceActions[i].identifier, 128),
                text: boundedText(sourceActions[i].text, 256)
            })
        }
        insertHistory(notification.id, notification.appName, notification.summary, notification.body, {
            appIcon: boundedText(notification.appIcon, 512),
            image: boundedText(notification.image, 2048),
            desktopEntry: boundedText(notification.desktopEntry, 256),
            actionsJson: JSON.stringify(actions)
        })
    }

    function boundedText(value, limit) {
        return String(value || "").slice(0, limit)
    }

    function recordMirroredNotification(appName, summary, body, sourceId) {
        const id = Number(sourceId) > 0 ? -Number(sourceId) : -Date.now()
        insertHistory(id, appName, summary, body, {
            appIcon: "",
            image: "",
            desktopEntry: "",
            actionsJson: "[]"
        })
    }

    function insertHistory(notificationId, appName, summary, body, details) {
        for (let i = historyModel.count - 1; i >= 0; --i) {
            if (historyModel.get(i).notificationId === notificationId) historyModel.remove(i)
        }
        historyModel.insert(0, {
            notificationId: notificationId,
            appName: boundedText(appName || "Уведомление", 256),
            summary: boundedText(summary, 2048),
            bodyText: boundedText(body, 8192),
            appIcon: boundedText(details && details.appIcon, 512),
            image: boundedText(details && details.image, 2048),
            desktopEntry: boundedText(details && details.desktopEntry, 256),
            actionsJson: boundedText(details && details.actionsJson || "[]", 8192)
        })
        while (historyModel.count > 40) historyModel.remove(historyModel.count - 1)
    }

    function findTrackedNotification(notificationId) {
        const tracked = notificationServer.trackedNotifications.values
        for (let i = 0; i < tracked.length; ++i) {
            if (Number(tracked[i].id) === Number(notificationId))
                return tracked[i]
        }
        return null
    }

    function resolveApplication(desktopEntry, appName) {
        let application = null
        try {
            if (desktopEntry)
                application = DesktopEntries.byId(desktopEntry)
            if (!application && appName)
                application = DesktopEntries.byId(appName)
            if (!application && appName)
                application = DesktopEntries.heuristicLookup(appName)
        } catch (error) {
            console.warn("[DFS:notifications] Could not resolve desktop entry:", String(error))
        }
        return application || null
    }

    function canOpenApplication(notificationId, desktopEntry, appName) {
        const notification = findTrackedNotification(notificationId)
        if (notification && notification.actions.some(action => action.identifier === "default"))
            return true
        return resolveApplication(desktopEntry, appName) !== null
    }

    function openApplication(desktopEntry, appName) {
        const application = resolveApplication(desktopEntry, appName)
        if (!application)
            return false
        application.execute()
        return true
    }

    function activateNotification(notificationId, desktopEntry, appName) {
        const notification = findTrackedNotification(notificationId)
        if (notification) {
            const defaultAction = notification.actions.find(action => action.identifier === "default")
            if (defaultAction) {
                defaultAction.invoke()
                GlobalState.isNotificationsOpen = false
                return true
            }
        }
        const opened = openApplication(desktopEntry, appName)
        if (opened)
            GlobalState.isNotificationsOpen = false
        return opened
    }

    function invokeAction(notificationId, actionId) {
        const notification = findTrackedNotification(notificationId)
        if (!notification)
            return false
        const action = notification.actions.find(candidate => candidate.identifier === actionId)
        if (!action)
            return false
        action.invoke()
        return true
    }

    function displayBody(body) {
        return String(body || "")
            .replace(/\r\n?/g, "\n")
            .replace(/\*([^*\n]+)\*/g, "$1")
            .replace(/\s+\|\s+/g, "\n")
            .replace(/[ \t]+\n/g, "\n")
            .replace(/\n{3,}/g, "\n\n")
            .trim()
    }

    function dismissNotification(notificationId) {
        const notification = findTrackedNotification(notificationId)
        if (notification)
            notification.dismiss()
        for (let i = historyModel.count - 1; i >= 0; --i) {
            if (historyModel.get(i).notificationId === notificationId) historyModel.remove(i)
        }
    }

    function dismissAll() {
        const values = notificationServer.trackedNotifications.values
        const snapshot = []
        for (let i = 0; i < values.length; ++i)
            snapshot.push(values[i])
        for (let i = 0; i < snapshot.length; ++i)
            snapshot[i].dismiss()
        historyModel.clear()
    }
}
