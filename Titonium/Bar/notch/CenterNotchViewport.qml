pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.Titonium.Core.Runtime
import qs.Titonium.Theme
import "CenterNotchState.js" as CenterNotchState

FocusScope {
    id: root
    property string requestedPage: "overview"
    property string pendingPage: ""
    property int transitionDuration: 0
    property int transitionOffset: 0
    property string currentPage: "overview"
    function componentFor(pageId: string): Component {
        const normalized = CenterNotchState.normalizePage(pageId);
        if (normalized !== pageId)
            Logger.warn("center-notch", "unknown page " + pageId + "; using overview");
        if (normalized === "overview")
            return overviewComponent;
        if (normalized === "notifications")
            return notificationsComponent;
        return overviewComponent;
    }

    function requestPage(pageId: string): void {
        const nextPage = CenterNotchState.normalizePage(pageId);
        if (stack.busy) {
            root.pendingPage = nextPage;
            return;
        }
        if (nextPage === root.currentPage)
            return;
        const plan = CenterNotchState.transitionPlan(
            root.currentPage, nextPage, Motion.reduced, Motion.normal);
        root.transitionDuration = plan.duration;
        root.transitionOffset = plan.offset;
        stack.replace(root.componentFor(nextPage), { "pageId": nextPage });
        root.currentPage = nextPage;
    }

    onRequestedPageChanged: root.requestPage(root.requestedPage)

    Component {
        id: overviewComponent
        OverviewPage { pageId: "overview" }
    }
    Component {
        id: notificationsComponent
        NotificationsPage { pageId: "notifications" }
    }
    StackView {
        id: stack
        anchors.fill: parent
        initialItem: overviewComponent
        clip: true

        replaceEnter: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: root.transitionDuration
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    property: "y"
                    from: root.transitionOffset
                    to: 0
                    duration: root.transitionDuration
                    easing.type: Easing.OutCubic
                }
            }
        }
        replaceExit: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: root.transitionDuration
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    property: "y"
                    from: 0
                    to: -root.transitionOffset
                    duration: root.transitionDuration
                    easing.type: Easing.OutCubic
                }
            }
        }

        onBusyChanged: {
            if (busy || root.pendingPage.length === 0)
                return;
            const nextPage = root.pendingPage;
            root.pendingPage = "";
            Qt.callLater(() => root.requestPage(nextPage));
        }
    }
}
