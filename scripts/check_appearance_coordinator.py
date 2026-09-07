#!/usr/bin/env python3
"""Run real coordinator with persistence and wallpaper I/O replaced at service boundary."""
import os, subprocess, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='appearance-coordinator-') as tmp:
 b=Path(tmp)
 def put(name,text):
  p=b/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text)
 def link(name,source):
  p=b/name;p.parent.mkdir(parents=True,exist_ok=True);p.symlink_to(ROOT/source)
 put('qs/Titonium/Settings/qmldir','module qs.Titonium.Settings\nsingleton AppearanceCoordinator 1.0 AppearanceCoordinator.qml\nsingleton SettingsCoordinator 1.0 SettingsCoordinator.qml\n')
 for n in ['AppearanceCoordinator.qml','AppearanceTransaction.js','SettingsCoordinator.qml','SettingsCatalog.js']:
  link('qs/Titonium/Settings/'+n,'Titonium/Settings/'+n)
 put('qs/Titonium/Core/Runtime/qmldir','module qs.Titonium.Core.Runtime\nsingleton Preferences 1.0 Preferences.qml\n')
 put('qs/Titonium/Core/Runtime/Preferences.qml','''pragma Singleton
import QtQuick
QtObject {
 property var committedState: ({appearance:{themeId:"neutral",mode:"dark",themeOverrides:{},wallpaper:{policy:"keep",customPath:""}},accessibility:{reducedMotion:false},locale:"vi",modules:{bar:{style:"connected"}}})
 property var previewState: JSON.parse(JSON.stringify(committedState))
 property bool previewActive: false
 readonly property var effectiveState: previewActive ? previewState : committedState
 property bool savePending:false
 property bool ready:true
 readonly property bool dirty:previewActive && JSON.stringify(previewState)!==JSON.stringify(committedState)
 property string lastError:""
 signal applyFinished(bool success)
 function beginPreview(){if(!previewActive)previewState=JSON.parse(JSON.stringify(committedState));previewActive=true;return true;}
 function stageAppearance(candidate,base){
  const s=JSON.parse(JSON.stringify(previewState));
  if(JSON.stringify(candidate.appearance)!==JSON.stringify(base.appearance))s.appearance=JSON.parse(JSON.stringify(candidate.appearance));
  if(candidate.reducedMotion!==base.reducedMotion)s.accessibility.reducedMotion=candidate.reducedMotion;
  previewState=s;return true;
 }
 function apply(){if(!dirty||savePending)return false;savePending=true;return true;}
 function finish(ok){if(ok)committedState=JSON.parse(JSON.stringify(previewState));savePending=false;applyFinished(ok);}
 function cancel(){previewState=JSON.parse(JSON.stringify(committedState));previewActive=false;}
}''')
 put('qs/Titonium/Services/Appearance/qmldir','module qs.Titonium.Services.Appearance\nsingleton AppearanceService 1.0 AppearanceService.qml\n')
 for n in ['AppearanceService.qml','AppearanceRules.js','ThemeCatalog.js','LegacyThemeCatalog.js']:
  link('qs/Titonium/Services/Appearance/'+n,'Titonium/Services/Appearance/'+n)
 put('qs/Titonium/Services/Wallpapers/qmldir','module qs.Titonium.Services.Wallpapers\nsingleton WallpapersService 1.0 WallpapersService.qml\n')
 put('qs/Titonium/Services/Wallpapers/WallpapersService.qml','''pragma Singleton
import QtQuick
QtObject {
 property bool busy:false
 property bool accept:false
 property bool appearanceLease:false
 property bool appearanceRecoveryReady:true
 property string lastError:""
 property var baselineSnapshot:null
 signal appearanceFinished(int generation,bool success,string error)
 signal appearanceSavingReady(int generation,bool success,string error)
 signal appearanceRolledBack(int generation,bool success,string error)
 signal appearanceCommitted(int generation,bool success,string error)
 function beginAppearance(screen,path,generation,candidate,fit){if(!accept)return false;appearanceLease=true;baselineSnapshot={screenName:screen,path:"/previous.png",fit:"contain"};return true;}
 function markAppearanceSaving(g){return accept;}
 function rollbackAppearance(g){return accept;}
 function commitAppearance(g){return accept;}
}''')
 # Exercise the real reset mutation with only persistence replaced at the boundary.
 link('qs/Titonium/Core/Runtime/PreferencesValidator.js','Titonium/Core/Runtime/PreferencesValidator.js')
 import json
 pref=b/'qs/Titonium/Core/Runtime/Preferences.qml'
 reset_source=(ROOT/'Titonium/Core/Runtime/Preferences.qml').read_text()
 reset_method=reset_source[reset_source.index('    function restorePaths('):reset_source.index('    function restoreAppearance(')]
 pref.write_text(pref.read_text().replace('import QtQuick', 'import QtQuick\nimport "PreferencesValidator.js" as Validator').replace('QtObject {', 'QtObject {\n id: root\n property var shippedDefaults: '+json.dumps(json.loads((ROOT/'config/defaults/settings.json').read_text()))+'\n'+reset_method))
 put('tst_appearance.qml','''import QtQuick
import QtTest
import qs.Titonium.Settings
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Appearance
import qs.Titonium.Services.Wallpapers
TestCase {
 name:"AppearanceCoordinator"
 function init(){
  WallpapersService.accept=false;WallpapersService.appearanceLease=false;
  AppearanceCoordinator.wallpaperHeld=false;AppearanceCoordinator.finalizationPending=false;
  AppearanceCoordinator.phase="idle";AppearanceCoordinator.undoRecord=null;
  Preferences.savePending=false;Preferences.committedState={appearance:{themeId:"neutral",mode:"dark",themeOverrides:{},wallpaper:{policy:"keep",customPath:""}},accessibility:{reducedMotion:false},locale:"vi",modules:{bar:{style:"connected"}}};
  Preferences.cancel();AppearanceCoordinator.close();SettingsCoordinator.ownerScreenName="";SettingsCoordinator.open("DP-1","appearance");
 }
 function cleanup(){Preferences.savePending=false;AppearanceCoordinator.close();Preferences.cancel();}
 function test_reset_one_page_preserves_other_edits_and_committed_state(){
  Preferences.previewState=Object.assign({},Preferences.previewState,{locale:"en",modules:{bar:{style:"classic"},audio:{allowAmplification:true}}});
  AppearanceCoordinator.selectTheme("glassmorphism");
  SettingsCoordinator.requestPage("audio");verify(SettingsCoordinator.restoreDefaults(false));
  compare(Preferences.previewState.modules.audio.allowAmplification,false);
  compare(Preferences.previewState.modules.bar.style,"classic");compare(Preferences.previewState.locale,"en");
  compare(AppearanceCoordinator.candidate.appearance.themeId,"glassmorphism");
  compare(Preferences.committedState.locale,"vi");verify(!Preferences.savePending);
  SettingsCoordinator.requestPage("about");verify(!SettingsCoordinator.restoreDefaults(false));
 }
 function test_global_reset_stages_defaults_then_apply(){
  Preferences.previewState=Object.assign({},Preferences.previewState,{locale:"en",applications:{hiddenIds:["hidden.desktop"]},modules:{bar:{style:"classic"},audio:{allowAmplification:true}}});
  AppearanceCoordinator.selectTheme("glassmorphism");AppearanceCoordinator.setReducedMotion(true);
  verify(SettingsCoordinator.restoreDefaults(true));
  compare(AppearanceCoordinator.candidate.appearance.themeId,"modern-flat");
  compare(AppearanceCoordinator.candidate.reducedMotion,false);
  compare(JSON.stringify(Preferences.previewState.modules),JSON.stringify(Preferences.shippedDefaults.modules));
  compare(Preferences.previewState.applications.hiddenIds.length,0);verify(!Preferences.savePending);
  verify(SettingsCoordinator.apply());Preferences.finish(true);
  compare(Preferences.committedState.modules.bar.style,"connected");
 }
 function test_appearance_reset_clears_overrides_and_close_discards(){
  AppearanceCoordinator.selectTheme("glassmorphism");AppearanceCoordinator.setOverride("accent","#aa22ff");
  AppearanceCoordinator.startTrial();AppearanceCoordinator.keepTrial();
  verify(SettingsCoordinator.restoreDefaults(false));
  compare(AppearanceCoordinator.candidate.appearance.themeId,"modern-flat");
  compare(JSON.stringify(AppearanceCoordinator.candidate.appearance.themeOverrides),"{}");
  SettingsCoordinator.discardAndClose();compare(Preferences.effectiveState.appearance.themeId,"neutral");
 }
 function test_style_without_wallpaper_is_rejected_before_staging(){
  const stagedBefore=JSON.stringify(Preferences.previewState), activeBefore=Preferences.previewActive;
  AppearanceCoordinator.selectTheme("material");AppearanceCoordinator.setWallpaper("theme","");
  verify(AppearanceCoordinator.themeWallpaperMissing);
  verify(!AppearanceCoordinator.startTrial());verify(!AppearanceCoordinator.apply());
  compare(Preferences.savePending,false);compare(Preferences.previewActive,activeBefore);compare(JSON.stringify(Preferences.previewState),stagedBefore);
  compare(AppearanceCoordinator.error,"settings.appearance.no_style_wallpaper");
  AppearanceCoordinator.setWallpaper("keep","");verify(!AppearanceCoordinator.themeWallpaperMissing);
  verify(AppearanceCoordinator.startTrial());
 }
 function test_legacy_wallpaper_still_resolves(){
  AppearanceCoordinator.candidate={appearance:{themeId:"glass",mode:"dark",wallpaper:{policy:"theme",customPath:""}},reducedMotion:false};
  verify(AppearanceCoordinator.wallpaperPath().endsWith("glass-dark.png"));
 }
 function test_candidate_is_local_until_trial(){
  AppearanceCoordinator.selectTheme("glassmorphism");
  compare(Preferences.effectiveState.appearance.themeId,"neutral");
  compare(AppearanceCoordinator.tokens.themeId,"glassmorphism");
  verify(AppearanceCoordinator.startTrial());
  compare(AppearanceService.tokens.themeId,"glassmorphism");
  AppearanceCoordinator.cancelTrial();
  compare(AppearanceService.tokens.themeId,"neutral");
  compare(AppearanceCoordinator.candidate.appearance.themeId,"glassmorphism");
 }
 function test_keep_stages_and_cancel_rolls_back(){
  AppearanceCoordinator.selectTheme("neumorphism");AppearanceCoordinator.startTrial();AppearanceCoordinator.keepTrial();
  compare(Preferences.effectiveState.appearance.themeId,"neumorphism");
  compare(Preferences.committedState.appearance.themeId,"neutral");
  AppearanceCoordinator.close();Preferences.cancel();
  compare(AppearanceService.tokens.themeId,"neutral");
 }
 function test_failed_save_does_not_commit_and_can_retry(){
  AppearanceCoordinator.selectTheme("material");
  verify(AppearanceCoordinator.apply());verify(Preferences.savePending);
  Preferences.finish(false);
  compare(Preferences.committedState.appearance.themeId,"neutral");verify(!AppearanceCoordinator.busy);
  verify(AppearanceCoordinator.apply());Preferences.finish(true);
  compare(Preferences.committedState.appearance.themeId,"material");verify(AppearanceCoordinator.canUndo);
  verify(AppearanceCoordinator.undoLastApply());Preferences.finish(true);
  compare(Preferences.committedState.appearance.themeId,"neutral");
 }
 function startWallpaperApply(){
  WallpapersService.accept=true;
  AppearanceCoordinator.selectTheme("glassmorphism");AppearanceCoordinator.setWallpaper("custom","/candidate.png");
  verify(AppearanceCoordinator.apply());
  const g=AppearanceCoordinator.generation;
  WallpapersService.appearanceFinished(g,true,"");
  compare(AppearanceCoordinator.phase,"marking");
  WallpapersService.appearanceSavingReady(g,true,"");
  verify(Preferences.savePending);return g;
 }
 function test_preparation_failure_rolls_back_possible_side_effect(){
  WallpapersService.accept=true;AppearanceCoordinator.setWallpaper("custom","/candidate.png");
  verify(AppearanceCoordinator.startTrial());
  WallpapersService.appearanceFinished(AppearanceCoordinator.generation,false,"timeout");
  compare(AppearanceCoordinator.phase,"rollback");verify(AppearanceCoordinator.wallpaperHeld);
  WallpapersService.appearanceLease=false;
  WallpapersService.appearanceRolledBack(AppearanceCoordinator.generation,true,"");
  compare(AppearanceCoordinator.phase,"idle");verify(!AppearanceCoordinator.wallpaperHeld);
 }
 function test_post_save_failure_cancel_does_not_rollback_committed_wallpaper(){
  const g=startWallpaperApply();Preferences.finish(true);
  WallpapersService.appearanceCommitted(g,false,"persistence");
  verify(AppearanceCoordinator.finalizationPending);
  AppearanceCoordinator.cancelTrial();
  compare(AppearanceCoordinator.phase,"idle");
  compare(Preferences.committedState.appearance.themeId,"glassmorphism");
  verify(AppearanceCoordinator.retryFinalization());
  WallpapersService.appearanceLease=false;WallpapersService.appearanceCommitted(g,true,"");
  verify(!AppearanceCoordinator.finalizationPending);verify(AppearanceCoordinator.canUndo);
 }
 function test_owner_loss_during_save_cancels_preview_after_completion(){
  AppearanceCoordinator.selectTheme("glassmorphism");SettingsCoordinator.apply();
  verify(Preferences.savePending);SettingsCoordinator.closeForOwnerLoss();
  compare(SettingsCoordinator.ownerScreenName,"");
  Preferences.finish(false);
  verify(!Preferences.previewActive);verify(!AppearanceCoordinator.sessionOpen);
  compare(Preferences.effectiveState.appearance.themeId,"neutral");
 }
 function test_trial_rollback_does_not_leak_wallpaper_baseline_into_keep_apply(){
  WallpapersService.accept=true;AppearanceCoordinator.setWallpaper("custom","/candidate.png");
  AppearanceCoordinator.startTrial();const g=AppearanceCoordinator.generation;
  WallpapersService.appearanceFinished(g,true,"");AppearanceCoordinator.cancelTrial();
  WallpapersService.appearanceLease=false;WallpapersService.appearanceRolledBack(g,true,"");
  AppearanceCoordinator.setWallpaper("keep","");AppearanceCoordinator.selectTheme("glassmorphism");
  AppearanceCoordinator.apply();Preferences.finish(true);
  compare(AppearanceCoordinator.undoRecord.wallpaperBaseline,null);
 }
 function test_wallpaper_undo_remembers_actual_baseline_even_keep_policy(){
  const g=startWallpaperApply();Preferences.finish(true);
  WallpapersService.appearanceLease=false;WallpapersService.appearanceCommitted(g,true,"");
  verify(AppearanceCoordinator.undoLastApply());
  compare(AppearanceCoordinator.wallpaperPath(),"/previous.png");
  compare(AppearanceCoordinator.undoWallpaperTarget.fit,"contain");
  compare(AppearanceCoordinator.phase,"preparing");
 }
 function test_stale_wallpaper_callback_does_not_change_trial(){
  WallpapersService.accept=true;AppearanceCoordinator.setWallpaper("custom","/candidate.png");
  AppearanceCoordinator.startTrial();
  WallpapersService.appearanceFinished(AppearanceCoordinator.generation-1,true,"");
  compare(AppearanceCoordinator.phase,"preparing");
 }
 function test_reset_custom_candidate_matches_persisted_normalization(){
  AppearanceCoordinator.selectTheme("glassmorphism");AppearanceCoordinator.setOverride("accent","#003388");
  AppearanceCoordinator.resetOverride("accent");
  compare(JSON.stringify(AppearanceCoordinator.candidate.appearance.themeOverrides),"{}");
  AppearanceCoordinator.stageCandidate();
  compare(JSON.stringify(AppearanceCoordinator.candidate.appearance),JSON.stringify(Preferences.effectiveState.appearance));
 }
 function test_return_to_initial_after_keep_replaces_staged_values(){
  AppearanceCoordinator.selectTheme("glassmorphism");AppearanceCoordinator.setReducedMotion(true);
  AppearanceCoordinator.startTrial();AppearanceCoordinator.keepTrial();
  AppearanceCoordinator.selectTheme("modern-flat");AppearanceCoordinator.setReducedMotion(false);
  AppearanceCoordinator.stageCandidate();
  compare(Preferences.effectiveState.appearance.themeId,"modern-flat");
  compare(Preferences.effectiveState.accessibility.reducedMotion,false);
 }
 function test_close_during_failed_save_releases_session(){
  AppearanceCoordinator.selectTheme("glassmorphism");AppearanceCoordinator.apply();
  AppearanceCoordinator.close();Preferences.finish(false);
  verify(!AppearanceCoordinator.sessionOpen);
  compare(Preferences.effectiveState.appearance.themeId,"neutral");
  AppearanceCoordinator.open("DP-1");verify(AppearanceCoordinator.sessionOpen);
 }
 function test_advanced_closing_preserves_custom_and_modes_isolate(){
  AppearanceCoordinator.selectTheme("glassmorphism");AppearanceCoordinator.setAdvancedOpen(true);
  AppearanceCoordinator.setMode("dark");AppearanceCoordinator.setOverride("accent","#aa22ff");
  AppearanceCoordinator.setMode("light");AppearanceCoordinator.setOverride("accent","#003388");
  AppearanceCoordinator.setAdvancedOpen(false);
  compare(AppearanceCoordinator.candidate.appearance.themeOverrides.glassmorphism.dark.accent,"#aa22ff");
  compare(AppearanceCoordinator.candidate.appearance.themeOverrides.glassmorphism.light.accent,"#003388");
 }
}''')
 result=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(b),'-import',str(b)],env={**os.environ,'QT_QPA_PLATFORM':'offscreen','QT_QUICK_BACKEND':'software'})
 raise SystemExit(result.returncode)
