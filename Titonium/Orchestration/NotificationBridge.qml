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
        function onDescriptorRetired(key: string, reason: var): void {
            NotificationCoordinator.retire(key);
        }
    }

    property Connections jobNotifications: Connections {
        target: CenterJobService
        function onNotificationPublished(notification: var): void {
            NotificationCoordinator.publishInternal(notification);
        }
    }

    property Connections timerNotifications: Connections {
        target: CenterTimerService
        function onNotificationPublished(notification: var): void {
            NotificationCoordinator.publishInternal(notification);
        }
    }
}
