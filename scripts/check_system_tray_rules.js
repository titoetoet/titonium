#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const rulesPath = path.join(
    root, "Titonium", "Services", "SystemTray", "SystemTrayRules.js");

assert.equal(fs.existsSync(rulesPath), true,
    "SystemTrayRules must exist before tray metadata can be projected safely");

const source = fs.readFileSync(rulesPath, "utf8")
    .replace(/^\.pragma library\s*\n/, "");
const rules = vm.createContext({});
vm.runInContext(source, rules, { filename: rulesPath });

const descriptors = rules.project([
    {
        id: "TelegramDesktop",
        title: "Telegram Desktop",
        tooltipTitle: "Telegram",
        tooltipDescription: "3 unread messages",
        icon: "telegram",
    },
    {
        id: "org.fcitx.Fcitx5",
        title: "Fcitx 5",
        tooltipTitle: "English (US)",
        tooltipDescription: "Keyboard — English (US)",
        icon: "keyboard-us",
    },
    {
        id: "spotify-client",
        title: "Spotify",
        tooltipTitle: "Spotify",
        tooltipDescription: "",
        icon: "spotify-client",
    },
    {
        id: "chrome_status_icon_1",
        title: "",
        tooltipTitle: "ChatGPT",
        tooltipDescription: "2 active conversations",
        icon: "",
    },
]);

assert.equal(descriptors.length, 4);
assert.deepEqual(JSON.parse(JSON.stringify(descriptors[0])), {
    id: "TelegramDesktop",
    title: "Telegram Desktop",
    tooltipTitle: "Telegram",
    tooltipDescription: "3 unread messages",
    icon: "telegram",
    inputMethod: false,
});

assert.equal(
    rules.contextForApp("org.telegram.desktop", "Telegram", descriptors),
    "3 unread messages",
    "a reverse-DNS app id must match the same application's tray metadata");
assert.equal(
    rules.contextForApp("com.spotify.Client", "Spotify", descriptors),
    "",
    "a tray title that only repeats the app name is not useful context");
assert.equal(
    rules.contextForApp("org.mozilla.firefox", "Firefox", descriptors),
    "",
    "an unrelated tray item must never become the active app subtitle");
assert.equal(
    rules.contextForApp("chatgpt", "ChatGPT", descriptors),
    "2 active conversations",
    "Chromium-style tray items may expose app identity only in tooltipTitle");

assert.equal(
    rules.contextForApp("org.fcitx.Fcitx5", "Fcitx 5", descriptors),
    "",
    "input-method metadata belongs to the dedicated Input icon");

assert.equal(typeof rules.inputMenuIcon, "function",
    "SystemTray rules must provide semantic icons for Input Method entries");
assert.equal(rules.inputMenuIcon("Keyboard - English (US)"), "language");
assert.equal(rules.inputMenuIcon("Lotus"), "local_florist");
assert.equal(rules.inputMenuIcon("Enable Input Method"), "toggle_on");
assert.equal(rules.inputMenuIcon("Disable Input Method"), "toggle_off");
assert.equal(rules.inputMenuIcon("Configure"), "settings");
assert.equal(rules.inputMenuIcon("Add Input Method"), "add_circle");
assert.equal(rules.inputMenuIcon("Remove Input Method"), "remove_circle");
assert.equal(rules.inputMenuIcon("Restart"), "restart_alt");
assert.equal(rules.inputMenuIcon("About Fcitx"), "info");
assert.equal(rules.inputMenuIcon("Help"), "help");
assert.equal(rules.inputMenuIcon("Exit"), "logout");
assert.equal(rules.inputMenuIcon("Charset"), "translate");
assert.equal(rules.inputMenuIcon("Spell Check"), "spellcheck");
assert.equal(rules.inputMenuIcon("Macro"), "code");
assert.equal(rules.inputMenuIcon("Capitalize Macro"), "text_format");
assert.equal(rules.inputMenuIcon("Auto Non-VN Restore"), "restore");
assert.equal(rules.inputMenuIcon("Custom Dictionary"), "dictionary");
assert.deepEqual(JSON.parse(JSON.stringify(rules.inputMenuPresentation({
    text: "✔ Spell Check", checked: false,
}))), {
    label: "Spell Check", icon: "spellcheck", selected: true,
});
assert.deepEqual(JSON.parse(JSON.stringify(rules.inputMenuPresentation({
    text: "✖ Custom Dictionary", checked: false,
}))), {
    label: "Custom Dictionary", icon: "dictionary", selected: false,
});
assert.deepEqual(JSON.parse(JSON.stringify(rules.inputMenuPresentation({
    text: "Lotus", checked: true,
}))), {
    label: "Lotus", icon: "local_florist", selected: true,
});
assert.equal(rules.inputMenuIcon("Input Method"), "keyboard_alt",
    "unknown Fcitx entries receive a Titonium semantic fallback icon");

