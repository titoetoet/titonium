#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.resolve(__dirname, "..");
const library = path.join(root, "Titonium", "Core", "Surfaces", "SurfaceIdentity.js");
assert.equal(fs.existsSync(library), true, "SurfaceIdentity.js must exist");
const source = fs.readFileSync(library, "utf8").replace(/^\.pragma library\s*\n/, "");
const identity = vm.createContext({ String });
vm.runInContext(source, identity, { filename: library });

const screenA = { name: "DP-1" };
const descriptorA = { ownerId: "network:DP-1", source: "ClassicNetworkPopupSurface.qml" };
assert.equal(identity.matches("network:DP-1", descriptorA, screenA,
    "network:DP-1", descriptorA, screenA), true,
"a current Loader failure may release its exact owner/descriptor/screen snapshot");

const descriptorB = { ownerId: "network:DP-1", source: "ClassicNetworkPopupSurface.qml" };
assert.equal(identity.matches("network:DP-1", descriptorB, screenA,
    "network:DP-1", descriptorA, screenA), false,
"a stale Loader error cannot close a same-owner reopen with a new descriptor identity");
assert.equal(identity.matches("network:DP-1", descriptorB, { name: "DP-1" },
    "network:DP-1", descriptorB, screenA), false,
"destruction of an old output object cannot close a replacement output with the same name");

const screenB = { name: "HDMI-A-1" };
assert.equal(identity.matches("audio:HDMI-A-1", descriptorB, screenB,
    "network:DP-1", descriptorA, screenA), false,
"an output-removal callback cannot close a newer owner on another output");
assert.equal(identity.matches("network:DP-1", descriptorB, screenA,
    "network:DP-1", descriptorB, screenA), true,
"the replacement descriptor remains independently releasable after stale cleanup is rejected");

const manager = fs.readFileSync(path.join(root, "Titonium", "Core", "Surfaces",
    "SurfaceManager.qml"), "utf8");
assert.match(manager, /import "SurfaceIdentity\.js" as SurfaceIdentity/);
assert.match(manager, /SurfaceIdentity\.matches\(root\.ownerId, root\.descriptor, root\.screen,/);

console.log("PASS exact surface identity for failure, output removal, and reopen fixtures");
