pragma ComponentBehavior: Bound
import QtQuick

// Artwork: local Mascot/mascots/dog, Puppy 1.0.0, Titonium Team.
Item {
    id: root
    objectName: "pixelStageDog"
    implicitWidth: 88
    implicitHeight: 36
    property bool hovered: dogHover.hovered
    // Compatibility with the standalone Mascot showcase controls.
    property alias peekHovered: root.hovered
    property bool autoWalkLoop: true
    property bool paused: false
    property url assetBase: Qt.resolvedUrl("assets/")
    property real cycleTime: 0
    property real actionTime: 0
    property string currentAction: "idle"
    property int lastReaction: -1
    property bool reactionPending: false
    property string pendingAction: ""
    readonly property real unit: height / 36
    readonly property real walkProgress: paused ? 1 : cycleTime < 2200 ? cycleTime / 2200
        : cycleTime < 8600 ? 1 : cycleTime < 10800 ? 1 - (cycleTime - 8600) / 2200 : 0
    readonly property bool walkingBack: !paused && cycleTime >= 8400
    readonly property bool walking: !paused && (cycleTime < 2200 || (cycleTime >= 8600 && cycleTime < 10800))
    readonly property real turnScale: paused || cycleTime < 8200 || cycleTime > 8600
        ? 1 : Math.max(0.12, Math.abs(cycleTime - 8400) / 200)
    readonly property string walkState: paused || (cycleTime >= 2200 && cycleTime < 8200)
        ? "front" : cycleTime < 2200 ? "walking_out" : cycleTime < 10800 ? "walking_in" : "back"
    readonly property real curtainRatio: currentAction === "curtain"
        ? (1 - Math.cos(actionTime / 2100 * Math.PI * 2)) / 2 : 0
    readonly property real stride: walking ? Math.sin(cycleTime / 90) : 0
    readonly property real gesture: currentAction === "idle" ? 0 : Math.sin(actionTime / 170)
    readonly property real effectOpacity: currentAction === "idle" ? 0
        : Math.min(1, actionTime / 220, (2100 - actionTime) / 300)
    clip: false

    function startReaction(): void {
        const choices = ["wave", "feed", "pet"];
        if (pendingAction === "") {
            lastReaction = lastReaction < 0 ? Math.floor(Math.random() * 3)
                : (lastReaction + 1 + Math.floor(Math.random() * 2)) % 3;
            currentAction = choices[lastReaction];
        } else {
            currentAction = pendingAction;
            if (choices.indexOf(pendingAction) >= 0) lastReaction = choices.indexOf(pendingAction);
        }
        actionTime = 0;
        reactionPending = false;
        pendingAction = "";
    }
    function queueReaction(action: string): void {
        if (!paused && currentAction === "idle") {
            pendingAction = action;
            reactionPending = true;
            if (cycleTime >= 2200 && cycleTime < 8200) startReaction();
        }
    }
    function doWave(): void { queueReaction("wave"); }
    function doFeed(): void { queueReaction("feed"); }
    function doPet(): void { queueReaction("pet"); }
    function doBark(): void { queueReaction("bark"); }
    function toggleCurtains(): void { queueReaction("curtain"); }
    function toggleWalkLoop(): void { autoWalkLoop = !autoWalkLoop; }
    onAutoWalkLoopChanged: { if (!autoWalkLoop) cycleTime = 2200; }
    onHoveredChanged: { if (hovered) queueReaction(""); }
    onPausedChanged: {
        if (paused) {
            currentAction = "idle";
            reactionPending = false;
            pendingAction = "";
            actionTime = 0;
            cycleTime = 2200;
        }
    }
    FrameAnimation {
        running: root.visible && !root.paused && (root.autoWalkLoop || root.currentAction !== "idle" || root.reactionPending)
        onTriggered: {
            const elapsed = Math.min(frameTime * 1000, 50);
            if (root.currentAction !== "idle") {
                root.actionTime += elapsed;
                if (root.actionTime >= 2100) {
                    root.currentAction = "idle";
                    root.actionTime = 0;
                    root.cycleTime = 2200;
                }
            } else {
                if (root.autoWalkLoop) root.cycleTime = (root.cycleTime + elapsed) % 12000;
                if (root.reactionPending && root.cycleTime >= 2200 && root.cycleTime < 8200)
                    root.startReaction();
            }
        }
    }

    // A soft stage recess, sized inside the host's existing pill.
    Rectangle {
        x: 3 * root.unit; y: 2 * root.unit
        width: Math.max(0, root.width - 6 * root.unit); height: root.height - 3 * root.unit
        radius: height / 2
        color: "#141019"
    }
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height - 4 * root.unit
        width: 26 * root.unit * (0.55 + root.walkProgress * 0.45)
        height: 3 * root.unit; radius: height / 2
        color: "#08070d"; opacity: 0.65
    }
    Item {
        id: puppy
        width: 30 * root.unit; height: 32 * root.unit
        x: (root.width - width) / 2
        y: root.height - height + root.walkProgress * root.unit
            - Math.abs(root.stride) * 0.7 * root.unit
            + (root.currentAction === "feed" ? root.gesture * 0.6 * root.unit : 0)
            - (root.currentAction === "bark" ? Math.abs(root.gesture) * 1.5 * root.unit : 0)
        scale: 0.48 + root.walkProgress * 0.52
        opacity: Math.min(1, root.walkProgress * 3)
        transformOrigin: Item.Bottom
        transform: Scale { origin.x: puppy.width / 2; xScale: root.turnScale }
        rotation: root.currentAction === "pet" ? root.gesture * 4 : root.stride * 1.2
        Image {
            anchors.fill: parent
            // Exclude the baked-in floor and edge debris; paw overlap is its own layer.
            sourceClipRect: Qt.rect(8, 12, 162, 178)
            source: root.assetBase + (root.walkingBack
                ? (root.walking ? (root.stride > 0 ? "puppy_back_walk1.png" : "puppy_back_walk2.png") : "puppy_back_stand.png")
                : root.walking ? (root.stride > 0 ? "puppy_walk1.png" : "puppy_walk2.png") : "puppy_walk3.png")
            smooth: false
            fillMode: Image.Stretch
        }
    }
    // Two compact velvet wings. Geometry replaces the old oversized curtain bitmaps.
    Repeater {
        model: 2
        delegate: Item {
            id: wing
            required property int index
            width: 13 * root.unit + root.curtainRatio * Math.max(0, root.width / 2 - 16 * root.unit)
            height: root.height - 4 * root.unit
            x: index === 0 ? 3 * root.unit : root.width - width - 3 * root.unit
            y: 2 * root.unit
            scale: 1
            transform: Scale { origin.x: wing.width / 2; xScale: wing.index === 0 ? 1 : -1 }
            Rectangle { width: parent.width; height: parent.height; radius: 5 * root.unit; color: "#6d293a" }
            Rectangle { x: 3 * root.unit; y: root.unit; width: 3 * root.unit; height: parent.height - 2 * root.unit; radius: root.unit; color: "#a44655" }
            Rectangle { x: 8 * root.unit; y: root.unit; width: 2 * root.unit; height: parent.height - 2 * root.unit; radius: root.unit; color: "#843347" }
            Rectangle { x: root.unit; y: parent.height * 0.64; width: parent.width - 2 * root.unit; height: 2 * root.unit; color: "#c69a61" }
        }
    }
    // Only the paws cross the lower rim, by at most four logical pixels.
    Repeater {
        model: 2
        delegate: Item {
            id: paw
            required property int index
            visible: !root.walkingBack && root.walkProgress > 0.88
            opacity: Math.max(0, (root.walkProgress - 0.88) / 0.12) * root.turnScale * (1 - root.curtainRatio)
            width: 6 * root.unit; height: 6 * root.unit
            x: root.width / 2 + (index === 0 ? -10 : 4) * root.unit
            y: root.height - 2 * root.unit
            transformOrigin: Item.Top
            rotation: index === 0 && root.currentAction === "wave" ? -22 + root.gesture * 22 : 0
            Rectangle { anchors.fill: parent; color: "#7f4b27"; radius: root.unit }
            Rectangle { x: root.unit; width: parent.width - 2 * root.unit; height: parent.height - root.unit; color: "#ffc56b" }
            Rectangle { x: root.unit; y: 3 * root.unit; width: parent.width - 2 * root.unit; height: 2 * root.unit; color: "#fff1d6" }
        }
    }
    Image {
        width: 10 * root.unit; height: 7 * root.unit
        x: root.width / 2 + 9 * root.unit
        y: root.height * 0.6 + root.gesture * root.unit
        source: root.assetBase + "pixel_bone.png"
        visible: root.currentAction === "feed"; opacity: root.effectOpacity
        smooth: false; fillMode: Image.PreserveAspectFit
    }
    Image {
        width: 7 * root.unit; height: 7 * root.unit
        x: root.width / 2 + 14 * root.unit
        y: 5 * root.unit - root.actionTime / 2100 * 3 * root.unit
        source: root.assetBase + "pixel_heart.png"
        visible: root.currentAction === "pet"; opacity: root.effectOpacity
        smooth: false; fillMode: Image.PreserveAspectFit
    }
    Item {
        x: root.width / 2 + 16 * root.unit; y: root.height * 0.4
        visible: root.currentAction === "bark"; opacity: root.effectOpacity
        Rectangle { width: 4 * root.unit; height: root.unit; rotation: -20; color: "#edc884" }
        Rectangle { y: 4 * root.unit; width: 3 * root.unit; height: root.unit; rotation: 20; color: "#edc884" }
    }
    Repeater {
        model: 6
        delegate: Item {
            id: star
            required property int index
            readonly property real phase: root.paused ? 0 : Math.sin(root.cycleTime / 650 + index * 1.7)
            width: (index % 2 === 0 ? 4 : 3) * root.unit; height: width
            x: ([0.2, 0.78, 0.08, 0.91, 0.28, 0.7][index]) * root.width - width / 2
            y: ([3, 6, 18, 25, 36, 37][index]) * root.unit
            opacity: 0.35 + (phase + 1) * 0.22
            Rectangle { x: star.width / 2 - root.unit / 2; width: root.unit; height: star.height; color: star.index % 2 ? "#8bcac1" : "#edc884" }
            Rectangle { y: star.height / 2 - root.unit / 2; width: star.width; height: root.unit; color: star.index % 2 ? "#8bcac1" : "#edc884" }
        }
    }
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width, parent.height * 1.1)
        height: parent.height
        HoverHandler { id: dogHover; blocking: false }
    }
}
