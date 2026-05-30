import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

const nativeSourcePath = join(process.cwd(), 'ios/App/App/BeaconNativePlugin.m');
const safeBridgeSourcePath = join(process.cwd(), 'ios/App/App/BeaconLiteRtSafeBridge.mm');
const iosStageScriptPath = join(process.cwd(), 'scripts/stage_ios_litert_assets.sh');
const iosSmokeScriptPath = join(process.cwd(), 'scripts/ios_metal_smoke.sh');

function readNativeSource(): string {
  return readFileSync(nativeSourcePath, 'utf8');
}

describe('iOS native visual contract', () => {
  it('sends text content before image content for the official Gemma 4 LiteRT-LM conversation processor', () => {
    const source = readNativeSource();
    const start = source.indexOf('static NSArray<NSDictionary *> *BeaconBuildConversationContent');
    const end = source.indexOf('static BOOL BeaconDataContainsCString', start);
    const body = source.slice(start, end);

    const firstImageAdd = body.indexOf('@"type": @"image"');
    const firstTextAdd = body.indexOf('@"type": @"text"');

    expect(start).toBeGreaterThanOrEqual(0);
    expect(end).toBeGreaterThan(start);
    expect(firstImageAdd).toBeGreaterThanOrEqual(0);
    expect(firstTextAdd).toBeGreaterThanOrEqual(0);
    expect(firstTextAdd).toBeLessThan(firstImageAdd);
  });

  it('only treats ORCA-style vision_2520 Gemma 4 artifacts as iOS-validated', () => {
    const source = readNativeSource();

    expect(source).toContain('vision_2520');
    expect(source).toContain('vision_280');
    expect(source).toContain('vision_140');
    expect(source).toContain('vision_70');
    expect(source).toContain('positions_xy');
    expect(source).toContain('vision_adapter');
    expect(source).toContain('mm_embedding');
    expect(source).toContain('hasOfficialTieredEncoder');
    expect(source).toContain('iosValidatedVisionContract = hasOrcaEncoder');
    expect(source).toContain('visionArtifactContract');
    expect(source).toContain('visionArtifactIOSValidated');
    expect(source).toContain('official-tiered');
    expect(source).toContain('orca-2520');
    expect(source).toContain('official-tiered vision artifact is not iOS Metal validated');
    expect(source).toContain('validateVisionArtifactForRequestedModelId');
    expect(source).toContain('Visual model package unavailable. Photo analysis was not run.');
  });

  it('stages the official Gemma 4 E2B artifact first and keeps ORCA-style override support', () => {
    const script = readFileSync(iosStageScriptPath, 'utf8');

    expect(script).toContain('MODEL_SRC_DEFAULT');
    expect(script).toContain('gemma-4-E2B-it-orca2520.litertlm');
    expect(script).toContain('BEACON_IOS_GEMMA_MODEL_SRC');
    expect(script).toContain('Using official Gemma 4 E2B LiteRT-LM artifact for iOS');
    expect(script).toContain('Official Gemma 4 E2B artifact not found; using ORCA-style vision_2520 artifact');
  });

  it('patches BeaconNative plugin registration inside every built iOS app bundle', () => {
    const script = readFileSync(iosStageScriptPath, 'utf8');

    expect(script).toContain('ensure_beacon_native_plugin_registration');
    expect(script).toContain('BeaconNativePlugin');
    expect(script).toContain('App.BeaconNativePlugin');
    expect(script).toContain('${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/capacitor.config.json');
  });

  it('does not keep using a stale writable official-tiered copy after the bundled iOS model changes', () => {
    const source = readNativeSource();

    expect(source).toContain('modelFileAtURL:downloaded matchesExpectedSizeForSpec:spec bundledURL:bundled');
    expect(source).toContain('ignoring stale writable model copy; bundled artifact size changed');
    expect(source).toContain('if (bundledSize > 0) {');
    expect(source).toContain('return NO;');
  });

  it('does not run the native visual smoke when the iOS vision artifact is not validated', () => {
    const source = readNativeSource();
    const start = source.indexOf('- (void)runSmokeTests');
    const end = source.indexOf('NSDictionary *resetCheck', start);
    const body = source.slice(start, end);

    expect(start).toBeGreaterThanOrEqual(0);
    expect(end).toBeGreaterThan(start);
    expect(body).toContain('visualArtifactReady');
    expect(body).toContain('@\"skipped\": @YES');
    expect(body).toContain('visionArtifactContract');
  });

  it('keys engine reuse by the effective engine vision mode rather than the raw request flag', () => {
    const source = readNativeSource();
    const start = source.indexOf('- (BOOL)ensureEngineLoaded:');
    const end = source.indexOf('NSTimeInterval now', start);
    const body = source.slice(start, end);

    expect(start).toBeGreaterThanOrEqual(0);
    expect(end).toBeGreaterThan(start);
    expect(body).toContain('_loadedEngineRequiresVision == engineRequiresVision');
    expect(body).not.toContain('(!requiresVision || _loadedEngineRequiresVision)');
  });

  it('uses a lazy multimodal iOS engine only for visual turns and does not reuse the wrong engine mode', () => {
    const source = readNativeSource();
    const start = source.indexOf('- (BOOL)ensureEngineLoaded:');
    const end = source.indexOf('NSTimeInterval now', start);
    const body = source.slice(start, end);

    expect(start).toBeGreaterThanOrEqual(0);
    expect(end).toBeGreaterThan(start);
    expect(body).toContain('hasIOSValidatedVisionContract');
    expect(body).toContain('BOOL engineRequiresVision = requiresVision;');
    expect(body).toContain('supportsImageInput');
    expect(body).toContain('using lazy multimodal engine for visual turn');
    expect(body).toContain('_loadedEngineRequiresVision == engineRequiresVision');
    expect(source).toContain('_loadedEngineRequiresVision = engineRequiresVision');
  });

  it('clears stale smoke result files before each launch smoke run', () => {
    const source = readNativeSource();
    const start = source.indexOf('- (void)runSmokeTests');
    const end = source.indexOf('BeaconWriteSmokeProgress(@"smoke-tests-started"', start);
    const body = source.slice(start, end);

    expect(start).toBeGreaterThanOrEqual(0);
    expect(end).toBeGreaterThan(start);
    expect(body).toContain('removeItemAtURL:[self smokeResultsURL]');
    expect(body).toContain('removeItemAtURL:BeaconSmokeProgressURL()');
  });

  it('uses a real LiteRT cache for iOS Gemma 4 vision engine creation', () => {
    const source = readNativeSource();
    const start = source.indexOf('#else\n    BOOL forceGpuOnly');
    const end = source.indexOf('] : @[\n            @{\n                @"backend": @"cpu"', start);
    const body = source.slice(start, end);

    expect(start).toBeGreaterThanOrEqual(0);
    expect(end).toBeGreaterThan(start);
    expect(body).toContain('@"cacheMode": @"default"');
    expect(body).not.toContain('@"cacheMode": @"session-scoped"');
  });

  it('passes a bounded Gemma 4 visual token budget instead of the full default image budget', () => {
    const source = readNativeSource();
    const safeBridgeSource = readFileSync(safeBridgeSourcePath, 'utf8');

    expect(source).toContain('kBeaconGemma4TextTokenBudget = 170');
    expect(source).toContain('kBeaconGemma4VisualTokenBudget = 256');
    expect(source).toContain('requiresVision ? kBeaconGemma4VisualTokenBudget : kBeaconGemma4TextTokenBudget');
    expect(safeBridgeSource).toContain('litert_lm_conversation_optional_args_set_visual_token_budget');
  });

  it('passes the selected locale into iOS visual prompts instead of forcing English answers', () => {
    const source = readNativeSource();
    const start = source.indexOf('static NSString *BeaconBuildVisualUserPrompt');
    const end = source.indexOf('static BOOL BeaconVisualObservationLooksBlind', start);
    const body = source.slice(start, end);

    expect(start).toBeGreaterThanOrEqual(0);
    expect(end).toBeGreaterThan(start);
    expect(body).toContain('BeaconLanguageDirective(locale)');
    expect(body).toContain('BeaconOutputLanguageReminder(locale)');
    expect(body).toContain('USER_INPUT');
    expect(body).toContain('IMAGE_INPUT');
    expect(body).not.toContain('(void)locale');
    expect(body).not.toContain('Describe the visible content.');
  });

  it('lets the iOS real-device smoke force a visual locale for localized photo tests', () => {
    const script = readFileSync(iosSmokeScriptPath, 'utf8');

    expect(script).toContain('BEACON_SMOKE_VISUAL_LOCALE');
    expect(script).toContain('payload["visualLocale"] = visual_locale');
    expect(script).toContain('BEACON_SMOKE_VISUAL_QUERY');
    expect(script).toContain('payload["visualQuery"] = visual_query');
    expect(script).toContain('BEACON_SMOKE_VISUAL_ONLY');
    expect(script).toContain('payload["visualOnly"] = visual_only.lower() in {"1", "true", "yes"}');
  });

  it('trims obvious repeated iOS model degeneration before final display and memory storage', () => {
    const source = readNativeSource();

    expect(source).toContain('BeaconTrimDegenerateModelTail');
    expect(source).toContain('you should you should');
    expect(source).toContain('333333');
    expect(source).toContain('static NSString *BeaconFinalizeModelText');
    expect(source).toContain('BeaconRemoveTrailingOrphanListMarker');
    expect(source).toContain('finalText:BeaconFinalizeModelText(finalText ?: @"")');
  });

  it('keeps benchmark off while explicitly configuring one image for Gemma 4 vision', () => {
    const source = readNativeSource();
    const start = source.indexOf('- (BOOL)ensureEngineLoaded:');
    const end = source.indexOf('BeaconWriteSmokeProgress(@"engine-create-call"', start);
    const body = source.slice(start, end);

    expect(start).toBeGreaterThanOrEqual(0);
    expect(end).toBeGreaterThan(start);
    expect(body).not.toContain('litert_lm_engine_settings_enable_benchmark');
    expect(body).toContain('litert_lm_engine_settings_set_max_num_images(settings, 1)');
    expect(body).toContain('litert_lm_engine_settings_set_enable_speculative_decoding(settings, false)');
    expect(body).toContain('litert_lm_engine_settings_set_litert_dispatch_lib_dir');
  });

  it('stages the Gemma model constraint provider dylib required by the patched iOS LiteRT runtime', () => {
    const stageScript = readFileSync(
      join(process.cwd(), 'scripts/stage_ios_litert_assets.sh'),
      'utf8',
    );
    const projectFile = readFileSync(
      join(process.cwd(), 'ios/App/App.xcodeproj/project.pbxproj'),
      'utf8',
    );

    expect(stageScript).toContain('libGemmaModelConstraintProvider.dylib');
    expect(stageScript).toContain('codesign --force --sign "$CODE_SIGN_IDENTITY_TO_USE" --timestamp=none "$GEMMA_CONSTRAINT_PROVIDER_DST"');
    expect(projectFile).toContain('$(TARGET_BUILD_DIR)/$(FRAMEWORKS_FOLDER_PATH)/libGemmaModelConstraintProvider.dylib');
  });
});
