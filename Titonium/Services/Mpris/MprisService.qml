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
            desktopEntry: player.desktopEntry || "",
            playbackState: MprisPlaybackState.toString(player.playbackState).toLowerCase(),
            trackTitle: player.trackTitle || "",
            trackArtist: player.trackArtist || "",
            trackArtUrl: player.trackArtUrl || "",
            trackLength: Number(player.length) > 0 ? Number(player.length) : 0,
            trackPosition: Number(player.trackPosition) >= 0 ? Number(player.trackPosition) : 0,
            canTogglePlaying: player.canTogglePlaying === true,
            canGoPrevious: player.canGoPrevious === true,
            canGoNext: player.canGoNext === true,
            changedAt: root.changeTimes[key] || 0
        };
    }

    function selectedNativePlayer(): var {
        if (root.projection === null)
            return null;
        const players = Mpris.players.values || [];
        for (let index = 0; index < players.length; index++) {
            if (root.playerKey(players[index]) === root.projection.identity)
                return players[index];
        }
        return null;
    }

    function selectNextPlayer(): bool {
        const players = root.playerFacts || [];
        if (players.length < 2 || root.projection === null)
            return false;
        let index = players.findIndex(player => player.identity === root.projection.identity);
        index = index < 0 ? 0 : (index + 1) % players.length;
        const next = players[index];
        root.projection = next;
        const liveActivity = MprisRules.activity(next, Date.now());
        if (liveActivity !== null)
            CenterActivityService.upsert(liveActivity);
        else
            CenterActivityService.remove("media:current");
        CenterAttentionService.setIndicator(
            "media", "music_note", I18n.tr("menubar.center.indicator.media"),
            MprisRules.indicatorActive(next));
        return true;
    }

    function togglePlaying(): bool {
        const player = root.selectedNativePlayer();
        if (player === null || player.canTogglePlaying !== true)
            return false;
        player.togglePlaying();
        return true;
    }

    function previous(): bool {
        const player = root.selectedNativePlayer();
        if (player === null || player.canGoPrevious !== true)
            return false;
        player.previous();
        return true;
    }

    function next(): bool {
        const player = root.selectedNativePlayer();
        if (player === null || player.canGoNext !== true)
            return false;
        player.next();
        return true;
    }

    function publishProjection(result: var): void {
        root.projection = result.next;
        if (result.event !== null)
            CenterAttentionService.publish(result.event);
        const liveActivity = MprisRules.activity(result.next, Date.now());
        if (liveActivity !== null)
            CenterActivityService.upsert(liveActivity);
        else
            CenterActivityService.remove("media:current");
        CenterAttentionService.setIndicator(
            "media",
            "music_note",
            I18n.tr("menubar.center.indicator.media"),
            MprisRules.indicatorActive(result.next)
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

    function raiseSource(): bool {
        if (root.projection === null)
            return false;
        const players = Mpris.players.values || [];
        for (let index = 0; index < players.length; index++) {
            const player = players[index];
            if (root.playerKey(player) !== root.projection.identity
                    || player.canRaise !== true)
                continue;
            player.raise();
            return true;
        }
        return false;
    }

    function snapshot(): string {
        return JSON.stringify({
            playerCount: root.playerFacts.length,
            selectedPlayer: root.selectedPlayer,
            playing: root.playing,
            title: root.title
        });
    }

    // App calls this to pin the singleton to the shell lifetime. Initialization
    // remains in Component.onCompleted so any first reference is safe.
    function activate(): void {}

    Component.onCompleted: root.synchronizePlayers()

    property Instantiator playerConnections: Instantiator {
        model: Mpris.players

        delegate: Connections {
            required property var modelData

            target: modelData
            function onTrackTitleChanged(): void { root.markChanged(modelData); }
            function onTrackArtistChanged(): void { root.markChanged(modelData); }
            function onTrackArtUrlChanged(): void { root.markChanged(modelData); }
            function onDesktopEntryChanged(): void { root.markChanged(modelData); }
            function onPlaybackStateChanged(): void { root.markChanged(modelData); }
            function onPositionChanged(): void { root.markChanged(modelData); }
            function onLengthChanged(): void { root.markChanged(modelData); }
        }
    }

    property Connections playersConnections: Connections {
        target: Mpris.players
        function onValuesChanged(): void { root.synchronizePlayers(); }
    }
}