assert.deepEqual(
    JSON.parse(JSON.stringify(rules.inputMethod(descriptors))),
    JSON.parse(JSON.stringify(descriptors[1])),
    "Fcitx must remain available to InputMethodService after ownership moves");
assert.equal(
    rules.matchingIndex("chatgpt", "ChatGPT", descriptors), 3,
    "the service must resolve the native tray item aligned with a matched descriptor");
assert.equal(
    rules.matchingIndex("org.fcitx.Fcitx5", "Fcitx 5", descriptors), -1,
    "Input Method tray items must never become StartIsland menus");

const vendorCollisions = rules.project([
    {
        id: "com.google.drive",
        title: "Google Drive",
        tooltipTitle: "Google Drive",
        tooltipDescription: "Uploading 3 files",
        icon: "google-drive",
    },
    {
        id: "org.mozilla.vpn",
        title: "Mozilla VPN",
        tooltipTitle: "Mozilla VPN",
        tooltipDescription: "Connected",
        icon: "mozilla-vpn",
    },
    {
        id: "com.microsoft.teams",
        title: "Microsoft Teams",
        tooltipTitle: "Microsoft Teams",
        tooltipDescription: "In a meeting",
        icon: "teams",
    },
]);

assert.equal(rules.contextForApp("com.google.Chrome", "Google Chrome", vendorCollisions), "");
assert.equal(rules.contextForApp("org.mozilla.firefox", "Firefox", vendorCollisions), "");
assert.equal(rules.contextForApp("com.microsoft.Edge", "Microsoft Edge", vendorCollisions), "");

const tooltipOnlyFcitx = rules.project([{
    id: "input-method-1",
    title: "",
    tooltipTitle: "Fcitx 5 · English (US)",
    tooltipDescription: "Keyboard — English (US)",
    icon: "keyboard-us",
}]);
assert.equal(
    rules.inputMethod(tooltipOnlyFcitx)?.id,
    "input-method-1",
    "Fcitx identity supplied through tooltipTitle must remain supported");

const multipleItems = rules.project([
    {
        id: "TelegramDesktop",
        title: "Telegram",
        tooltipTitle: "Telegram",
        tooltipDescription: "",
        icon: "telegram",
    },
    {
        id: "TelegramDesktop",
        title: "Telegram",
        tooltipTitle: "Telegram",
        tooltipDescription: "5 unseen messages",
        icon: "telegram",
    },
]);
assert.equal(
    rules.contextForApp("org.telegram.desktop", "Telegram", multipleItems),
    "5 unseen messages",
    "a redundant matching tray item must not hide a later useful context");

const selectionRecords = rules.projectRecords([
    { id: "", title: "", tooltipTitle: "Broken", tooltipDescription: "", icon: "", hasMenu: true },
    { id: "chatgpt", title: "ChatGPT", tooltipTitle: "ChatGPT", tooltipDescription: "2 active conversations", icon: "", hasMenu: false },
    { id: "chrome_status_icon_1", title: "", tooltipTitle: "ChatGPT", tooltipDescription: "", icon: "", hasMenu: true },
]);

