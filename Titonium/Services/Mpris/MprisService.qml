pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Center
import "MprisRules.js" as MprisRules

QtObject {
    id: root

    property var projection: null
    property var changeTimes: ({})
    property var playerSignatures: ({})

    readonly property var playerFacts: Mpris.players.values.map(player => root.factForPlayer(player))
    readonly property var selectedPlayer: root.projection
    readonly property bool playing: root.selectedPlayer !== null
        && root.selectedPlayer.playbackState === "playing"
    readonly property string title: root.selectedPlayer
        ? (root.selectedPlayer.title || I18n.tr("menubar.center.media_unknown")) : ""

    function playerKey(player: var): string {
        return String(player?.dbusName || player?.identity || "").trim();
    }

    function factForPlayer(player: var): var {
        const key = root.playerKey(player);
        return {
            identity: key,
            playbackState: MprisPlaybackState.toString(player.playbackState).toLowerCase(),
            trackTitle: player.trackTitle || "",
            trackArtist: player.trackArtist || "",
            changedAt: root.changeTimes[key] || 0
        };
    }

    function publishProjection(result: var): void {
        root.projection = result.next;
        if (result.event !== null)
            CenterAttentionService.publish(result.event);
        CenterAttentionService.setIndicator(
            "media",
            "music_note",
            I18n.tr("menubar.center.indicator.media"),
            root.playing
        );
    }

    function recompute(establishBaseline: bool): void {
        const selected = MprisRules.select(root.playerFacts);
        const previous = establishBaseline ? null : root.projection;
        root.publishProjection(MprisRules.transition(previous, selected, Date.now()));
    }

    function markChanged(player: var): void {
        const key = root.playerKey(player);
        if (!key)
            return;
        const fact = root.factForPlayer(player);
        const nextSignature = MprisRules.signature(fact);
        if (root.playerSignatures[key] === nextSignature)
            return;

        const signatures = Object.assign({}, root.playerSignatures);
        const times = Object.assign({}, root.changeTimes);
        signatures[key] = nextSignature;
        times[key] = Date.now();
        root.playerSignatures = signatures;
        root.changeTimes = times;
        root.recompute(false);
    }

    function synchronizePlayers(): void {
        const players = Mpris.players.values;
        const signatures = {};
        const times = {};
        let selectedStillPresent = root.projection === null;

        players.forEach(player => {
            const key = root.playerKey(player);
            if (!key)
                return;
            const fact = root.factForPlayer(player);
            signatures[key] = MprisRules.signature(fact);
            times[key] = root.changeTimes[key] || 0;
            if (root.projection !== null && root.projection.identity === key)
                selectedStillPresent = true;
        });

        root.playerSignatures = signatures;
        root.changeTimes = times;
        root.recompute(!selectedStillPresent);
    }

    function snapshot(): string {
        return JSON.stringify({
            playerCount: root.playerFacts.length,
            selectedPlayer: root.selectedPlayer,
            playing: root.playing,
            title: root.title
        });
    }

    Component.onCompleted: root.synchronizePlayers()

    property Instantiator playerConnections: Instantiator {
        model: Mpris.players

        delegate: Connections {
            required property var modelData

            target: modelData
            function onTrackTitleChanged(): void { root.markChanged(modelData); }
            function onTrackArtistChanged(): void { root.markChanged(modelData); }
            function onPlaybackStateChanged(): void { root.markChanged(modelData); }
        }
    }

    property Connections playersConnections: Connections {
        target: Mpris.players
        function onValuesChanged(): void { root.synchronizePlayers(); }
    }
}
