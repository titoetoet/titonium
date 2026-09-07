import QtQuick
import QtTest
import qs.Titonium.Settings
import qs.Titonium.Settings.pages
import qs.Titonium.Settings.components
import qs.Titonium.Services.Appearance

TestCase {
    id: testCase
    name: "AppearancePresentation"
    when: windowShown
    visible: true
    width: 720; height: 700
    Rectangle { anchors.fill: parent; color: "#111318"; z: -1 }
    readonly property var dark: AppearanceService.resolveCandidate({appearance: {themeId: "glass", mode: "dark"}})
    readonly property var light: AppearanceService.resolveCandidate({appearance: {themeId: "soft", mode: "light"}})
    Component { id: previewFactory; ThemePreview { width: 600; height: 258 } }
    Component { id: cardFactory; ThemeCard { width: 160; height: 160 } }
    Component { id: pageFactory; AppearancePage { width: 700; height: 680 } }
    Component { id: advancedFactory; AppearanceAdvanced { width: 640 } }
    SignalSpy { id: spy }
    function cleanup() { spy.target = null; spy.clear(); }
    function test_five_style_cards_and_local_layout_preview() {
        const page=createTemporaryObject(pageFactory,testCase);
        const grid=findChild(page,"designStyleGrid");
        verify(grid !== null);compare(grid.columns,3);
        compare(AppearanceService.catalog.length,5);
        page.width=520;wait(20);compare(grid.columns,2);
        const preview=findChild(page,"designStylePreview");verify(preview !== null);
        const before=JSON.stringify(AppearanceCoordinator.candidate);
        preview.layoutStyle="classic";wait(20);compare(JSON.stringify(AppearanceCoordinator.candidate),before);
    }
    function test_opaque_style_advanced_is_structurally_bounded() {
        const t=AppearanceService.resolveCandidate({appearance:{themeId:"modern-flat",mode:"dark"}});
        const editor=createTemporaryObject(advancedFactory,testCase,{tokens:t});
        verify(!findChild(editor,"backgroundOpacitySlider").enabled);
        verify(!findChild(editor,"shadowStrengthSlider").enabled);
        verify(!findChild(editor,"sheenStrengthSlider").enabled);
        verify(findChild(editor,"radiusScaleSlider").enabled);
    }
    function test_preview_uses_candidate_without_runtime_mutation() {
        const before = JSON.stringify(AppearanceService.tokens);
        const preview = createTemporaryObject(previewFactory, testCase, {tokens: dark});
        compare(preview.previewPalette.accent, dark.colors.accent);
        preview.tokens = light;
        compare(preview.previewPalette.accent, light.colors.accent);
        compare(preview.previewPalette.textPrimary, light.colors.textPrimary);
        compare(JSON.stringify(AppearanceService.tokens), before);
    }
    function test_card_keyboard_selects_descriptor() {
        const card = createTemporaryObject(cardFactory, testCase, {
            descriptor: {id: "glass", nameKey: "settings.appearance.theme.glass"}, tokens: dark
        });
        spy.signalName = "selectedTheme"; spy.target = card;
        card.forceActiveFocus();
        keyClick(Qt.Key_Space);
        compare(spy.count, 1); compare(spy.signalArguments[0][0], "glass");
        card.enabled = false;
        card.activate();
        compare(spy.count, 1);
    }
    function test_advanced_has_bounded_values_and_reduced_motion() {
        const editor = createTemporaryObject(advancedFactory, testCase, {tokens: dark});
        const opacity = findChild(editor, "backgroundOpacitySlider");
        verify(opacity !== null);
        compare(opacity.from, 0.85); compare(opacity.to, 1);
        const radius = findChild(editor, "radiusScaleSlider");
        compare(radius.from, 0.75); compare(radius.to, 1.25);
        const motion = findChild(editor, "motionScaleSlider");
        compare(motion.from, 0.5); compare(motion.to, 1.5);
        editor.reducedMotion = true;
        verify(!motion.enabled);
        editor.reducedMotion = false;
        verify(motion.enabled);
        editor.overrides = {radiusScale: 1.2};
        compare(radius.value, 1.2);
    }
    function test_advanced_defaults_follow_pinned_edit_mode() {
        const original = AppearanceCoordinator.candidate;
        AppearanceCoordinator.candidate = {appearance: {themeId: "glass", mode: "light"}, reducedMotion: false};
        AppearanceCoordinator.editMode = "dark";
        AppearanceCoordinator.advancedOpen = true;
        const page = createTemporaryObject(pageFactory, testCase);
        compare(page.advancedTokens.mode, "dark");
        const editor = findChild(page, "advancedLoader").item;
        compare(editor.tokens.colors.accent, dark.colors.accent);
        compare(findChild(editor, "accentInput").text, dark.colors.accent);
        AppearanceCoordinator.candidate = original;
        AppearanceCoordinator.advancedOpen = false;
    }
    function test_page_advanced_is_lazy_and_escape_reverts_trial() {
        AppearanceCoordinator.advancedOpen = false;
        const page = createTemporaryObject(pageFactory, testCase);
        verify(page !== null);
        const loader = findChild(page, "advancedLoader");
        compare(loader.item, null);
        findChild(page, "advancedButton").activate();
        verify(loader.item !== null);
        findChild(page, "advancedButton").activate();
        compare(loader.item, null);
        AppearanceCoordinator.startTrial();
        page.forceActiveFocus();
        keyClick(Qt.Key_Escape);
        verify(!AppearanceCoordinator.trialActive);
        wait(50);
        const screenshot = grabImage(page);
        screenshot.save("/tmp/titonium-appearance-ui.png");
    }
    function test_accent_validation_rejects_malformed_input() {
        const editor = createTemporaryObject(advancedFactory, testCase, {tokens: dark});
        const input = findChild(editor, "accentInput");
        input.text = "#12345";
        verify(!input.acceptableInput);
        input.text = "#12345Z";
        verify(!input.acceptableInput);
        input.text = "#12aB56";
        verify(input.acceptableInput);
        spy.signalName = "fieldEdited"; spy.target = editor;
        input.editingFinished();
        compare(spy.count, 1);
        compare(spy.signalArguments[0][0], "accent");
        compare(spy.signalArguments[0][1], "#12AB56");
    }
}