const menuEntries = rules.projectMenuEntries([
    { text: "Running", icon: "", enabled: false, isSeparator: false, hasChildren: false, buttonType: "none", checked: false },
    { text: "Nghiên cứu Event và độ ưu tiên", icon: "", enabled: true, isSeparator: false, hasChildren: false, buttonType: "none", checked: false },
    { text: "", icon: "", enabled: false, isSeparator: true, hasChildren: false, buttonType: "none", checked: false },
    { text: "Recent", icon: "", enabled: false, isSeparator: false, hasChildren: false, buttonType: "none", checked: false },
]);
assert.deepEqual(
    JSON.parse(JSON.stringify(menuEntries)),
    [
        { index: 0, text: "Running", icon: "", enabled: false, separator: false, hasChildren: false, buttonType: "none", checked: false },
        { index: 1, text: "Nghiên cứu Event và độ ưu tiên", icon: "", enabled: true, separator: false, hasChildren: false, buttonType: "none", checked: false },
        { index: 2, text: "", icon: "", enabled: false, separator: true, hasChildren: false, buttonType: "none", checked: false },
        { index: 3, text: "Recent", icon: "", enabled: false, separator: false, hasChildren: false, buttonType: "none", checked: false },
    ]);
const inputChoices = rules.projectMenuEntries([
    { text: "Keyboard - English (US)", icon: "", enabled: true, isSeparator: false, hasChildren: false, buttonType: "radio", checked: false },
    { text: "Lotus", icon: "", enabled: true, isSeparator: false, hasChildren: false, buttonType: "radio", checked: true },
]);
assert.deepEqual(JSON.parse(JSON.stringify(inputChoices)), [
    { index: 0, text: "Keyboard - English (US)", icon: "", enabled: true, separator: false, hasChildren: false, buttonType: "radio", checked: false },
    { index: 1, text: "Lotus", icon: "", enabled: true, separator: false, hasChildren: false, buttonType: "radio", checked: true },
], "input-method choices preserve native radio selection metadata");
assert.equal(rules.hasMenuForApp("chatgpt", "ChatGPT", selectionRecords), true,
    "ChatGPT must be identified as a tray-menu app for title fallback policy");
assert.equal(rules.hasMenuForApp("org.mozilla.firefox", "Firefox", selectionRecords), false,
    "an app without a matching tray menu must use its compositor title");
assert.equal(rules.popupEntryAction(menuEntries, 0), "none",
    "disabled menu headings are not actionable");
assert.equal(rules.popupEntryAction(menuEntries, 1), "trigger",
    "enabled leaf entries trigger their native action");
assert.equal(rules.popupEntryAction(menuEntries, 2), "none",
    "separators are not actionable");
const submenuEntries = rules.projectMenuEntries([
    { text: "More", icon: "", enabled: true, isSeparator: false, hasChildren: true, buttonType: "none", checked: false },
]);
assert.equal(rules.popupEntryAction(submenuEntries, 0), "submenu",
    "enabled parent entries enter their submenu");

assert.equal(
    rules.runningContext(menuEntries),
    "Nghiên cứu Event và độ ưu tiên",
    "the first enabled entry under Running becomes StartIsland context");
assert.equal(
    rules.runningContext(rules.projectMenuEntries([
        { text: "Running", icon: "", enabled: false, isSeparator: false, hasChildren: false },
        { text: "", icon: "", enabled: false, isSeparator: true, hasChildren: false },
        { text: "Recent", icon: "", enabled: false, isSeparator: false, hasChildren: false },
        { text: "Nghiên cứu Event và độ ưu tiên", icon: "", enabled: true, isSeparator: false, hasChildren: false },
        { text: "Phân tích và tái cấu trúc Titonium", icon: "", enabled: true, isSeparator: false, hasChildren: false },
    ])), "Nghiên cứu Event và độ ưu tiên",
    "the first Recent entry becomes context while ChatGPT is idle");

