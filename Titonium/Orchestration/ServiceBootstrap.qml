pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Services.Center
import qs.Titonium.Services.Capture
import qs.Titonium.Services.Clipboard
import qs.Titonium.Services.Mpris

QtObject {
    function activate(): void {
        MprisService.activate();
        ClipboardService.activate();
        CenterActivityService.activate();
        CenterJobService.activate();
        CenterTimerService.activate();
        ScreenRecordService.activate();
    }
}
