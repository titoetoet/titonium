pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Services.Center
import qs.Titonium.Services.Notifications

QtObject {
    property Connections nativeNotifications: Connections {
        target: NotificationService
        function onDescriptorPublished(descriptor: var): void {
            NotificationCoordinator.publish(descriptor);
        }
        function onDescriptorRetired(key: string, reason: string): void {
            NotificationCoordinator.retire(key, reason);
        }
    }

    property Connections jobNotifications: Connections {
        target: CenterJobService
        function onNotificationPublished(notification: var): void {
            NotificationCoordinator.publishInternal(notification);
        }
        function onNotificationRetired(key: string, reason: string): void {
            NotificationCoordinator.retire(key, reason);
        }
    }

    property Connections timerNotifications: Connections {
        target: CenterTimerService
        function onNotificationPublished(notification: var): void {
            NotificationCoordinator.publishInternal(notification);
        }
        function onNotificationRetired(key: string, reason: string): void {
            NotificationCoordinator.retire(key, reason);
        }
    }
}