const antigravityActiveEntries = rules.projectMenuEntries([
    { text: "1 agent running", icon: "", enabled: false, isSeparator: false, hasChildren: false },
    { text: "", icon: "", enabled: false, isSeparator: true, hasChildren: false },
    { text: "Open Antigravity", icon: "", enabled: true, isSeparator: false, hasChildren: false },
    { text: "Quit", icon: "", enabled: true, isSeparator: false, hasChildren: false },
]);
assert.equal(
    rules.runningContext(antigravityActiveEntries),
    "1 agent running",
    "active agent count in Electron tray badge must become StartIsland context");

const antigravityIdleEntries = rules.projectMenuEntries([
    { text: "No agents running", icon: "", enabled: false, isSeparator: false, hasChildren: false },
    { text: "", icon: "", enabled: false, isSeparator: true, hasChildren: false },
    { text: "Open Antigravity", icon: "", enabled: true, isSeparator: false, hasChildren: false },
    { text: "Quit", icon: "", enabled: true, isSeparator: false, hasChildren: false },
]);
assert.equal(
    rules.runningContext(antigravityIdleEntries),
    "",
    "idle agent count does not clutter StartIsland context");

const taskRunningEntries = rules.projectMenuEntries([
    { text: "3 tasks in progress", icon: "", enabled: false, isSeparator: false, hasChildren: false },
    { text: "", icon: "", enabled: false, isSeparator: true, hasChildren: false },
    { text: "Preferences", icon: "", enabled: true, isSeparator: false, hasChildren: false },
]);
assert.equal(
    rules.runningContext(taskRunningEntries),
    "3 tasks in progress",
    "generic in-progress task count in tray menu becomes context");

const selectedMenuRecord = rules.selectRecord("chatgpt", "ChatGPT", selectionRecords);
assert.equal(selectedMenuRecord.nativeIndex, 2,
    "selection preserves native index and prefers a matching menu-bearing record");
assert.equal(selectedMenuRecord.hasMenu, true);
const chatSelection = rules.nextMenuSelection(
    null, "chatgpt", "ChatGPT", selectionRecords);
assert.deepEqual(JSON.parse(JSON.stringify(chatSelection)),
    { appId: "chatgpt", appName: "ChatGPT" },
    "a menu-bearing app becomes the retained QsMenuOpener selection");
const selectionAfterFirefox = rules.nextMenuSelection(
    chatSelection, "org.mozilla.firefox", "Firefox", selectionRecords);
assert.deepEqual(JSON.parse(JSON.stringify(selectionAfterFirefox)),
    { appId: "chatgpt", appName: "ChatGPT" },
    "switching through an app without a tray menu must not tear down the retained menu");
assert.equal(Object.isFrozen(selectionAfterFirefox), true);
assert.equal(Object.isFrozen(selectedMenuRecord), true);
const inputSelectionRecords = rules.projectRecords([
    { id: "chatgpt", title: "ChatGPT", tooltipTitle: "ChatGPT", tooltipDescription: "", icon: "", hasMenu: true },
    { id: "Fcitx", title: "Input Method", tooltipTitle: "Lotus", tooltipDescription: "", icon: "fcitx-lotus-default", hasMenu: true },
]);
const selectedInputRecord = rules.inputMethodRecord(inputSelectionRecords);
assert.deepEqual(
    JSON.parse(JSON.stringify(selectedInputRecord)),
    {
        nativeIndex: 1, id: "Fcitx", title: "Input Method",
        tooltipTitle: "Lotus", tooltipDescription: "",
        icon: "fcitx-lotus-default", inputMethod: true, hasMenu: true,
    },
    "Input icon menu intent must resolve the native Fcitx record");
assert.equal(
    rules.selectedContext(selectedMenuRecord, Object.freeze([]), "2 active conversations"),
    "",
    "a menu-bearing app must not flash tooltip metadata while DBusMenu loads");
assert.equal(
    rules.selectedContext(selectionRecords[1], Object.freeze([]), "2 active conversations"),
    "2 active conversations",
    "a selected item without a menu may retain tooltip context");

console.log("PASS SystemTray descriptor, context and Input Method routing rules");
