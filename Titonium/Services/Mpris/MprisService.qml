pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Center
import "MprisRules.js" as MprisRules
import "MprisControls.js" as Controls

QtObject {
    id: root

    property var projection: null
    property var changeTimes: ({})
    property var playerSignatures: ({})
    property bool detailsActive: false
    property int positionRevision: 0
    property var queue: ({})
    property bool queueRestartPending: false
    readonly property string selectedIdentity: root.projection?.identity || ""
    readonly property var playbackDetails: root.readPlaybackDetails()

    function readPlaybackDetails(): var {
        const revision = root.positionRevision;
        const player = root.selectedNativePlayer();
        if (!player) return Object.freeze({});
        const trackId = Controls.trackId(player.metadata?.["mpris:trackid"]);
        const queueMatches = root.queue.identity === root.selectedIdentity && root.queue.trackId === trackId;
        return Object.freeze({ identity: root.selectedIdentity, trackToken: player.uniqueId,
            source: Controls.sourceDetails(player.identity, player.metadata?.["xesam:url"]),
            canRaise: player.canRaise === true,
            trackId: trackId, length: player.lengthSupported ? Math.max(0, player.length) : 0,
            position: player.positionSupported ? Math.max(0, player.position) : 0,
            canSeek: player.canSeek === true && player.positionSupported === true,
            nextTrack: queueMatches ? root.queue.nextTrack : null,
            queueStatus: queueMatches ? root.queue.status : "unavailable" });
    }

    function seekTo(identity: string, token: int, fraction: real): bool {
        const player = root.selectedNativePlayer();
        if (!player) return false;
        const position = Controls.seekPosition(identity, token, {
            identity: root.playerKey(player), trackToken: player.uniqueId,
            canSeek: player.canSeek === true && player.positionSupported === true,
            length: player.lengthSupported ? player.length : 0
        }, fraction);
        if (position === null) return false;
        player.position = position;
        root.positionRevision++;
        return true;
    }

    function startQueueReader(): void {
        root.queueRestartPending = false;
        if (!root.detailsActive || !root.selectedIdentity) return;
        queueReader.command = ["python3", Qt.resolvedUrl("track_list.py").toString().replace("file://", ""), root.selectedIdentity];
        queueReader.running = true;
    }
    function updateQueueReader(): void {
        root.queue = ({});
        root.queueRestartPending = root.detailsActive && !!root.selectedIdentity;
        if (queueReader.running) queueReader.running = false;
        else root.startQueueReader();
    }
    onDetailsActiveChanged: root.updateQueueReader()
    onSelectedIdentityChanged: root.updateQueueReader()
    property Timer positionClock: Timer {
        interval: 1000; repeat: true
        running: root.detailsActive && root.playing
        onTriggered: root.positionRevision++
    }
    property Process queueReader: Process {
        id: queueReader
        stdout: SplitParser {
            onRead: line => {
                try {
                    const value = JSON.parse(line);
                    if (root.detailsActive && !root.queueRestartPending
                            && value.identity === root.selectedIdentity)
                        root.queue = value;
                } catch (_) { root.queue = ({}); }
            }
        }
        onExited: {
            root.queue = ({});
            if (root.queueRestartPending) root.startQueueReader();
        }
    }

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
            trackPosition: player.positionSupported && Number(player.position) >= 0 ? Number(player.position) : 0,
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

    function adjustVolume(identity: string, delta: real): bool {
        if (!identity || root.projection?.identity !== identity || !Number.isFinite(delta))
            return false;
        const player = root.selectedNativePlayer();
        if (!player || player.volumeSupported !== true || !Number.isFinite(player.volume))
            return false;
        player.volume = Math.max(0, Math.min(1, player.volume + delta));
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
            function onCanTogglePlayingChanged(): void { root.markChanged(modelData); }
            function onCanGoPreviousChanged(): void { root.markChanged(modelData); }
            function onCanGoNextChanged(): void { root.markChanged(modelData); }
        }
    }

    property Connections playersConnections: Connections {
        target: Mpris.players
        function onValuesChanged(): void { root.synchronizePlayers(); }
    }
}
