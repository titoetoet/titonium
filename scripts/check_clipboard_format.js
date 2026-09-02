#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const formatPath = path.join(
    __dirname,
    "..",
    "Titonium/Overlays/Spotlight/ClipboardFormat.js"
);

if (!fs.existsSync(formatPath)) {
    console.error("FAIL ClipboardFormat.js is missing");
    process.exit(1);
}

const context = vm.createContext({ String, Math, Date, encodeURIComponent });
const source = fs.readFileSync(formatPath, "utf8").replace(/^\.pragma library\s*/, "");
vm.runInContext(source, context, { filename: formatPath });

// Test MD5
assert.equal(
    context.md5("git@github.com:parzij/ArchLinux-setup.git"),
    "d1a01d6592ff83c727c95a24155c3475",
    "MD5 matches sample from reference screenshot"
);
assert.equal(
    context.md5(""),
    "d41d8cd98f00b204e9800998ecf8427e",
    "MD5 of empty string is empty MD5"
);
assert.equal(
    context.md5("hello world"),
    "5eb63bbbe01eeed093cb22bb8f5acdc3",
    "MD5 of hello world"
);

// Test copiedAt
const testDate = new Date(2026, 6, 19, 0, 13, 0); // Sun Jul 19 00:13:00 2026
assert.equal(
    context.copiedAt(testDate.getTime()),
    "Sun Jul 19 00:13:00 2026",
    "copiedAt formats date matching screenshot specification"
);

// Test relativeTime
const now = 1000000000000;
assert.equal(context.relativeTime(now - 10000, now), "just now", "just now within 60s");
assert.equal(context.relativeTime(now - 65000, now), "1 minute ago", "1 minute ago");
assert.equal(context.relativeTime(now - 7 * 60000, now), "7 minutes ago", "7 minutes ago");
assert.equal(context.relativeTime(now - 8 * 60000, now), "8 minutes ago", "8 minutes ago");
assert.equal(context.relativeTime(now - 18 * 60000, now), "18 minutes ago", "18 minutes ago");
assert.equal(context.relativeTime(now - 65 * 60000, now), "1 hour ago", "1 hour ago");
assert.equal(context.relativeTime(now - 5 * 3600000, now), "5 hours ago", "5 hours ago");
assert.equal(context.relativeTime(now - 25 * 3600000, now), "1 day ago", "1 day ago");
assert.equal(context.relativeTime(now - 3 * 86400000, now), "3 days ago", "3 days ago");

// Test sizeLabel
assert.equal(context.sizeLabel({ text: "git@github.com:parzij/ArchLinux-setup.git" }), "41 bytes", "41 bytes text length");
assert.equal(context.sizeLabel({ bytes: 41 }), "41 bytes", "exact bytes");
assert.equal(context.sizeLabel({ bytes: 2048 }), "2.0 KB", "KB conversion");

// Test typeLabel
assert.equal(context.typeLabel({ kind: "plain" }), "Text", "plain type is Text");
assert.equal(context.typeLabel({ kind: "code" }), "Text", "code type is Text");
assert.equal(context.typeLabel({ kind: "image" }), "Image", "image type is Image");

// Test label
assert.equal(context.label("type"), "Type", "Type label");
assert.equal(context.label("size"), "Size", "Size label");
assert.equal(context.label("copied_at"), "Copied at", "Copied at label");
assert.equal(context.label("md5"), "MD5", "MD5 label");
assert.equal(context.label("source"), "Source", "Source label");
assert.equal(context.label("path"), "Path", "Path label");

// Test sourceName & sourceIcon
assert.equal(context.sourceName({ sourceApp: "kitty" }), "Kitty", "kitty source name");
assert.equal(context.sourceIcon({ sourceApp: "kitty" }), "terminal", "kitty source icon");
assert.equal(context.sourceName({ text: "git@github.com:parzij/ArchLinux-setup.git" }), "Terminal", "git command source");
assert.equal(context.sourceIcon({ text: "git@github.com:parzij/ArchLinux-setup.git" }), "terminal", "git command icon");
assert.equal(context.sourceName({ kind: "image" }), "Screenshot", "image source name");
assert.equal(context.sourceIcon({ kind: "image" }), "image", "image source icon");

// Test itemPath
assert.equal(
    context.itemPath({ text: "git@github.com:parzij/ArchLinux-setup.git" }),
    "git@github.com:parzij/ArchLinux-setup.git",
    "git remote itemPath"
);
assert.equal(
    context.itemPath({ text: "cd ~/Asfedu/coding/ArchLinux" }),
    "~/Asfedu/coding/ArchLinux",
    "cd path itemPath"
);
assert.equal(
    context.itemPath({ kind: "image", imagePath: "/tmp/img.png" }),
    "/tmp/img.png",
    "image file path itemPath"
);
assert.equal(
    context.itemPath({ text: "Hello world without any path" }),
    "",
    "plain text has empty path"
);

// Test itemIcon
assert.equal(context.itemIcon({ kind: "image" }), "image", "image itemIcon");
assert.equal(context.itemIcon({ text: "cd ~/Asfedu/coding" }), "terminal", "terminal command itemIcon");
assert.equal(context.itemIcon({ kind: "plain", text: "Regular text" }), "title", "text itemIcon is title");
assert.equal(
    context.itemIcon({ sourceApp: "antigravity-ide", sourceTitle: "titonium - Antigravity IDE" }),
    "rocket_launch",
    "antigravity itemIcon is rocket_launch"
);
assert.equal(
    context.itemIcon({ sourceApp: "firefox", sourceTitle: "ChatGPT — Mozilla Firefox" }),
    "chat_bubble",
    "chatgpt itemIcon is chat_bubble"
);
assert.equal(
    context.itemIcon({ sourceApp: "firefox", sourceTitle: "Claude - Mozilla Firefox" }),
    "chat_bubble",
    "claude itemIcon is chat_bubble"
);
assert.equal(
    context.itemIcon({ sourceApp: "firefox", sourceTitle: "Arch Linux Documentation" }),
    "language",
    "website itemIcon is language"
);

// Test appIconSource
assert.equal(
    context.appIconSource({ sourceApp: "antigravity-ide" }),
    "/usr/share/pixmaps/antigravity-ide.png",
    "antigravity-ide icon path"
);
assert.equal(
    context.appIconSource({ sourceApp: "ChatGPT" }),
    "/usr/share/pixmaps/chatgpt.png",
    "chatgpt icon path"
);
assert.equal(
    context.appIconSource({ sourceApp: "google-chrome" }),
    "google-chrome",
    "google-chrome icon theme name"
);
assert.equal(
    context.appIconSource({ text: "regular text" }),
    "",
    "plain text has empty appIconSource"
);

console.log("PASS Clipboard format, source icon, path, and MD5 tests");
