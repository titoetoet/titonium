pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Services.Mpris

QtObject {
    id: root
    readonly property var player: MprisService.selectedPlayer
    readonly property string contextId: "media:current"
    readonly property var actionIds: !root.player ? Object.freeze([]) : Object.freeze([
        "media.previous", "media.toggle", "media.next", "media.raise"
    ])
    readonly property var contexts: !root.player ? Object.freeze([]) : Object.freeze([Object.freeze({
        id: root.contextId, source: "media", kind: "playback",
        title: root.player.trackTitle || "Unknown media",
        subtitle: root.player.trackArtist || "", icon: "music_note", tone: "normal",
        attention: "ambient",
        progress: root.player.trackLength > 0
            ? Math.max(0, Math.min(1, root.player.trackPosition / root.player.trackLength)) : null,
        occurredAt: root.player.changedAt || 0, expiresAt: 0,
        details: Object.freeze({
            identity: root.player.identity || "", trackArtUrl: root.player.trackArtUrl || "",
            trackLength: root.player.trackLength || 0, trackPosition: root.player.trackPosition || 0,
            playing: MprisService.playing,
            playback: MprisService.playbackDetails,
            playbackState: root.player.playbackState || "stopped"
        }), actionIds: root.actionIds
    })])
    readonly property var indicators: Object.freeze([Object.freeze({
        id: "media", icon: "music_note", accessibleName: "Media playing",
        tone: "normal", active: MprisService.playing
    })])
    readonly property var actions: !root.player ? Object.freeze([]) : Object.freeze([
        root.capability("media.previous", "secondary", "Previous", "skip_previous", root.player.canGoPrevious),
        root.capability("media.toggle", "primary", MprisService.playing ? "Pause" : "Play",
            MprisService.playing ? "pause" : "play_arrow", root.player.canTogglePlaying),
        root.capability("media.next", "secondary", "Next", "skip_next", root.player.canGoNext),
        root.capability("media.raise", "secondary", "Open source", "open_in_new", MprisService.playbackDetails.canRaise === true)
    ])

    function capability(id: string, role: string, label: string, icon: string, enabled: bool): var {
        return Object.freeze({ id: id, contextId: root.contextId, role: role,
            label: label, icon: icon, enabled: enabled });
    }
    function dispatch(actionId: string, contextId: string, idempotencyKey: string): var {
        if (contextId !== root.contextId || !root.player)
            return root.result(false, "stale", "missing-context");
        let completed = false;
        if (actionId === "media.previous") completed = MprisService.previous();
        else if (actionId === "media.toggle") completed = MprisService.togglePlaying();
        else if (actionId === "media.next") completed = MprisService.next();
        else if (actionId === "media.raise") completed = MprisService.raiseSource();
        else return root.result(false, "stale", "unknown-action");
        return root.result(completed, completed ? "completed" : "unavailable", "");
    }
    function result(accepted: bool, status: string, reason: string): var {
        return Object.freeze({ accepted: accepted, status: status, reason: reason,
            closePolicy: "keep" });
    }
}
