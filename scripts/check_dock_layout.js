#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const dockRoot = path.join(root, "Titonium", "Dock");
const files = {
  host: path.join(dockRoot, "DockHost.qml"),
  window: path.join(dockRoot, "DockWindow.qml"),
  surface: path.join(dockRoot, "DockSurface.qml"),
  button: path.join(dockRoot, "DockAppButton.qml"),
  coordinator: path.join(dockRoot, "DockItemMenuCoordinator.qml"),
  menu: path.join(dockRoot, "DockItemMenuSurface.qml"),
  qmldir: path.join(dockRoot, "qmldir"),
};

const errors = [];

function source(name) {
  const target = files[name];
  if (!fs.existsSync(target)) {
    errors.push(`missing ${path.relative(root, target)}`);
    return "";
  }
  return fs.readFileSync(target, "utf8");
}

function requireFragments(name, fragments) {
  const text = source(name);
  for (const fragment of fragments) {
    if (!text.includes(fragment))
      errors.push(`${name} missing ${fragment}`);
  }
  return text;
}

function requireAbsent(name, fragments) {
  const text = source(name);
  for (const fragment of fragments) {
    if (text.includes(fragment))
      errors.push(`${name} has forbidden ${fragment}`);
  }
}

function layoutFixture() {
  const body = 56;
  const icon = 40;
  const margin = 8;
  const spacing = 6;
  const reveal = 4;
  const reserve = body + margin;
  if (body !== 56 || icon !== 40 || margin !== 8 || spacing !== 6)
    errors.push("dock geometry fixture changed");
  if (reveal !== 4)
    errors.push("edge reveal fixture changed");
  if (reserve !== 64)
    errors.push("pinned reserve fixture changed");
}

layoutFixture();
requireFragments("host", ["Variants {", "model: ScreenPolicy.screens", "DockWindow {", "applicationsRequested"]);
requireFragments("window", [
  "PanelWindow {", "WlrLayershell.namespace: \"titonium-dock\"",
  "readonly property int bodyHeight: 56", "readonly property int edgeRevealHeight: 4",
  "readonly property int reservedHeight: 64", "exclusiveZone: root.pinnedOpen ? root.reservedHeight : 0",
  "mask: Region {", "Region { item: dockSurface }", "Region { item: edgeReveal }",
  "WlrLayershell.exclusionMode: root.pinnedOpen ? ExclusionMode.Normal : ExclusionMode.Ignore",
  "WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand", "WlrLayershell.layer: WlrLayer.Overlay",
  "dockSurface.itemMenuActive",
]);
requireFragments("surface", [
  "readonly property int bodyHeight: 56", "readonly property int itemSpacing: 6",
  "readonly property real hoverScale: 1.12", "readonly property int hoverLift: 4",
  "Motion.fast", "Behavior on opacity", "Behavior on y", "applicationsRequested",
  "DockAppButton", "DockItemMenuCoordinator", "DockStore.setPinnedOpen", "itemMenu.active",
]);
requireFragments("button", [
  "readonly property int iconSize: 40", "scale: root.hovered ? root.hoverScale : 1",
  "y: root.hovered ? -root.hoverLift : 0", "Motion.fast", "DockService.activateOrLaunch",
  "DockService.launchNew", "menuRequested", "Keys.onPressed", "size: root.iconSize",
  "QtControls.ToolTip.visible", "dock.application_tooltip",
]);
requireFragments("coordinator", [
  "SurfaceManager.open", "DockItemMenuSurface.qml", "function open(dockItem: var, invoker: var, screen: var): bool",
  "function menuItem(dockItem: var): var", "\"item\": item", "function close(): bool", "keyboardFocus\": \"exclusive\"",
]);
requireFragments("menu", [
  "SurfaceManager.close", "Keys.onEscapePressed", "dock.menu.new_window", "dock.menu.pin",
  "dock.menu.unpin", "dock.menu.close_active", "root.item?.runningCount > 0",
  "height: menuColumn.implicitHeight + menuPanel.padding * 2",
  "DockService.launchNew", "DockService.togglePin", "DockService.closeActive", "returnFocus",
]);
requireFragments("qmldir", ["module qs.Titonium.Dock", "DockHost 1.0 DockHost.qml"]);

for (const name of Object.keys(files))
  requireAbsent(name, ["Process", "FileView", "Timer {", "MultiEffect", "ShaderEffect", "gradient", "blur", "hyprctl", "bluetoothctl"]);

requireAbsent("window", ["WlrLayershell.keyboardFocus: WlrKeyboardFocus.None", "WlrLayershell.layer: WlrLayer.Top"]);

if (errors.length > 0) {
  for (const error of errors)
    console.error(`FAIL ${error}`);
  process.exit(1);
}

console.log("PASS Dock layout and lifecycle fixtures");
