#import <Foundation/Foundation.h>
#import <TargetConditionals.h>
#import <dlfcn.h>
#import <UIKit/UIKit.h>
#import <Capacitor/Capacitor.h>
#import <Capacitor/CAPBridgedJSTypes.h>
#import "BeaconLiteRtSafeBridge.h"
@import BeaconLiteRtLm;
@import Metal;

static NSString * const kBeaconLoadedModelIdKey = @"beacon.native.loadedModelId";
static NSString * const kBeaconDefaultModelId = @"gemma-4-e2b";
static NSString * const kBeaconPreferredBackendKeyPrefix = @"beacon.native.preferredBackend.";
static NSString * const kBeaconGpuBlockedReasonKeyPrefix = @"beacon.native.gpuBlockedReason.";
static NSString * const kBeaconGpuWarmupAttemptedKeyPrefix = @"beacon.native.gpuWarmupAttempted.";
static NSString * const kBeaconRuntimeStackLiteRtLmCApi = @"litert-lm-c-api";
static NSString * const kBeaconArtifactFormatLiteRtLm = @"litertlm";
static NSString * const kBeaconPreferredBackendAutoReal = @"auto-real";
static NSString * const kBeaconSmokeTestEnvKey = @"BEACON_SMOKE_TEST";
static NSString * const kBeaconSmokeTestQueryEnvKey = @"BEACON_SMOKE_QUERY";
static NSString * const kBeaconLiteRtRuntimeDispatchModeEnvKey = @"BEACON_LITERT_RUNTIME_DISPATCH_MODE";
static NSString * const kBeaconLiteRtCacheModeEnvKey = @"BEACON_LITERT_CACHE_MODE";
static NSString * const kBeaconLiteRtGpuOnlyEnvKey = @"BEACON_LITERT_GPU_ONLY";
static NSString * const kBeaconLiteRtAllowUnsafeGpuOnlyEnvKey = @"BEACON_LITERT_ALLOW_UNSAFE_GPU_ONLY";
static NSString * const kBeaconLiteRtSkipGpuEnvKey = @"BEACON_LITERT_SKIP_GPU";
static NSString * const kBeaconLiteRtMaxTokensEnvKey = @"BEACON_LITERT_MAX_TOKENS";
static NSString * const kBeaconLiteRtPrefillChunkSizeEnvKey = @"BEACON_LITERT_PREFILL_CHUNK_SIZE";
static NSString * const kBeaconLiteRtSessionMaxOutputTokensEnvKey = @"BEACON_LITERT_SESSION_MAX_OUTPUT_TOKENS";
static NSString * const kBeaconLiteRtActivationDataTypeEnvKey = @"BEACON_LITERT_ACTIVATION_DATA_TYPE";
static NSString * const kBeaconLiteRtSamplerBackendEnvKey = @"BEACON_LITERT_SAMPLER_BACKEND";
static NSString * const kBeaconLiteRtParallelFileLoadingEnvKey = @"BEACON_LITERT_PARALLEL_FILE_LOADING";
static NSString * const kBeaconLiteRtInjectDispatchLibraryDirEnvKey = @"BEACON_LITERT_INJECT_DISPATCH_LIBRARY_DIR";
static NSString * const kBeaconSmokeTestLaunchArgument = @"--beacon-smoke-test";
static NSString * const kBeaconSmokeQueryLaunchArgumentPrefix = @"--beacon-smoke-query=";
static NSString * const kBeaconSmokeRequestFileName = @"beacon-native-smoke-request.json";
static NSString * const kBeaconTriageStreamEventName = @"triageStreamEvent";
static unsigned long long const kBeaconMinimumGemma4IosMemoryBytes = 6ull * 1024ull * 1024ull * 1024ull;
static NSUInteger const kBeaconRecentMemoryTurns = 6;
static NSUInteger const kBeaconMaxRollingSummaryChars = 420;
static NSUInteger const kBeaconMaxRecentChatContextChars = 960;
static NSUInteger const kBeaconMaxLastVisualContextChars = 260;
static NSUInteger const kBeaconMaxRememberedUserTurnChars = 160;
static NSUInteger const kBeaconMaxRememberedAssistantTurnChars = 260;
static NSString * const kBeaconDefaultVisualPromptWithImage = @"What dangers do you see and what should I do next?";
static NSString * const kBeaconDefaultVisualPromptWithoutImage = @"What visible details should I check and what should I do next?";
static BOOL gBeaconSmokeRunClaimed = NO;
static id gBeaconStandaloneSmokeRunner = nil;
static void *gBeaconMetalAcceleratorHandle = NULL;
static NSString *gBeaconLiteRtSessionCacheToken = nil;

static void BeaconNativeLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"[BeaconNative] %@", message);
}

static BOOL BeaconParseBooleanValue(NSString *value, BOOL *parsedValue) {
    NSString *normalized = [[value ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    if ([normalized isEqualToString:@"1"]
        || [normalized isEqualToString:@"true"]
        || [normalized isEqualToString:@"yes"]
        || [normalized isEqualToString:@"on"]) {
        if (parsedValue != NULL) {
            *parsedValue = YES;
        }
        return YES;
    }
    if ([normalized isEqualToString:@"0"]
        || [normalized isEqualToString:@"false"]
        || [normalized isEqualToString:@"no"]
        || [normalized isEqualToString:@"off"]) {
        if (parsedValue != NULL) {
            *parsedValue = NO;
        }
        return YES;
    }
    return NO;
}

static BOOL BeaconEnvFlagEnabled(NSString *name) {
    BOOL enabled = NO;
    return BeaconParseBooleanValue([[NSProcessInfo processInfo] environment][name], &enabled) && enabled;
}

static BOOL BeaconHasLaunchArgument(NSString *flag) {
    for (NSString *argument in [[NSProcessInfo processInfo] arguments]) {
        if ([argument isEqualToString:flag]) {
            return YES;
        }
    }
    return NO;
}

static NSString *BeaconLaunchArgumentValue(NSString *prefix) {
    for (NSString *argument in [[NSProcessInfo processInfo] arguments]) {
        if ([argument hasPrefix:prefix]) {
            return [argument substringFromIndex:prefix.length];
        }
    }
    return nil;
}

static NSURL *BeaconSmokeRequestURL(void) {
    NSURL *tmpDirectory = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    return [tmpDirectory URLByAppendingPathComponent:kBeaconSmokeRequestFileName isDirectory:NO];
}

static NSDictionary *BeaconSmokeRequestPayload(void) {
    NSData *data = [NSData dataWithContentsOfURL:BeaconSmokeRequestURL()];
    if (data == nil) {
        return nil;
    }

    NSError *error = nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error != nil || ![json isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    return (NSDictionary *)json;
}

static NSString *BeaconSmokeRequestStringValue(NSString *key) {
    id value = BeaconSmokeRequestPayload()[key];
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

static BOOL BeaconParseIntegerValue(id rawValue, NSInteger *parsedValue) {
    if ([rawValue isKindOfClass:[NSNumber class]]) {
        if (parsedValue != NULL) {
            *parsedValue = [(NSNumber *)rawValue integerValue];
        }
        return YES;
    }
    if (![rawValue isKindOfClass:[NSString class]]) {
        return NO;
    }

    NSString *trimmed = [(NSString *)rawValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        return NO;
    }

    NSScanner *scanner = [NSScanner scannerWithString:trimmed];
    NSInteger scannedValue = 0;
    if (![scanner scanInteger:&scannedValue] || !scanner.isAtEnd) {
        return NO;
    }
    if (parsedValue != NULL) {
        *parsedValue = scannedValue;
    }
    return YES;
}

static BOOL BeaconSmokeRequestFlagValue(NSString *key, BOOL *parsedValue) {
    id value = BeaconSmokeRequestPayload()[key];
    if ([value isKindOfClass:[NSNumber class]]) {
        if (parsedValue != NULL) {
            *parsedValue = [(NSNumber *)value boolValue];
        }
        return YES;
    }
    if ([value isKindOfClass:[NSString class]]) {
        return BeaconParseBooleanValue((NSString *)value, parsedValue);
    }
    return NO;
}

static BOOL BeaconRequestedFlagEnabled(NSString *envKey, NSString *requestKey) {
    BOOL parsedValue = NO;
    if (BeaconParseBooleanValue([[NSProcessInfo processInfo] environment][envKey], &parsedValue)) {
        return parsedValue;
    }
    if (BeaconSmokeRequestFlagValue(requestKey, &parsedValue)) {
        return parsedValue;
    }
    return NO;
}

static BOOL BeaconRequestedFlagValue(NSString *envKey, NSString *requestKey, BOOL *parsedValue) {
    if (BeaconParseBooleanValue([[NSProcessInfo processInfo] environment][envKey], parsedValue)) {
        return YES;
    }
    return BeaconSmokeRequestFlagValue(requestKey, parsedValue);
}

static BOOL BeaconRequestedIntegerValue(NSString *envKey, NSString *requestKey, NSInteger *parsedValue) {
    if (BeaconParseIntegerValue([[NSProcessInfo processInfo] environment][envKey], parsedValue)) {
        return YES;
    }
    return BeaconParseIntegerValue(BeaconSmokeRequestPayload()[requestKey], parsedValue);
}

static NSString *BeaconRequestedStringValue(NSString *envKey, NSString *requestKey) {
    NSString *environmentValue = [[[NSProcessInfo processInfo] environment][envKey] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (environmentValue.length > 0) {
        return environmentValue;
    }
    NSString *requestValue = BeaconSmokeRequestStringValue(requestKey);
    return [requestValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static BOOL BeaconSmokeTestRequested(void) {
    if (BeaconEnvFlagEnabled(kBeaconSmokeTestEnvKey) || BeaconHasLaunchArgument(kBeaconSmokeTestLaunchArgument)) {
        return YES;
    }

    NSDictionary *request = BeaconSmokeRequestPayload();
    id enabled = request[@"enabled"];
    if ([enabled respondsToSelector:@selector(boolValue)]) {
        return [enabled boolValue];
    }
    return request != nil;
}

static BOOL BeaconClaimSmokeRun(void) {
    @synchronized ([NSProcessInfo class]) {
        if (gBeaconSmokeRunClaimed) {
            return NO;
        }
        gBeaconSmokeRunClaimed = YES;
        return YES;
    }
}

static NSString *BeaconSmokeQueryOverride(void) {
    NSString *environmentValue = [[NSProcessInfo processInfo] environment][kBeaconSmokeTestQueryEnvKey];
    NSString *trimmedEnvironmentValue = [environmentValue ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmedEnvironmentValue.length > 0) {
        return environmentValue;
    }
    NSString *launchArgumentValue = BeaconLaunchArgumentValue(kBeaconSmokeQueryLaunchArgumentPrefix);
    if (launchArgumentValue.length > 0) {
        return launchArgumentValue;
    }
    id fileQuery = BeaconSmokeRequestPayload()[@"query"];
    return [fileQuery isKindOfClass:[NSString class]] ? fileQuery : nil;
}

static NSString *BeaconSmokeTraceToken(void) {
    return BeaconSmokeRequestStringValue(@"traceToken");
}

static NSString *BeaconISO8601TimestampNow(void) {
    NSISO8601DateFormatter *formatter = [NSISO8601DateFormatter new];
    return [formatter stringFromDate:[NSDate date]];
}

static NSURL *BeaconSmokeProgressURL(void) {
    NSURL *tmpDirectory = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    return [tmpDirectory URLByAppendingPathComponent:@"beacon-native-smoke-progress.json" isDirectory:NO];
}

static void BeaconWriteSmokeProgress(NSString *stage, NSDictionary *details) {
    if (!BeaconSmokeTestRequested()) {
        return;
    }

    NSMutableDictionary *payload = [@{
        @"stage": stage ?: @"",
        @"timestamp": BeaconISO8601TimestampNow()
    } mutableCopy];
    if (details != nil) {
        [payload addEntriesFromDictionary:details];
    }

    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:&error];
    if (data == nil || error != nil) {
        return;
    }
    [data writeToURL:BeaconSmokeProgressURL() options:NSDataWritingAtomic error:nil];
}

static NSString *BeaconTruncatedPreview(NSString *value, NSUInteger limit) {
    NSString *trimmed = value != nil ? [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"";
    if (trimmed.length <= limit) {
        return trimmed;
    }
    return [[trimmed substringToIndex:limit] stringByAppendingString:@"..."];
}

static NSString *BeaconTrimmedString(NSString *value) {
    return [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString *BeaconNormalizeModelText(NSString *value) {
    NSString *normalized = value != nil ? [value stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"] : @"";
    normalized = [normalized stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
    NSMutableString *cleaned = [NSMutableString stringWithCapacity:normalized.length];
    for (NSUInteger index = 0; index < normalized.length; index += 1) {
        unichar character = [normalized characterAtIndex:index];
        BOOL isControlCharacter = ((character < 0x20 || character == 0x7F) &&
                                   character != '\n' &&
                                   character != '\t');
        if (!isControlCharacter) {
            [cleaned appendFormat:@"%C", character];
        }
    }
    return cleaned;
}

static NSString *BeaconSanitizeModelText(NSString *value) {
    return BeaconNormalizeModelText(value);
}

static BOOL BeaconHasMeaningfulModelText(NSString *value) {
    return BeaconTrimmedString(BeaconSanitizeModelText(value ?: @"")).length > 0;
}

static NSString *BeaconNormalizeLocale(NSString *locale) {
    NSString *trimmed = locale != nil ? BeaconTrimmedString(locale) : @"";
    return trimmed.length > 0 ? trimmed : @"en";
}

static NSString *BeaconLanguageDirective(NSString *locale) {
    NSString *normalized = [BeaconNormalizeLocale(locale) lowercaseString];
    if ([normalized hasPrefix:@"zh-cn"] || [normalized isEqualToString:@"zh"]) return @"Answer strictly in Simplified Chinese.";
    if ([normalized hasPrefix:@"zh-tw"] || [normalized hasPrefix:@"zh-hk"]) return @"Answer strictly in Traditional Chinese.";
    if ([normalized hasPrefix:@"ja"]) return @"Answer strictly in Japanese.";
    if ([normalized hasPrefix:@"ko"]) return @"Answer strictly in Korean.";
    if ([normalized hasPrefix:@"es"]) return @"Answer strictly in Spanish.";
    if ([normalized hasPrefix:@"fr"]) return @"Answer strictly in French.";
    if ([normalized hasPrefix:@"de"]) return @"Answer strictly in German.";
    if ([normalized hasPrefix:@"pt"]) return @"Answer strictly in Portuguese.";
    if ([normalized hasPrefix:@"ru"]) return @"Answer strictly in Russian.";
    if ([normalized hasPrefix:@"ar"]) return @"Answer strictly in Arabic.";
    if ([normalized hasPrefix:@"hi"]) return @"Answer strictly in Hindi.";
    if ([normalized hasPrefix:@"it"]) return @"Answer strictly in Italian.";
    if ([normalized hasPrefix:@"tr"]) return @"Answer strictly in Turkish.";
    if ([normalized hasPrefix:@"vi"]) return @"Answer strictly in Vietnamese.";
    if ([normalized hasPrefix:@"th"]) return @"Answer strictly in Thai.";
    if ([normalized hasPrefix:@"id"]) return @"Answer strictly in Indonesian.";
    if ([normalized hasPrefix:@"nl"]) return @"Answer strictly in Dutch.";
    if ([normalized hasPrefix:@"pl"]) return @"Answer strictly in Polish.";
    if ([normalized hasPrefix:@"uk"]) return @"Answer strictly in Ukrainian.";
    if ([normalized hasPrefix:@"ms"]) return @"Answer strictly in Malay.";
    return @"Answer strictly in English.";
}

static NSString *BeaconTargetLanguageName(NSString *locale) {
    NSString *normalized = [BeaconNormalizeLocale(locale) lowercaseString];
    if ([normalized hasPrefix:@"zh-cn"] || [normalized isEqualToString:@"zh"]) {
        return @"Simplified Chinese";
    }
    if ([normalized hasPrefix:@"zh-tw"] || [normalized hasPrefix:@"zh-hk"]) {
        return @"Traditional Chinese";
    }
    if ([normalized hasPrefix:@"ja"]) {
        return @"Japanese";
    }
    if ([normalized hasPrefix:@"ko"]) {
        return @"Korean";
    }
    if ([normalized hasPrefix:@"es"]) {
        return @"Spanish";
    }
    if ([normalized hasPrefix:@"fr"]) {
        return @"French";
    }
    if ([normalized hasPrefix:@"de"]) {
        return @"German";
    }
    if ([normalized hasPrefix:@"pt"]) {
        return @"Portuguese";
    }
    if ([normalized hasPrefix:@"ru"]) {
        return @"Russian";
    }
    if ([normalized hasPrefix:@"ar"]) {
        return @"Arabic";
    }
    if ([normalized hasPrefix:@"hi"]) {
        return @"Hindi";
    }
    if ([normalized hasPrefix:@"it"]) {
        return @"Italian";
    }
    if ([normalized hasPrefix:@"tr"]) {
        return @"Turkish";
    }
    if ([normalized hasPrefix:@"vi"]) {
        return @"Vietnamese";
    }
    if ([normalized hasPrefix:@"th"]) {
        return @"Thai";
    }
    if ([normalized hasPrefix:@"id"]) {
        return @"Indonesian";
    }
    if ([normalized hasPrefix:@"nl"]) {
        return @"Dutch";
    }
    if ([normalized hasPrefix:@"pl"]) {
        return @"Polish";
    }
    if ([normalized hasPrefix:@"uk"]) {
        return @"Ukrainian";
    }
    if ([normalized hasPrefix:@"ms"]) {
        return @"Malay";
    }
    return @"English";
}

static NSString *BeaconOutputLanguageReminder(NSString *locale) {
    NSString *languageName = BeaconTargetLanguageName(locale);
    return [NSString stringWithFormat:@"Write the final answer only in %@. If retrieved knowledge is in another language, translate it into %@ before answering.", languageName, languageName];
}

static NSString *BeaconResolvedVisualUserText(NSString *userText, BOOL hasImage) {
    NSString *trimmed = BeaconTrimmedString(userText ?: @"");
    if (trimmed.length > 0) {
        return trimmed;
    }
    return hasImage ? kBeaconDefaultVisualPromptWithImage : kBeaconDefaultVisualPromptWithoutImage;
}

static NSString *BeaconCompactGroundingContext(NSString *groundingContext) {
    NSString *trimmed = groundingContext != nil ? BeaconTrimmedString(groundingContext) : @"";
    if (trimmed.length == 0) {
        return @"";
    }

    NSString *normalized = [[trimmed stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"] copy];
    while ([normalized containsString:@"\n\n"]) {
        normalized = [normalized stringByReplacingOccurrencesOfString:@"\n\n" withString:@"\n"];
    }

    NSArray<NSString *> *rawLines = [normalized componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    for (NSString *rawLine in rawLines) {
        NSString *line = BeaconTrimmedString(rawLine);
        if (line.length == 0) {
            continue;
        }
        [lines addObject:line];
        if (lines.count >= 8) {
            break;
        }
    }

    NSString *joined = [lines componentsJoinedByString:@" | "];
    if (joined.length <= 360) {
        return joined;
    }
    return [joined substringToIndex:360];
}

static NSString *BeaconEngineLoadCacheKey(NSString *modelId, BOOL requiresVision) {
    return [NSString stringWithFormat:@"%@|vision=%@", modelId ?: @"", requiresVision ? @"1" : @"0"];
}

static NSString *BeaconNormalizedBase64Blob(NSString *value) {
    NSString *trimmed = value != nil ? BeaconTrimmedString(value) : @"";
    if (trimmed.length == 0) {
        return nil;
    }
    if ([trimmed hasPrefix:@"data:"]) {
        NSRange commaRange = [trimmed rangeOfString:@","];
        if (commaRange.location != NSNotFound && (commaRange.location + 1) < trimmed.length) {
            trimmed = [trimmed substringFromIndex:(commaRange.location + 1)];
        }
    }
    trimmed = [[[trimmed stringByReplacingOccurrencesOfString:@"\r" withString:@""]
                stringByReplacingOccurrencesOfString:@"\n" withString:@""]
               stringByReplacingOccurrencesOfString:@" " withString:@""];
    return trimmed.length > 0 ? trimmed : nil;
}

static NSArray<NSDictionary *> *BeaconBuildConversationContent(NSString *prompt, NSString *imageBase64) {
    NSMutableArray<NSDictionary *> *content = [NSMutableArray array];
    NSString *safePrompt = prompt ?: @"";
    if (imageBase64.length > 0) {
        [content addObject:@{ @"type": @"image", @"blob": imageBase64 }];
        if (safePrompt.length > 0) {
            [content addObject:@{ @"type": @"text", @"text": safePrompt }];
        }
        return content;
    }
    [content addObject:@{ @"type": @"text", @"text": safePrompt }];
    return content;
}

static NSString *BeaconSystemInstruction(void) {
    return @"You are Beacon.\n"
           @"Answer directly based on the user's input.\n"
           @"Refer to retrieved knowledge base content when it is helpful.\n"
           @"The knowledge base is only a reference.\n"
           @"If the knowledge base does not cover the question, you must still answer.";
}

static NSString *BeaconRuntimeStackForSpec(NSDictionary *spec) {
    NSString *value = [spec[@"runtimeStack"] isKindOfClass:[NSString class]] ? spec[@"runtimeStack"] : nil;
    return value.length > 0 ? value : kBeaconRuntimeStackLiteRtLmCApi;
}

static NSString *BeaconArtifactFormatForSpec(NSDictionary *spec) {
    NSString *value = [spec[@"artifactFormat"] isKindOfClass:[NSString class]] ? spec[@"artifactFormat"] : nil;
    return value.length > 0 ? value : kBeaconArtifactFormatLiteRtLm;
}

static NSString *BeaconPreferredBackendDirectiveForSpec(NSDictionary *spec) {
    NSString *value = [spec[@"preferredBackend"] isKindOfClass:[NSString class]] ? spec[@"preferredBackend"] : nil;
    return value.length > 0 ? value : kBeaconPreferredBackendAutoReal;
}

static NSString *BeaconSupportedDeviceClass(void) {
#if TARGET_OS_SIMULATOR
    return @"simulator";
#else
    unsigned long long physicalMemory = [NSProcessInfo processInfo].physicalMemory;
    UIUserInterfaceIdiom idiom = UIDevice.currentDevice.userInterfaceIdiom;
    if (idiom == UIUserInterfaceIdiomPhone) {
        return physicalMemory >= kBeaconMinimumGemma4IosMemoryBytes ? @"iphone_primary" : @"iphone_legacy";
    }
    if (idiom == UIUserInterfaceIdiomPad) {
        return physicalMemory >= kBeaconMinimumGemma4IosMemoryBytes ? @"ipad_compat" : @"ipad_low_memory";
    }
    return @"unknown";
#endif
}

static BOOL BeaconSupportsReleasedGpuAutoForDeviceClass(NSString *supportedDeviceClass) {
    return [supportedDeviceClass isEqualToString:@"iphone_primary"];
}

static BOOL BeaconUsesConservativeCpuProfileForDeviceClass(NSString *supportedDeviceClass) {
    return [supportedDeviceClass isEqualToString:@"ipad_compat"];
}

static NSDictionary *BeaconCapabilitySnapshotForSpec(NSDictionary *spec) {
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    NSString *supportedDeviceClass = BeaconSupportedDeviceClass();
    payload[@"supportedDeviceClass"] = supportedDeviceClass;
    payload[@"runtimeStack"] = BeaconRuntimeStackForSpec(spec);
    payload[@"artifactFormat"] = BeaconArtifactFormatForSpec(spec);

    NSArray *accelerators = [spec[@"accelerators"] isKindOfClass:[NSArray class]] ? spec[@"accelerators"] : @[ @"cpu" ];
    BOOL gpuHinted = [accelerators containsObject:@"gpu"];
    BOOL metalAvailable = (MTLCreateSystemDefaultDevice() != nil);
    BOOL memorySupported = [NSProcessInfo processInfo].physicalMemory == 0
        || [NSProcessInfo processInfo].physicalMemory >= kBeaconMinimumGemma4IosMemoryBytes;
    BOOL releasedGpuAutoSupported = BeaconSupportsReleasedGpuAutoForDeviceClass(supportedDeviceClass);

#if TARGET_OS_SIMULATOR
    payload[@"capabilityClass"] = @"simulator";
    payload[@"gpuEligible"] = @NO;
#else
    if ([spec[@"id"] isEqualToString:kBeaconDefaultModelId] && !memorySupported) {
        payload[@"capabilityClass"] = @"unsupported_memory";
    } else {
        payload[@"capabilityClass"] = @"supported";
    }
    payload[@"gpuEligible"] = @(
        gpuHinted &&
        metalAvailable &&
        memorySupported &&
        releasedGpuAutoSupported &&
        [payload[@"capabilityClass"] isEqualToString:@"supported"]
    );
#endif

    return payload;
}

static NSError *BeaconUnsupportedDeviceErrorForModelId(NSString *modelId) {
#if TARGET_OS_SIMULATOR
    return nil;
#else
    if (![modelId isEqualToString:kBeaconDefaultModelId]) {
        return nil;
    }

    unsigned long long physicalMemory = [NSProcessInfo processInfo].physicalMemory;
    if (physicalMemory == 0 || physicalMemory >= kBeaconMinimumGemma4IosMemoryBytes) {
        return nil;
    }

    double memoryGiB = ((double)physicalMemory) / (1024.0 * 1024.0 * 1024.0);
    NSString *message = [NSString stringWithFormat:
                         @"This iPhone has %.1f GB RAM, below the current Gemma 4 E2B iOS baseline of 6 GB. 当前 iPhone 内存低于 6GB，无法在本机启动 Gemma 4 E2B。",
                         memoryGiB];
    return [NSError errorWithDomain:@"BeaconNative"
                               code:109
                           userInfo:@{NSLocalizedDescriptionKey: message}];
#endif
}

static NSError *BeaconBlockedGpuOnlyErrorForModelId(NSString *modelId) {
#if TARGET_OS_SIMULATOR
    return nil;
#else
    if (![modelId isEqualToString:kBeaconDefaultModelId]) {
        return nil;
    }

    return [NSError errorWithDomain:@"BeaconNative"
                               code:118
                           userInfo:@{
                               NSLocalizedDescriptionKey:
                                   @"GPU-only mode is temporarily blocked for Gemma 4 E2B on this iOS runtime because the current LiteRT Metal delegate still crashes during initialization. Beacon keeps the stable on-device CPU path as the supported mode."
                           }];
#endif
}

static NSDictionary *BeaconMetalSnapshot(void) {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    NSMutableDictionary *snapshot = [@{
        @"metalAvailable": @(device != nil),
        @"simulator": @(TARGET_OS_SIMULATOR != 0),
        @"physicalMemoryBytes": @([NSProcessInfo processInfo].physicalMemory),
        @"minimumRecommendedMemoryBytes": @(kBeaconMinimumGemma4IosMemoryBytes)
    } mutableCopy];
    if (device != nil && device.name.length > 0) {
        snapshot[@"metalDeviceName"] = device.name;
    }
    return snapshot;
}

static BOOL BeaconRuntimeSymbolPresent(const char *symbolName) {
    return symbolName != NULL && dlsym(RTLD_DEFAULT, symbolName) != NULL;
}

static BOOL BeaconBundleContainsLibraryNamed(NSString *libraryName) {
    if (libraryName.length == 0) {
        return NO;
    }

    NSBundle *bundle = [NSBundle mainBundle];
    NSMutableArray<NSURL *> *roots = [NSMutableArray array];
    if (bundle.bundleURL != nil) {
        [roots addObject:bundle.bundleURL];
    }
    if (bundle.privateFrameworksURL != nil) {
        [roots addObject:bundle.privateFrameworksURL];
    }
    if (bundle.sharedFrameworksURL != nil) {
        [roots addObject:bundle.sharedFrameworksURL];
    }
    if (bundle.builtInPlugInsURL != nil) {
        [roots addObject:bundle.builtInPlugInsURL];
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator<NSURL *> *enumerator = nil;
    for (NSURL *root in roots) {
        BOOL isDirectory = NO;
        if (![fileManager fileExistsAtPath:root.path isDirectory:&isDirectory] || !isDirectory) {
            continue;
        }
        enumerator = [fileManager enumeratorAtURL:root
                       includingPropertiesForKeys:nil
                                          options:NSDirectoryEnumerationSkipsHiddenFiles
                                     errorHandler:nil];
        for (NSURL *entry in enumerator) {
            if ([[entry lastPathComponent] isEqualToString:libraryName]) {
                return YES;
            }
        }
    }
    return NO;
}

static NSString *BeaconLiteRtRuntimeLibraryDirectory(void) {
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *frameworksPath = bundle.privateFrameworksURL.path;
    if (frameworksPath.length > 0) {
        return frameworksPath;
    }
    if (bundle.bundleURL.path.length > 0) {
        return [bundle.bundleURL.path stringByAppendingPathComponent:@"Frameworks"];
    }
    return nil;
}

static NSString *BeaconNormalizedRuntimeDispatchMode(NSString *rawMode) {
    NSString *normalized = [[(rawMode != nil ? rawMode : @"") lowercaseString] copy];
    if ([normalized isEqualToString:@"explicit-dir"] ||
        [normalized isEqualToString:@"preload-only"] ||
        [normalized isEqualToString:@"disabled"]) {
        return normalized;
    }
    return nil;
}

static NSString *BeaconLiteRtRuntimeDispatchMode(void) {
    NSString *normalized = BeaconNormalizedRuntimeDispatchMode(NSProcessInfo.processInfo.environment[kBeaconLiteRtRuntimeDispatchModeEnvKey]);
    if (normalized.length > 0) {
        return normalized;
    }
    normalized = BeaconNormalizedRuntimeDispatchMode(BeaconSmokeRequestStringValue(@"runtimeDispatchMode"));
    if (normalized.length > 0) {
        return normalized;
    }
#if TARGET_OS_SIMULATOR
    return @"preload-only";
#else
    // On real devices, preload-only has been more reliable for fast GPU
    // eligibility probing and clean CPU fallback when Gemma 4 GPU init fails.
    // Engineers can still force explicit-dir via env for manual validation.
    return @"preload-only";
#endif
}

static NSString *BeaconLiteRtNormalizedCacheMode(NSString *rawValue) {
    NSString *normalized = [[(rawValue != nil ? rawValue : @"") lowercaseString] copy];
    if ([normalized isEqualToString:@"default"] ||
        [normalized isEqualToString:@"nocache"] ||
        [normalized isEqualToString:@"session-scoped"] ||
        [normalized isEqualToString:@"trace-scoped"]) {
        return normalized;
    }
    return nil;
}

static NSString *BeaconNormalizedBackendIdentifier(NSString *rawValue) {
    NSString *normalized = [[(rawValue != nil ? rawValue : @"") lowercaseString] copy];
    if ([normalized isEqualToString:@"cpu"] || [normalized isEqualToString:@"gpu"]) {
        return normalized;
    }
    return nil;
}

static NSString *BeaconLiteRtRequestedCacheMode(void) {
    NSString *environmentValue = [[NSProcessInfo processInfo] environment][kBeaconLiteRtCacheModeEnvKey];
    NSString *normalizedEnvironmentValue = BeaconLiteRtNormalizedCacheMode(environmentValue);
    if (normalizedEnvironmentValue.length > 0) {
        return normalizedEnvironmentValue;
    }

    NSString *requestValue = BeaconSmokeRequestStringValue(@"cacheMode");
    NSString *normalizedRequestValue = BeaconLiteRtNormalizedCacheMode(requestValue);
    if (normalizedRequestValue.length > 0) {
        return normalizedRequestValue;
    }
    return nil;
}

static NSString *BeaconLiteRtSanitizePathComponent(NSString *value) {
    NSString *source = value.length > 0 ? value : @"default";
    NSMutableString *result = [NSMutableString stringWithCapacity:source.length];
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
                               @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._"];
    for (NSUInteger index = 0; index < source.length; index++) {
        unichar character = [source characterAtIndex:index];
        if ([allowed characterIsMember:character]) {
            [result appendFormat:@"%C", character];
        } else {
            [result appendString:@"_"];
        }
    }
    while ([result containsString:@"__"]) {
        [result replaceOccurrencesOfString:@"__"
                                withString:@"_"
                                   options:0
                                     range:NSMakeRange(0, result.length)];
    }
    NSString *trimmed = [result stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"._-"]];
    if (trimmed.length == 0) {
        return @"default";
    }
    return trimmed.length > 64 ? [trimmed substringToIndex:64] : trimmed;
}

static NSString *BeaconLiteRtSessionCacheToken(void) {
    @synchronized ([NSProcessInfo class]) {
        if (gBeaconLiteRtSessionCacheToken.length == 0) {
            gBeaconLiteRtSessionCacheToken = [[[NSUUID UUID] UUIDString] copy];
        }
        return gBeaconLiteRtSessionCacheToken;
    }
}

static NSString *BeaconLiteRtCacheDirectoryRoot(void) {
    NSArray<NSURL *> *cacheDirectories = [[NSFileManager defaultManager]
                                          URLsForDirectory:NSCachesDirectory
                                          inDomains:NSUserDomainMask];
    NSURL *baseDirectory = cacheDirectories.firstObject;
    if (baseDirectory == nil) {
        baseDirectory = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    }
    return [[baseDirectory URLByAppendingPathComponent:@"BeaconLiteRt" isDirectory:YES] path];
}

static NSString *BeaconLiteRtCacheSpecifierForAttempt(NSURL *modelURL,
                                                      NSString *backend,
                                                      NSString *attemptLabel,
                                                      NSString *requestedModeOverride,
                                                      NSString **modeOut) {
    NSString *requestedMode = BeaconLiteRtNormalizedCacheMode(requestedModeOverride);
    if (requestedMode.length == 0) {
        requestedMode = BeaconLiteRtRequestedCacheMode();
    }
    NSString *normalizedBackend = [[backend ?: @"" lowercaseString] copy];
    NSString *mode = requestedMode;
    if (mode.length == 0) {
        mode = [normalizedBackend isEqualToString:@"gpu"] ? @"session-scoped" : @"default";
    }
    if (modeOut != NULL) {
        *modeOut = mode;
    }
    if ([mode isEqualToString:@"nocache"]) {
        return @":nocache";
    }

    NSString *root = BeaconLiteRtCacheDirectoryRoot();
    NSString *modelComponent = BeaconLiteRtSanitizePathComponent(modelURL.lastPathComponent);
    NSString *backendComponent = BeaconLiteRtSanitizePathComponent(normalizedBackend.length > 0 ? normalizedBackend : @"default");
    NSMutableArray<NSString *> *components = [NSMutableArray arrayWithArray:@[
        root,
        modelComponent,
        backendComponent
    ]];
    if ([mode isEqualToString:@"session-scoped"]) {
        [components addObject:BeaconLiteRtSanitizePathComponent(BeaconLiteRtSessionCacheToken())];
    } else if ([mode isEqualToString:@"trace-scoped"]) {
        NSString *traceComponent = BeaconSmokeTraceToken().length > 0 ? BeaconSmokeTraceToken() : BeaconLiteRtSessionCacheToken();
        [components addObject:BeaconLiteRtSanitizePathComponent(traceComponent)];
        [components addObject:BeaconLiteRtSanitizePathComponent(attemptLabel)];
    }

    NSString *cacheDirectory = [NSString pathWithComponents:components];
    NSError *directoryError = nil;
    BOOL created = [[NSFileManager defaultManager] createDirectoryAtPath:cacheDirectory
                                             withIntermediateDirectories:YES
                                                              attributes:nil
                                                                   error:&directoryError];
    if (!created) {
        BeaconNativeLog(@"failed to create LiteRT cache dir %@ error=%@", cacheDirectory, directoryError.localizedDescription ?: @"unknown");
        return @":nocache";
    }
    return cacheDirectory;
}

static BOOL BeaconLiteRtShouldPreloadMetalAccelerator(void) {
    return ![BeaconLiteRtRuntimeDispatchMode() isEqualToString:@"disabled"];
}

static BOOL BeaconLiteRtShouldInjectDispatchLibraryDir(void) {
    return [BeaconLiteRtRuntimeDispatchMode() isEqualToString:@"explicit-dir"];
}

static NSDictionary *BeaconDlopenProbe(NSString *libraryPath) {
    BOOL exists = libraryPath.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:libraryPath];
    NSMutableDictionary *payload = [@{
        @"path": libraryPath ?: @"",
        @"exists": @(exists),
        @"loadable": @NO
    } mutableCopy];
    if (!exists) {
        return payload;
    }

    dlerror();
    void *handle = dlopen(libraryPath.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL);
    if (handle != NULL) {
        payload[@"loadable"] = @YES;
        dlclose(handle);
        return payload;
    }

    const char *loadError = dlerror();
    if (loadError != NULL) {
        payload[@"error"] = [NSString stringWithUTF8String:loadError] ?: @"dlopen failed";
    }
    return payload;
}

static NSDictionary *BeaconEnsureMetalAcceleratorPreloaded(NSString *libraryPath) {
    BOOL exists = libraryPath.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:libraryPath];
    NSMutableDictionary *payload = [@{
        @"path": libraryPath ?: @"",
        @"exists": @(exists),
        @"loadable": @NO,
        @"preloaded": @NO
    } mutableCopy];
    if (!exists) {
        return payload;
    }

    @synchronized ([NSProcessInfo class]) {
        if (gBeaconMetalAcceleratorHandle != NULL) {
            payload[@"loadable"] = @YES;
            payload[@"preloaded"] = @YES;
            return payload;
        }

        dlerror();
        void *handle = dlopen(libraryPath.fileSystemRepresentation, RTLD_NOW | RTLD_GLOBAL);
        if (handle != NULL) {
            gBeaconMetalAcceleratorHandle = handle;
            payload[@"loadable"] = @YES;
            payload[@"preloaded"] = @YES;
            return payload;
        }
    }

    const char *loadError = dlerror();
    if (loadError != NULL) {
        payload[@"error"] = [NSString stringWithUTF8String:loadError] ?: @"dlopen failed";
    }
    return payload;
}

static NSDictionary *BeaconLiteRtRuntimeAudit(void) {
    BOOL gpuEnvironmentSymbolPresent = BeaconRuntimeSymbolPresent("LiteRtGpuEnvironmentCreate");
    BOOL metalTensorInteropSymbolPresent = BeaconRuntimeSymbolPresent("LiteRtCreateTensorBufferFromMetalMemory");
    BOOL metalArgumentBufferSymbolPresent = BeaconRuntimeSymbolPresent("LrtSetGpuOptionsUseMetalArgumentBuffers");
    BOOL staticTopKMetalSamplerSymbolPresent = BeaconRuntimeSymbolPresent("LiteRtTopKMetalSampler_Create_Static");
    BOOL topKMetalSamplerDylibPresent = BeaconBundleContainsLibraryNamed(@"libLiteRtTopKMetalSampler.dylib");
    BOOL metalAcceleratorDylibPresent = BeaconBundleContainsLibraryNamed(@"libLiteRtMetalAccelerator.dylib");
    NSString *runtimeLibraryDir = BeaconLiteRtRuntimeLibraryDirectory();
    NSString *expectedMetalAcceleratorPath = runtimeLibraryDir.length > 0
        ? [runtimeLibraryDir stringByAppendingPathComponent:@"libLiteRtMetalAccelerator.dylib"]
        : nil;
    NSDictionary *metalAcceleratorProbe = BeaconDlopenProbe(expectedMetalAcceleratorPath);
    NSString *runtimeDispatchMode = BeaconLiteRtRuntimeDispatchMode();

    return @{
        @"runtimeDispatchMode": runtimeDispatchMode,
        @"gpuEnvironmentSymbolPresent": @(gpuEnvironmentSymbolPresent),
        @"metalTensorInteropSymbolPresent": @(metalTensorInteropSymbolPresent),
        @"metalArgumentBufferSymbolPresent": @(metalArgumentBufferSymbolPresent),
        @"staticTopKMetalSamplerSymbolPresent": @(staticTopKMetalSamplerSymbolPresent),
        @"topKMetalSamplerDylibPresent": @(topKMetalSamplerDylibPresent),
        @"metalAcceleratorDylibPresent": @(metalAcceleratorDylibPresent),
        @"runtimeLibraryDir": runtimeLibraryDir ?: @"",
        @"expectedMetalAcceleratorPath": expectedMetalAcceleratorPath ?: @"",
        @"expectedMetalAcceleratorExists": metalAcceleratorProbe[@"exists"] ?: @NO,
        @"expectedMetalAcceleratorLoadable": metalAcceleratorProbe[@"loadable"] ?: @NO,
        @"expectedMetalAcceleratorLoadError": metalAcceleratorProbe[@"error"] ?: @"",
        @"willPreloadMetalAccelerator": @(BeaconLiteRtShouldPreloadMetalAccelerator()),
        @"willInjectDispatchLibraryDir": @(BeaconLiteRtShouldInjectDispatchLibraryDir()),
        @"gpuSymbolsPresent": @(
            gpuEnvironmentSymbolPresent &&
            metalTensorInteropSymbolPresent &&
            metalArgumentBufferSymbolPresent
        ),
        @"metalSamplerPresent": @(
            staticTopKMetalSamplerSymbolPresent ||
            topKMetalSamplerDylibPresent
        )
    };
}

static NSString *BeaconNormalizedPromptBlock(NSString *value, NSUInteger limit) {
    NSString *trimmed = value != nil ? BeaconTrimmedString(value) : @"";
    if (trimmed.length == 0) {
        return nil;
    }
    if (trimmed.length <= limit) {
        return trimmed;
    }
    return [[trimmed substringToIndex:limit] stringByAppendingString:@"..."];
}

static NSString *BeaconBuildUserPrompt(NSString *locale,
                                       NSString *powerMode,
                                       NSString *categoryHint,
                                       NSString *userText,
                                       NSString *groundingContext,
                                       BOOL hasAuthoritativeEvidence,
                                       BOOL hasImage,
                                       NSString *sessionSummary,
                                       NSString *recentChatContext,
                                       NSString *lastVisualContext) {
    (void)powerMode;
    (void)categoryHint;
    (void)hasAuthoritativeEvidence;
    (void)hasImage;
    NSMutableArray<NSString *> *sections = [NSMutableArray array];
    [sections addObject:[NSString stringWithFormat:@"LANGUAGE:\n%@", BeaconLanguageDirective(locale)]];
    [sections addObject:[NSString stringWithFormat:@"OUTPUT_LANGUAGE:\n%@", BeaconOutputLanguageReminder(locale)]];
    NSString *safeSessionSummary = BeaconNormalizedPromptBlock(sessionSummary, kBeaconMaxRollingSummaryChars);
    if (safeSessionSummary.length > 0) {
        [sections addObject:[NSString stringWithFormat:@"SESSION_SUMMARY:\n%@", safeSessionSummary]];
    }
    NSString *safeRecentChatContext = BeaconNormalizedPromptBlock(recentChatContext, kBeaconMaxRecentChatContextChars);
    if (safeRecentChatContext.length > 0) {
        [sections addObject:[NSString stringWithFormat:@"RECENT_CHAT_CONTEXT:\n%@", safeRecentChatContext]];
    }
    NSString *safeLastVisualContext = BeaconNormalizedPromptBlock(lastVisualContext, kBeaconMaxLastVisualContextChars);
    if (safeLastVisualContext.length > 0) {
        [sections addObject:[NSString stringWithFormat:@"LAST_VISUAL_CONTEXT:\n%@", safeLastVisualContext]];
    }
    NSString *incident = BeaconTruncatedPreview(BeaconTrimmedString(userText ?: @""), 260);
    [sections addObject:[NSString stringWithFormat:@"USER_INPUT:\n%@", incident]];
    NSString *compactGrounding = BeaconCompactGroundingContext(groundingContext);
    NSString *knowledgeBase = compactGrounding.length > 0 ? compactGrounding : @"(none)";
    [sections addObject:[NSString stringWithFormat:@"KNOWLEDGE_BASE:\n%@", knowledgeBase]];
    return [sections componentsJoinedByString:@"\n"];
}

@interface BeaconSessionMemoryTurn : NSObject
@property(nonatomic, copy, readonly) NSString *userText;
@property(nonatomic, copy, readonly) NSString *assistantText;
- (instancetype)initWithUserText:(NSString *)userText assistantText:(NSString *)assistantText;
@end

@implementation BeaconSessionMemoryTurn
- (instancetype)initWithUserText:(NSString *)userText assistantText:(NSString *)assistantText {
    self = [super init];
    if (self != nil) {
        _userText = [userText copy] ?: @"";
        _assistantText = [assistantText copy] ?: @"";
    }
    return self;
}
@end

@interface BeaconSessionMemory : NSObject
@property(nonatomic, copy, readonly) NSString *sessionId;
@property(nonatomic, copy, readonly) NSString *modelId;
@property(nonatomic, copy, readonly) NSString *rollingSummary;
@property(nonatomic, copy, readonly) NSArray<BeaconSessionMemoryTurn *> *recentTurns;
@property(nonatomic, copy, readonly) NSString *lastVisualContext;
- (instancetype)initWithSessionId:(NSString *)sessionId
                          modelId:(NSString *)modelId
                   rollingSummary:(NSString *)rollingSummary
                      recentTurns:(NSArray<BeaconSessionMemoryTurn *> *)recentTurns
                lastVisualContext:(NSString *)lastVisualContext;
@end

@implementation BeaconSessionMemory
- (instancetype)initWithSessionId:(NSString *)sessionId
                          modelId:(NSString *)modelId
                   rollingSummary:(NSString *)rollingSummary
                      recentTurns:(NSArray<BeaconSessionMemoryTurn *> *)recentTurns
                lastVisualContext:(NSString *)lastVisualContext {
    self = [super init];
    if (self != nil) {
        _sessionId = [sessionId copy] ?: @"default-session";
        _modelId = [modelId copy] ?: @"";
        _rollingSummary = [rollingSummary copy] ?: @"";
        _recentTurns = [recentTurns copy] ?: @[];
        _lastVisualContext = [lastVisualContext copy];
    }
    return self;
}
@end

static NSString *BeaconCollapsedWhitespace(NSString *value) {
    NSString *trimmed = BeaconTrimmedString(value ?: @"");
    if (trimmed.length == 0) {
        return @"";
    }

    NSMutableArray<NSString *> *segments = [NSMutableArray array];
    [trimmed enumerateSubstringsInRange:NSMakeRange(0, trimmed.length)
                                options:NSStringEnumerationByWords
                             usingBlock:^(NSString *substring, __unused NSRange substringRange, __unused NSRange enclosingRange, BOOL *stop) {
        (void)stop;
        if (substring.length > 0) {
            [segments addObject:substring];
        }
    }];
    return [segments componentsJoinedByString:@" "];
}

static NSString *BeaconTruncateCollapsed(NSString *value, NSUInteger limit) {
    NSString *collapsed = BeaconCollapsedWhitespace(value ?: @"");
    if (collapsed.length <= limit) {
        return collapsed;
    }
    return [[[collapsed substringToIndex:limit] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] stringByAppendingString:@"..."];
}

static NSString *BeaconTruncateTailPreservingRecent(NSString *value, NSUInteger limit) {
    NSString *collapsed = BeaconCollapsedWhitespace(value ?: @"");
    if (collapsed.length <= limit) {
        return collapsed;
    }
    if (limit <= 3) {
        return [collapsed substringFromIndex:(collapsed.length - limit)];
    }
    NSString *suffix = [[collapsed substringFromIndex:(collapsed.length - (limit - 3))] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    return [@"..." stringByAppendingString:suffix];
}

static NSString *BeaconRememberedUserText(NSString *categoryHint, NSString *userText, BOOL visualTurn) {
    NSString *normalizedUserText = BeaconTruncateCollapsed(userText, kBeaconMaxRememberedUserTurnChars);
    if (normalizedUserText.length > 0) {
        return normalizedUserText;
    }
    NSString *normalizedCategory = BeaconTruncateCollapsed(categoryHint, kBeaconMaxRememberedUserTurnChars);
    if (normalizedCategory.length > 0) {
        return normalizedCategory;
    }
    if (visualTurn) {
        return @"Visual analysis request.";
    }
    return @"";
}

static NSString *BeaconRememberedAssistantText(NSString *responseText) {
    return BeaconTruncateCollapsed(responseText, kBeaconMaxRememberedAssistantTurnChars);
}

static NSString *BeaconVisualContextFromResponse(NSString *responseText) {
    NSString *normalized = [responseText ?: @"" stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
    NSArray<NSString *> *rawLines = [normalized componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    for (NSString *rawLine in rawLines) {
        NSString *line = BeaconCollapsedWhitespace(rawLine);
        if (line.length == 0) {
            continue;
        }
        [lines addObject:line];
        if (lines.count >= 3) {
            break;
        }
    }
    if (lines.count == 0) {
        return nil;
    }
    return BeaconTruncateCollapsed([lines componentsJoinedByString:@" "], kBeaconMaxLastVisualContextChars);
}

static NSString *BeaconMergedRollingSummary(NSString *existingSummary, NSArray<BeaconSessionMemoryTurn *> *overflowTurns) {
    NSString *merged = BeaconTruncateTailPreservingRecent(existingSummary, kBeaconMaxRollingSummaryChars);
    for (BeaconSessionMemoryTurn *turn in overflowTurns) {
        NSMutableArray<NSString *> *parts = [NSMutableArray array];
        if (turn.userText.length > 0) {
            [parts addObject:[NSString stringWithFormat:@"User: %@", turn.userText]];
        }
        if (turn.assistantText.length > 0) {
            [parts addObject:[NSString stringWithFormat:@"Beacon: %@", turn.assistantText]];
        }
        NSString *segment = [parts componentsJoinedByString:@" "];
        if (segment.length == 0) {
            continue;
        }
        merged = merged.length > 0 ? [NSString stringWithFormat:@"%@ %@", merged, segment] : segment;
        merged = BeaconTruncateTailPreservingRecent(merged, kBeaconMaxRollingSummaryChars);
    }
    return merged;
}

static NSString *BeaconRenderedRecentChatContext(NSArray<BeaconSessionMemoryTurn *> *turns) {
    if (turns.count == 0) {
        return nil;
    }

    NSArray<BeaconSessionMemoryTurn *> *recentTurns = turns.count > kBeaconRecentMemoryTurns
        ? [turns subarrayWithRange:NSMakeRange(turns.count - kBeaconRecentMemoryTurns, kBeaconRecentMemoryTurns)]
        : turns;
    NSMutableArray<NSString *> *rendered = [NSMutableArray arrayWithCapacity:recentTurns.count];
    [recentTurns enumerateObjectsUsingBlock:^(BeaconSessionMemoryTurn *turn, NSUInteger idx, __unused BOOL *stop) {
        [rendered addObject:[NSString stringWithFormat:@"U%lu: %@\nB%lu: %@",
                             (unsigned long)(idx + 1),
                             turn.userText ?: @"",
                             (unsigned long)(idx + 1),
                             turn.assistantText ?: @""]];
    }];

    NSMutableArray<NSString *> *kept = [NSMutableArray array];
    NSUInteger usedChars = 0;
    for (NSString *segment in [rendered reverseObjectEnumerator]) {
        NSUInteger segmentChars = segment.length + (kept.count == 0 ? 0 : 1);
        if ((usedChars + segmentChars) > kBeaconMaxRecentChatContextChars && kept.count > 0) {
            break;
        }
        if (segmentChars > kBeaconMaxRecentChatContextChars && kept.count == 0) {
            return BeaconTruncateTailPreservingRecent(segment, kBeaconMaxRecentChatContextChars);
        }
        [kept insertObject:segment atIndex:0];
        usedChars += segmentChars;
    }

    NSString *joined = [kept componentsJoinedByString:@"\n"];
    return joined.length > 0 ? joined : nil;
}

static NSString *BeaconJSONString(id object) {
    if (![NSJSONSerialization isValidJSONObject:object]) {
        return nil;
    }
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:object options:0 error:&error];
    if (data == nil || error != nil) {
        return nil;
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

static NSString *BeaconExtractTextFromContent(id content) {
    if ([content isKindOfClass:[NSString class]]) {
        return content;
    }
    if ([content isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = (NSDictionary *)content;
        id directText = dictionary[@"text"];
        if ([directText isKindOfClass:[NSString class]]) {
            return directText;
        }
        id nestedContent = dictionary[@"content"];
        if (nestedContent != nil) {
            return BeaconExtractTextFromContent(nestedContent);
        }
        NSMutableArray<NSString *> *segments = [NSMutableArray array];
        for (id value in [dictionary allValues]) {
            NSString *segment = BeaconExtractTextFromContent(value);
            if (segment.length > 0) {
                [segments addObject:segment];
            }
        }
        return [segments componentsJoinedByString:@"\n"];
    }
    if ([content isKindOfClass:[NSArray class]]) {
        NSMutableArray<NSString *> *segments = [NSMutableArray array];
        for (id value in (NSArray *)content) {
            NSString *segment = BeaconExtractTextFromContent(value);
            if (segment.length > 0) {
                [segments addObject:segment];
            }
        }
        return [segments componentsJoinedByString:@"\n"];
    }
    return @"";
}

static NSString *BeaconExtractResponseText(NSString *jsonString) {
    if (jsonString.length == 0) {
        return @"";
    }
    NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    if (data == nil) {
        return jsonString;
    }
    NSError *error = nil;
    id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (parsed == nil || error != nil) {
        return jsonString;
    }
    NSString *content = BeaconExtractTextFromContent(parsed);
    return content ?: @"";
}

@protocol BeaconNativeStreamHandling <NSObject>
- (void)emitTriageStreamPayload:(NSDictionary *)payload;
- (void)finishTriageStreamWithId:(NSString *)streamId
                       sessionId:(NSString *)sessionId
                        modelId:(NSString *)modelId
                    categoryHint:(NSString *)categoryHint
                        userText:(NSString *)userText
                    isVisualTurn:(BOOL)isVisualTurn
                       finalText:(NSString *)finalText
                    errorMessage:(NSString *)errorMessage
                       startedAt:(CFAbsoluteTime)startedAt;
@end

@interface BeaconNativeStreamContext : NSObject
@property(nonatomic, strong, readonly) id<BeaconNativeStreamHandling> plugin;
@property(nonatomic, copy, readonly) NSString *streamId;
@property(nonatomic, copy, readonly) NSString *sessionId;
@property(nonatomic, copy, readonly) NSString *modelId;
@property(nonatomic, copy, readonly) NSString *categoryHint;
@property(nonatomic, copy, readonly) NSString *userText;
@property(nonatomic, assign, readonly) BOOL isVisualTurn;
@property(nonatomic, assign, readonly) CFAbsoluteTime startedAt;
- (instancetype)initWithPlugin:(id<BeaconNativeStreamHandling>)plugin
                      streamId:(NSString *)streamId
                     sessionId:(NSString *)sessionId
                       modelId:(NSString *)modelId
                   categoryHint:(NSString *)categoryHint
                       userText:(NSString *)userText
                   isVisualTurn:(BOOL)isVisualTurn
                     startedAt:(CFAbsoluteTime)startedAt;
- (void)consumeChunkJSON:(NSString *)chunkJSON isFinal:(BOOL)isFinal errorMessage:(NSString *)errorMessage;
@end

@implementation BeaconNativeStreamContext {
    NSMutableString *_accumulatedText;
}

- (instancetype)initWithPlugin:(id<BeaconNativeStreamHandling>)plugin
                      streamId:(NSString *)streamId
                     sessionId:(NSString *)sessionId
                       modelId:(NSString *)modelId
                   categoryHint:(NSString *)categoryHint
                       userText:(NSString *)userText
                   isVisualTurn:(BOOL)isVisualTurn
                     startedAt:(CFAbsoluteTime)startedAt {
    self = [super init];
    if (self != nil) {
        _plugin = plugin;
        _streamId = [streamId copy] ?: [[NSUUID UUID] UUIDString];
        _sessionId = [sessionId copy] ?: @"default-session";
        _modelId = [modelId copy] ?: @"";
        _categoryHint = [categoryHint copy];
        _userText = [userText copy] ?: @"";
        _isVisualTurn = isVisualTurn;
        _startedAt = startedAt;
        _accumulatedText = [NSMutableString new];
    }
    return self;
}

- (void)consumeChunkJSON:(NSString *)chunkJSON isFinal:(BOOL)isFinal errorMessage:(NSString *)errorMessage {
    NSString *delta = BeaconSanitizeModelText(BeaconExtractResponseText(chunkJSON ?: @""));
    if (delta.length > 0) {
        @synchronized (self) {
            [_accumulatedText appendString:delta];
        }
        [self.plugin emitTriageStreamPayload:@{
            @"streamId": self.streamId,
            @"delta": delta
        }];
    }

    if (!isFinal) {
        return;
    }

    NSString *finalText = nil;
    @synchronized (self) {
        finalText = [_accumulatedText copy];
    }
    [self.plugin finishTriageStreamWithId:self.streamId
                                sessionId:self.sessionId
                                  modelId:self.modelId
                              categoryHint:self.categoryHint
                                  userText:self.userText
                              isVisualTurn:self.isVisualTurn
                                finalText:BeaconSanitizeModelText(finalText ?: @"")
                             errorMessage:errorMessage
                                startedAt:self.startedAt];
}

@end

@interface BeaconNativeBlockingStreamContext : NSObject
- (void)consumeChunkJSON:(NSString *)chunkJSON isFinal:(BOOL)isFinal errorMessage:(NSString *)errorMessage;
- (BOOL)waitForCompletionWithTimeout:(NSTimeInterval)timeout;
- (NSString *)accumulatedText;
- (NSString *)finalError;
@end

@implementation BeaconNativeBlockingStreamContext {
    NSMutableString *_accumulatedText;
    dispatch_semaphore_t _doneSemaphore;
    NSString *_finalError;
}

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _accumulatedText = [NSMutableString new];
        _doneSemaphore = dispatch_semaphore_create(0);
    }
    return self;
}

- (void)consumeChunkJSON:(NSString *)chunkJSON isFinal:(BOOL)isFinal errorMessage:(NSString *)errorMessage {
    NSString *delta = BeaconSanitizeModelText(BeaconExtractResponseText(chunkJSON ?: @""));
    if (delta.length > 0) {
        @synchronized (self) {
            [_accumulatedText appendString:delta];
        }
    }

    if (!isFinal) {
        return;
    }

    @synchronized (self) {
        _finalError = [BeaconTrimmedString(errorMessage ?: @"") copy];
    }
    dispatch_semaphore_signal(_doneSemaphore);
}

- (BOOL)waitForCompletionWithTimeout:(NSTimeInterval)timeout {
    return dispatch_semaphore_wait(_doneSemaphore,
                                   dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC))) == 0;
}

- (NSString *)accumulatedText {
    @synchronized (self) {
        return [_accumulatedText copy];
    }
}

- (NSString *)finalError {
    @synchronized (self) {
        return [_finalError copy] ?: @"";
    }
}

@end

static void BeaconNativeTriageStreamCallback(void *callbackData,
                                             const char *chunk,
                                             bool isFinal,
                                             const char *errorMessage) {
    BeaconNativeStreamContext *context = (__bridge BeaconNativeStreamContext *)callbackData;
    NSString *chunkJSON = chunk != NULL ? [NSString stringWithUTF8String:chunk] : @"";
    NSString *errorText = errorMessage != NULL ? [NSString stringWithUTF8String:errorMessage] : nil;
    [context consumeChunkJSON:chunkJSON isFinal:isFinal errorMessage:errorText];
    if (isFinal) {
        CFBridgingRelease(callbackData);
    }
}

static void BeaconNativeBlockingStreamCallback(void *callbackData,
                                               const char *chunk,
                                               bool isFinal,
                                               const char *errorMessage) {
    BeaconNativeBlockingStreamContext *context = (__bridge BeaconNativeBlockingStreamContext *)callbackData;
    NSString *chunkJSON = chunk != NULL ? [NSString stringWithUTF8String:chunk] : @"";
    NSString *errorText = errorMessage != NULL ? [NSString stringWithUTF8String:errorMessage] : nil;
    [context consumeChunkJSON:chunkJSON isFinal:isFinal errorMessage:errorText];
    if (isFinal) {
        CFBridgingRelease(callbackData);
    }
}

static NSDictionary *BeaconFallbackModelSpec(void) {
    return @{
        @"id": @"gemma-4-e2b",
        @"tier": @"e2b",
        @"name": @"Gemma 4 E2B",
        @"fileName": @"gemma-4-E2B-it.litertlm",
        @"sizeLabel": @"2B / Survival Baseline",
        @"downloadUrl": @"",
        @"sizeInBytes": @(2583085056LL),
        @"defaultProfileName": @"gemma-4-e2b-balanced",
        @"recommendedFor": @"Default offline triage on most phones.",
        @"supportsImageInput": @YES,
        @"supportsVision": @YES,
        @"artifactFormat": kBeaconArtifactFormatLiteRtLm,
        @"runtimeStack": kBeaconRuntimeStackLiteRtLmCApi,
        @"minCapabilityClass": @"ios-6gb-plus",
        @"preferredBackend": kBeaconPreferredBackendAutoReal,
        @"accelerators": @[ @"gpu", @"cpu" ]
    };
}

@interface BeaconNativePlugin : CAPPlugin <CAPBridgedPlugin, BeaconNativeStreamHandling>
+ (void)kickOffLaunchSmokeTestIfRequested;
@end

@implementation BeaconNativePlugin {
    dispatch_queue_t _workerQueue;
    NSArray<NSDictionary *> *_modelCatalog;
    NSString *_loadedModelId;
    NSString *_activeSessionId;
    NSString *_activeConversationModelId;
    NSString *_activeConversationPowerMode;
    NSString *_activeBackend;
    NSString *_activeVisionBackend;
    NSString *_activeEngineAttempt;
    NSArray<NSString *> *_lastEngineAttemptLog;
    NSDictionary *_lastBenchmarkSummary;
    NSString *_lastEngineFailureMessage;
    NSString *_lastGpuFailureMessage;
    BOOL _gpuAttemptedDuringLastLoad;
    BOOL _gpuFallbackToCpuDuringLastLoad;
    BOOL _loadedEngineRequiresVision;
    BOOL _activeConversationRequiresVision;
    NSDictionary *_lastRuntimeAudit;
    BeaconSessionMemory *_sessionMemory;
    LiteRtLmEngine *_engine;
    LiteRtLmConversation *_conversation;
    BOOL _didScheduleSmokeTest;
    NSError *_cachedEngineLoadFailure;
    NSString *_cachedEngineLoadFailureModelId;
    NSTimeInterval _cachedEngineLoadFailureAt;
}

+ (void)load {
    if (!BeaconSmokeTestRequested()) {
        return;
    }

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(__unused NSNotification *note) {
        [BeaconNativePlugin kickOffLaunchSmokeTestIfRequested];
    }];
}

- (NSString *)identifier {
    return @"BeaconNativePlugin";
}

- (NSString *)jsName {
    return @"BeaconNative";
}

- (NSArray<CAPPluginMethod *> *)pluginMethods {
    NSMutableArray<CAPPluginMethod *> *methods = [NSMutableArray new];
    CAP_PLUGIN_METHOD(listModels, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(loadModel, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(downloadModel, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(triage, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(triageStream, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(cancelActiveInference, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(analyzeVisual, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(getRuntimeDiagnostics, CAPPluginReturnPromise);
    return methods;
}

- (void)dealloc {
    if (_conversation != NULL) {
        litert_lm_conversation_delete(_conversation);
        _conversation = NULL;
        _activeConversationRequiresVision = NO;
    }
    if (_engine != NULL) {
        litert_lm_engine_delete(_engine);
        _engine = NULL;
        _loadedEngineRequiresVision = NO;
    }
}

- (void)load {
    [self bootstrapStateIfNeeded];
    BeaconNativeLog(@"plugin loaded; catalog=%lu storedModelId=%@", (unsigned long)_modelCatalog.count, _loadedModelId ?: @"(none)");
    [self maybeScheduleSmokeTest];
}

+ (void)kickOffLaunchSmokeTestIfRequested {
    if (!BeaconSmokeTestRequested() || !BeaconClaimSmokeRun()) {
        return;
    }

    BeaconWriteSmokeProgress(@"launch-kickoff-claimed", @{
        @"traceToken": BeaconSmokeTraceToken() ?: @""
    });
    BeaconNativePlugin *runner = [BeaconNativePlugin new];
    gBeaconStandaloneSmokeRunner = runner;
    [runner bootstrapStateIfNeeded];
    BeaconNativeLog(@"launch smoke harness claimed at native app entry");
    dispatch_async(runner->_workerQueue, ^{
        BeaconWriteSmokeProgress(@"launch-kickoff-dispatch-entered", @{
            @"traceToken": BeaconSmokeTraceToken() ?: @""
        });
        [runner runSmokeTests];
        gBeaconStandaloneSmokeRunner = nil;
    });
}

- (void)bootstrapStateIfNeeded {
    if (_workerQueue == nil) {
        _workerQueue = dispatch_queue_create("com.beacon.sos.native", DISPATCH_QUEUE_SERIAL);
    }
    if (_modelCatalog == nil) {
        _modelCatalog = [self loadModelCatalog];
    }
    if (_loadedModelId.length == 0) {
        _loadedModelId = [[NSUserDefaults standardUserDefaults] stringForKey:kBeaconLoadedModelIdKey];
    }
}

- (NSArray<NSDictionary *> *)loadModelCatalog {
    NSURL *allowlistURL = [[NSBundle mainBundle] URLForResource:@"model_allowlist" withExtension:@"json" subdirectory:@"public"];
    if (allowlistURL == nil) {
        return @[ BeaconFallbackModelSpec() ];
    }

    NSData *data = [NSData dataWithContentsOfURL:allowlistURL];
    if (data == nil) {
        return @[ BeaconFallbackModelSpec() ];
    }

    NSError *error = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    NSArray *models = error == nil ? json[@"models"] : nil;
    if (![models isKindOfClass:[NSArray class]]) {
        return @[ BeaconFallbackModelSpec() ];
    }

    NSMutableArray<NSDictionary *> *filtered = [NSMutableArray array];
    for (id entry in models) {
        if (![entry isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *dictionary = (NSDictionary *)entry;
        if ([dictionary[@"id"] isEqual:kBeaconDefaultModelId]) {
            [filtered addObject:dictionary];
        }
    }

    return filtered.count > 0 ? filtered : @[ BeaconFallbackModelSpec() ];
}

- (NSDictionary *)modelSpecForId:(NSString *)modelId {
    for (NSDictionary *spec in _modelCatalog) {
        if ([spec[@"id"] isEqualToString:modelId]) {
            return spec;
        }
    }
    return nil;
}

- (NSURL *)modelsDirectoryURLCreatingIfNeeded:(BOOL)create {
    NSURL *appSupport = [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] firstObject];
    NSURL *directory = [appSupport URLByAppendingPathComponent:@"models" isDirectory:YES];
    if (create) {
        [[NSFileManager defaultManager] createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return directory;
}

- (NSURL *)downloadedModelURLForSpec:(NSDictionary *)spec creatingParentIfNeeded:(BOOL)create {
    NSString *fileName = spec[@"fileName"] ?: @"";
    return [[self modelsDirectoryURLCreatingIfNeeded:create] URLByAppendingPathComponent:fileName isDirectory:NO];
}

- (NSURL *)bundledModelURLForSpec:(NSDictionary *)spec {
    NSString *fileName = spec[@"fileName"] ?: @"";
    NSString *baseName = [fileName stringByDeletingPathExtension];
    NSString *extension = [fileName pathExtension];
    return [[NSBundle mainBundle] URLForResource:baseName withExtension:extension subdirectory:@"models"];
}

- (NSURL *)resolvedModelURLForSpec:(NSDictionary *)spec {
    NSURL *downloaded = [self downloadedModelURLForSpec:spec creatingParentIfNeeded:NO];
    if (downloaded != nil && [[NSFileManager defaultManager] fileExistsAtPath:downloaded.path]) {
        return downloaded;
    }
    NSURL *bundled = [self bundledModelURLForSpec:spec];
    if (bundled != nil && [[NSFileManager defaultManager] fileExistsAtPath:bundled.path]) {
        return bundled;
    }
    return nil;
}

- (NSString *)defaultAvailableModelId {
    for (NSDictionary *spec in _modelCatalog) {
        if ([self resolvedModelURLForSpec:spec] != nil) {
            return spec[@"id"];
        }
    }
    return nil;
}

- (NSString *)capabilityStorageSuffixForModelId:(NSString *)modelId {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    NSString *deviceName = device.name.length > 0 ? device.name : @"unknown-gpu";
    NSString *systemVersion = UIDevice.currentDevice.systemVersion.length > 0 ? UIDevice.currentDevice.systemVersion : @"unknown-ios";
    return [NSString stringWithFormat:@"%@|%@|%llu|%@",
            modelId ?: @"unknown-model",
            deviceName,
            [NSProcessInfo processInfo].physicalMemory,
            systemVersion];
}

- (NSString *)preferredBackendDefaultsKeyForModelId:(NSString *)modelId {
    return [kBeaconPreferredBackendKeyPrefix stringByAppendingString:[self capabilityStorageSuffixForModelId:modelId]];
}

- (NSString *)gpuBlockedReasonDefaultsKeyForModelId:(NSString *)modelId {
    return [kBeaconGpuBlockedReasonKeyPrefix stringByAppendingString:[self capabilityStorageSuffixForModelId:modelId]];
}

- (NSString *)gpuWarmupAttemptedDefaultsKeyForModelId:(NSString *)modelId {
    return [kBeaconGpuWarmupAttemptedKeyPrefix stringByAppendingString:[self capabilityStorageSuffixForModelId:modelId]];
}

- (NSDictionary *)capabilitySnapshotForSpec:(NSDictionary *)spec {
    return BeaconCapabilitySnapshotForSpec(spec ?: @{});
}

- (NSString *)persistedPreferredBackendForModelId:(NSString *)modelId {
    NSString *value = [[NSUserDefaults standardUserDefaults] stringForKey:[self preferredBackendDefaultsKeyForModelId:modelId]];
    return value.length > 0 ? value : nil;
}

- (NSString *)persistedGpuBlockedReasonForModelId:(NSString *)modelId {
    NSString *value = [[NSUserDefaults standardUserDefaults] stringForKey:[self gpuBlockedReasonDefaultsKeyForModelId:modelId]];
    return value.length > 0 ? value : nil;
}

- (BOOL)gpuWarmupAttemptedForModelId:(NSString *)modelId {
    return [[NSUserDefaults standardUserDefaults] boolForKey:[self gpuWarmupAttemptedDefaultsKeyForModelId:modelId]];
}

- (NSString *)effectivePreferredBackendForModelId:(NSString *)modelId spec:(NSDictionary *)spec capability:(NSDictionary *)capability {
    BOOL gpuEligible = [capability[@"gpuEligible"] respondsToSelector:@selector(boolValue)] ? [capability[@"gpuEligible"] boolValue] : NO;
    if (!gpuEligible) {
        return @"cpu";
    }
    NSString *persisted = [self persistedPreferredBackendForModelId:modelId];
    if (persisted.length > 0) {
        return persisted;
    }
    return [BeaconPreferredBackendDirectiveForSpec(spec) isEqualToString:kBeaconPreferredBackendAutoReal]
        ? kBeaconPreferredBackendAutoReal
        : @"cpu";
}

- (void)recordBackendPreferenceForModelId:(NSString *)modelId backend:(NSString *)backend gpuAttempted:(BOOL)gpuAttempted failureReason:(NSString *)failureReason {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:gpuAttempted forKey:[self gpuWarmupAttemptedDefaultsKeyForModelId:modelId]];
    if (backend.length > 0) {
        [defaults setObject:backend forKey:[self preferredBackendDefaultsKeyForModelId:modelId]];
    }
    if (failureReason.length > 0) {
        [defaults setObject:failureReason forKey:[self gpuBlockedReasonDefaultsKeyForModelId:modelId]];
    } else {
        [defaults removeObjectForKey:[self gpuBlockedReasonDefaultsKeyForModelId:modelId]];
    }
}

- (NSArray<NSDictionary *> *)buildModelArray {
    NSMutableArray<NSDictionary *> *models = [NSMutableArray array];
    for (NSDictionary *spec in _modelCatalog) {
        NSURL *resolvedURL = [self resolvedModelURLForSpec:spec];
        NSDictionary *capability = [self capabilitySnapshotForSpec:spec];
        NSArray *accelerators = [spec[@"accelerators"] isKindOfClass:[NSArray class]] ? spec[@"accelerators"] : @[ @"cpu" ];
        NSString *localPath = resolvedURL != nil ? resolvedURL.path : [[self downloadedModelURLForSpec:spec creatingParentIfNeeded:NO] path];
        BOOL isLoaded = (_engine != NULL && [_loadedModelId isEqualToString:spec[@"id"]]);
        NSString *acceleratorFamily = [_activeBackend isEqualToString:@"gpu"] ? @"metal" : ([_activeBackend isEqualToString:@"cpu"] ? @"cpu" : @"unknown");
        [models addObject:@{
            @"id": spec[@"id"] ?: @"",
            @"tier": spec[@"tier"] ?: @"e2b",
            @"name": spec[@"name"] ?: @"Gemma 4",
            @"localPath": localPath ?: @"",
            @"sizeLabel": spec[@"sizeLabel"] ?: @"",
            @"sizeBytes": spec[@"sizeInBytes"] ?: @(0),
            @"defaultProfileName": spec[@"defaultProfileName"] ?: @"",
            @"recommendedFor": spec[@"recommendedFor"] ?: @"",
            @"supportsImageInput": spec[@"supportsImageInput"] ?: @NO,
            @"supportsVision": spec[@"supportsVision"] ?: spec[@"supportsImageInput"] ?: @NO,
            @"acceleratorHints": accelerators,
            @"isLoaded": @(isLoaded),
            @"isDownloaded": @(resolvedURL != nil),
            @"activeBackend": isLoaded ? (_activeBackend ?: @"") : @"",
            @"activeVisionBackend": isLoaded ? (_activeVisionBackend ?: @"") : @"",
            @"acceleratorFamily": isLoaded ? acceleratorFamily : @"unknown",
            @"downloadStatus": resolvedURL != nil ? @"succeeded" : @"not_downloaded",
            @"artifactFormat": BeaconArtifactFormatForSpec(spec),
            @"runtimeStack": BeaconRuntimeStackForSpec(spec),
            @"minCapabilityClass": spec[@"minCapabilityClass"] ?: @"ios-6gb-plus",
            @"preferredBackend": BeaconPreferredBackendDirectiveForSpec(spec),
            @"capabilityClass": capability[@"capabilityClass"] ?: @"unknown",
            @"supportedDeviceClass": capability[@"supportedDeviceClass"] ?: @"unknown"
        }];
    }
    return models;
}

- (NSDictionary *)benchmarkSummaryForConversation:(LiteRtLmConversation *)conversation {
    if (conversation == NULL) {
        return nil;
    }
    LiteRtLmBenchmarkInfo *benchmarkInfo = litert_lm_conversation_get_benchmark_info(conversation);
    if (benchmarkInfo == NULL) {
        return nil;
    }
    NSDictionary *summary = @{
        @"totalInitMs": @(litert_lm_benchmark_info_get_total_init_time_in_second(benchmarkInfo) * 1000.0),
        @"timeToFirstTokenMs": @(litert_lm_benchmark_info_get_time_to_first_token(benchmarkInfo) * 1000.0),
        @"lastPrefillTokenCount": @(litert_lm_benchmark_info_get_num_prefill_turns(benchmarkInfo) > 0 ? litert_lm_benchmark_info_get_prefill_token_count_at(benchmarkInfo, litert_lm_benchmark_info_get_num_prefill_turns(benchmarkInfo) - 1) : 0),
        @"lastDecodeTokenCount": @(litert_lm_benchmark_info_get_num_decode_turns(benchmarkInfo) > 0 ? litert_lm_benchmark_info_get_decode_token_count_at(benchmarkInfo, litert_lm_benchmark_info_get_num_decode_turns(benchmarkInfo) - 1) : 0),
        @"lastPrefillTokensPerSecond": @(litert_lm_benchmark_info_get_num_prefill_turns(benchmarkInfo) > 0 ? litert_lm_benchmark_info_get_prefill_tokens_per_sec_at(benchmarkInfo, litert_lm_benchmark_info_get_num_prefill_turns(benchmarkInfo) - 1) : 0.0),
        @"lastDecodeTokensPerSecond": @(litert_lm_benchmark_info_get_num_decode_turns(benchmarkInfo) > 0 ? litert_lm_benchmark_info_get_decode_tokens_per_sec_at(benchmarkInfo, litert_lm_benchmark_info_get_num_decode_turns(benchmarkInfo) - 1) : 0.0)
    };
    litert_lm_benchmark_info_delete(benchmarkInfo);
    return summary;
}

- (void)clearSessionMemoryIfNeededForSessionId:(NSString *)sessionId resetContext:(BOOL)resetContext {
    @synchronized (self) {
        if (resetContext) {
            _sessionMemory = nil;
            return;
        }
        if (_sessionMemory != nil && ![_sessionMemory.sessionId isEqualToString:(sessionId ?: @"default-session")]) {
            _sessionMemory = nil;
        }
    }
}

- (NSDictionary<NSString *, NSString *> *)promptMemoryForSessionId:(NSString *)sessionId resetContext:(BOOL)resetContext {
    [self clearSessionMemoryIfNeededForSessionId:sessionId resetContext:resetContext];
    @synchronized (self) {
        if (_sessionMemory == nil || ![_sessionMemory.sessionId isEqualToString:(sessionId ?: @"default-session")]) {
            return @{};
        }
        NSMutableDictionary<NSString *, NSString *> *memory = [NSMutableDictionary dictionary];
        NSString *sessionSummary = BeaconTruncateTailPreservingRecent(_sessionMemory.rollingSummary, kBeaconMaxRollingSummaryChars);
        if (sessionSummary.length > 0) {
            memory[@"sessionSummary"] = sessionSummary;
        }
        NSString *recentChatContext = BeaconRenderedRecentChatContext(_sessionMemory.recentTurns);
        if (recentChatContext.length > 0) {
            memory[@"recentChatContext"] = recentChatContext;
        }
        NSString *lastVisualContext = BeaconTruncateCollapsed(_sessionMemory.lastVisualContext, kBeaconMaxLastVisualContextChars);
        if (lastVisualContext.length > 0) {
            memory[@"lastVisualContext"] = lastVisualContext;
        }
        return memory;
    }
}

- (void)rememberSessionMemoryForSessionId:(NSString *)sessionId
                                  modelId:(NSString *)modelId
                             categoryHint:(NSString *)categoryHint
                                 userText:(NSString *)userText
                             responseText:(NSString *)responseText
                             isVisualTurn:(BOOL)isVisualTurn {
    NSString *safeSessionId = sessionId ?: @"default-session";
    NSString *rememberedUserText = BeaconRememberedUserText(categoryHint, userText, isVisualTurn);
    NSString *rememberedAssistantText = BeaconRememberedAssistantText(responseText);
    if (rememberedUserText.length == 0 || rememberedAssistantText.length == 0) {
        return;
    }

    @synchronized (self) {
        BeaconSessionMemory *baseMemory = _sessionMemory;
        if (baseMemory == nil || ![baseMemory.sessionId isEqualToString:safeSessionId]) {
            baseMemory = [[BeaconSessionMemory alloc] initWithSessionId:safeSessionId
                                                                modelId:modelId ?: @""
                                                         rollingSummary:@""
                                                            recentTurns:@[]
                                                      lastVisualContext:nil];
        }

        NSMutableArray<BeaconSessionMemoryTurn *> *combinedTurns = [baseMemory.recentTurns mutableCopy] ?: [NSMutableArray array];
        [combinedTurns addObject:[[BeaconSessionMemoryTurn alloc] initWithUserText:rememberedUserText
                                                                     assistantText:rememberedAssistantText]];

        NSArray<BeaconSessionMemoryTurn *> *overflowTurns = @[];
        if (combinedTurns.count > kBeaconRecentMemoryTurns) {
            overflowTurns = [combinedTurns subarrayWithRange:NSMakeRange(0, combinedTurns.count - kBeaconRecentMemoryTurns)];
            [combinedTurns removeObjectsInRange:NSMakeRange(0, combinedTurns.count - kBeaconRecentMemoryTurns)];
        }

        NSString *updatedSummary = BeaconMergedRollingSummary(baseMemory.rollingSummary, overflowTurns);
        NSString *updatedVisualContext = isVisualTurn
            ? BeaconVisualContextFromResponse(responseText)
            : baseMemory.lastVisualContext;

        _sessionMemory = [[BeaconSessionMemory alloc] initWithSessionId:safeSessionId
                                                                modelId:modelId ?: baseMemory.modelId ?: @""
                                                         rollingSummary:updatedSummary
                                                            recentTurns:combinedTurns
                                                      lastVisualContext:updatedVisualContext];
        BeaconNativeLog(@"session memory updated session=%@ recentTurns=%lu summaryChars=%lu visual=%@",
                        safeSessionId,
                        (unsigned long)_sessionMemory.recentTurns.count,
                        (unsigned long)_sessionMemory.rollingSummary.length,
                        _sessionMemory.lastVisualContext.length > 0 ? @"yes" : @"no");
    }
}

- (NSDictionary *)runtimeDiagnosticsPayload {
    NSMutableDictionary *payload = [[BeaconMetalSnapshot() mutableCopy] ?: [NSMutableDictionary dictionary] mutableCopy];
    NSDictionary *spec = _loadedModelId.length > 0
        ? [self modelSpecForId:_loadedModelId]
        : [self modelSpecForId:([self defaultAvailableModelId] ?: kBeaconDefaultModelId)];
    if (spec == nil) {
        spec = BeaconFallbackModelSpec();
    }
    NSDictionary *capability = [self capabilitySnapshotForSpec:spec];
    NSString *capabilityClass = capability[@"capabilityClass"] ?: @"unknown";
    if (_engine == NULL && _lastEngineFailureMessage.length > 0 && [capabilityClass isEqualToString:@"supported"]) {
        capabilityClass = @"runtime_unstable";
    }
    NSString *effectivePreferredBackend = [self effectivePreferredBackendForModelId:(spec[@"id"] ?: kBeaconDefaultModelId)
                                                                               spec:spec
                                                                         capability:capability];
    BOOL gpuWarmupAttempted = [self gpuWarmupAttemptedForModelId:(spec[@"id"] ?: kBeaconDefaultModelId)];
    NSString *gpuBlockedReason = [self persistedGpuBlockedReasonForModelId:(spec[@"id"] ?: kBeaconDefaultModelId)];
    if (gpuBlockedReason.length == 0) {
        gpuBlockedReason = _lastGpuFailureMessage ?: @"";
    }
    if (gpuBlockedReason.length == 0
        && [capability[@"gpuEligible"] respondsToSelector:@selector(boolValue)]
        && ![capability[@"gpuEligible"] boolValue]
        && [capabilityClass isEqualToString:@"supported"]) {
        NSString *supportedDeviceClass = capability[@"supportedDeviceClass"] ?: @"unknown";
        if (!BeaconSupportsReleasedGpuAutoForDeviceClass(supportedDeviceClass)) {
            gpuBlockedReason = @"GPU auto mode is currently released only for verified iPhone target devices. Beacon stays on the real on-device CPU path on this device class.";
        }
    }

    payload[@"platform"] = @"ios";
    payload[@"loadedModelId"] = _loadedModelId ?: @"";
    payload[@"isLoaded"] = @(_engine != NULL && _loadedModelId.length > 0);
    payload[@"activeBackend"] = _activeBackend ?: @"unknown";
    payload[@"activeVisionBackend"] = _activeVisionBackend ?: @"";
    payload[@"acceleratorFamily"] = [_activeBackend isEqualToString:@"gpu"] ? @"metal" : ([_activeBackend isEqualToString:@"cpu"] ? @"cpu" : @"unknown");
    payload[@"lastEngineAttempt"] = _activeEngineAttempt ?: @"";
    payload[@"lastEngineFailure"] = _lastEngineFailureMessage ?: @"";
    payload[@"engineAttemptLog"] = _lastEngineAttemptLog ?: @[];
    payload[@"gpuAttempted"] = @(_gpuAttemptedDuringLastLoad);
    payload[@"gpuFallbackToCpu"] = @(_gpuFallbackToCpuDuringLastLoad);
    payload[@"gpuFailureDetail"] = _lastGpuFailureMessage ?: @"";
    payload[@"runtimeStack"] = capability[@"runtimeStack"] ?: kBeaconRuntimeStackLiteRtLmCApi;
    payload[@"artifactFormat"] = capability[@"artifactFormat"] ?: kBeaconArtifactFormatLiteRtLm;
    payload[@"capabilityClass"] = capabilityClass;
    payload[@"gpuEligible"] = capability[@"gpuEligible"] ?: @NO;
    payload[@"gpuWarmupAttempted"] = @(gpuWarmupAttempted);
    payload[@"gpuWarmupPassed"] = @(
        [_activeBackend isEqualToString:@"gpu"]
        || (gpuWarmupAttempted && [effectivePreferredBackend isEqualToString:@"gpu"])
    );
    payload[@"gpuBlockedReason"] = gpuBlockedReason ?: @"";
    payload[@"supportedDeviceClass"] = capability[@"supportedDeviceClass"] ?: @"unknown";
    payload[@"preferredBackend"] = effectivePreferredBackend ?: kBeaconPreferredBackendAutoReal;
    if (_lastRuntimeAudit != nil) {
        payload[@"bundleAudit"] = _lastRuntimeAudit;
    }
    if (_lastBenchmarkSummary != nil) {
        payload[@"benchmark"] = _lastBenchmarkSummary;
    }
    return payload;
}

- (void)rejectCall:(CAPPluginCall *)call message:(NSString *)message error:(NSError *)error {
    NSString *safeMessage = BeaconTrimmedString(message ?: @"");
    [call reject:(safeMessage.length > 0 ? safeMessage : @"Unknown Beacon native error.")
               :nil
               :error
               :nil];
}

- (void)emitTriageStreamPayload:(NSDictionary *)payload {
    NSDictionary *safePayload = payload ?: @{};
    dispatch_async(dispatch_get_main_queue(), ^{
        [self notifyListeners:kBeaconTriageStreamEventName data:safePayload];
    });
}

- (void)releaseFinishedConversationWithReason:(NSString *)reason {
    if (_conversation == NULL) {
        return;
    }
    NSString *sessionId = _activeSessionId ?: @"(none)";
    litert_lm_conversation_delete(_conversation);
    _conversation = NULL;
    _activeSessionId = nil;
    _activeConversationModelId = nil;
    _activeConversationPowerMode = nil;
    _activeConversationRequiresVision = NO;
    BeaconNativeLog(@"released finished conversation session=%@ reason=%@", sessionId, reason ?: @"unknown");
}

- (void)finishTriageStreamWithId:(NSString *)streamId
                       sessionId:(NSString *)sessionId
                         modelId:(NSString *)modelId
                     categoryHint:(NSString *)categoryHint
                         userText:(NSString *)userText
                     isVisualTurn:(BOOL)isVisualTurn
                       finalText:(NSString *)finalText
                    errorMessage:(NSString *)errorMessage
                       startedAt:(CFAbsoluteTime)startedAt {
    dispatch_async(_workerQueue, ^{
        NSString *trimmedError = BeaconTrimmedString(errorMessage ?: @"");
        NSString *trimmedText = BeaconSanitizeModelText(finalText ?: @"");

        self->_lastBenchmarkSummary = [self benchmarkSummaryForConversation:self->_conversation];
        NSTimeInterval elapsedMs = (CFAbsoluteTimeGetCurrent() - startedAt) * 1000.0;

        if (trimmedError.length > 0) {
            BeaconNativeLog(@"stream failed session=%@ durationMs=%ld error=%@",
                            sessionId ?: @"(none)",
                            (long)llround(elapsedMs),
                            trimmedError);
            [self emitTriageStreamPayload:@{
                @"streamId": streamId ?: @"",
                @"done": @YES,
                @"error": trimmedError
            }];
            return;
        }

        if (!BeaconHasMeaningfulModelText(trimmedText)) {
            NSString *emptyError = @"LiteRT-LM produced an empty response.";
            BeaconNativeLog(@"stream failed: empty response session=%@", sessionId ?: @"(none)");
            [self emitTriageStreamPayload:@{
                @"streamId": streamId ?: @"",
                @"done": @YES,
                @"error": emptyError
            }];
            return;
        }

        if (self->_lastBenchmarkSummary != nil) {
            BeaconNativeLog(@"stream done session=%@ backend=%@ ttftMs=%@ decodeTps=%@ durationMs=%ld response=%@",
                            sessionId ?: @"(none)",
                            self->_activeBackend ?: @"unknown",
                            self->_lastBenchmarkSummary[@"timeToFirstTokenMs"] ?: @(0),
                            self->_lastBenchmarkSummary[@"lastDecodeTokensPerSecond"] ?: @(0),
                            (long)llround(elapsedMs),
                            BeaconTruncatedPreview(trimmedText, 220));
        } else {
            BeaconNativeLog(@"stream done session=%@ durationMs=%ld response=%@",
                            sessionId ?: @"(none)",
                            (long)llround(elapsedMs),
                            BeaconTruncatedPreview(trimmedText, 220));
        }

        [self rememberSessionMemoryForSessionId:sessionId
                                        modelId:modelId ?: self->_loadedModelId
                                   categoryHint:categoryHint
                                       userText:userText
                                   responseText:trimmedText
                                   isVisualTurn:isVisualTurn];
        [self releaseFinishedConversationWithReason:@"stream-complete-sidecar-memory"];

        [self emitTriageStreamPayload:@{
            @"streamId": streamId ?: @"",
            @"done": @YES,
            @"finalText": trimmedText,
            @"modelId": self->_loadedModelId ?: @"",
            @"usedProfileName": [self activeProfileName]
        }];
    });
}

- (NSString *)activeProfileName {
    NSDictionary *spec = _loadedModelId != nil ? [self modelSpecForId:_loadedModelId] : nil;
    NSString *profile = spec[@"defaultProfileName"];
    return profile.length > 0 ? profile : (spec[@"name"] ?: @"Gemma 4 E2B");
}

- (NSURL *)smokeResultsURL {
    NSURL *tmpDirectory = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    return [tmpDirectory URLByAppendingPathComponent:@"beacon-native-smoke-results.json" isDirectory:NO];
}

- (void)persistSmokeSummary:(NSDictionary *)summary {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:summary options:NSJSONWritingPrettyPrinted error:&error];
    if (data == nil || error != nil) {
        BeaconNativeLog(@"failed to serialize smoke summary: %@", error.localizedDescription ?: @"unknown");
        BeaconWriteSmokeProgress(@"smoke-summary-serialize-failed", @{
            @"error": error.localizedDescription ?: @"unknown"
        });
        return;
    }

    NSURL *url = [self smokeResultsURL];
    if (![data writeToURL:url options:NSDataWritingAtomic error:&error]) {
        BeaconNativeLog(@"failed to write smoke summary to %@: %@", url.path, error.localizedDescription ?: @"unknown");
        BeaconWriteSmokeProgress(@"smoke-summary-write-failed", @{
            @"path": url.path ?: @"",
            @"error": error.localizedDescription ?: @"unknown"
        });
        return;
    }

    BeaconNativeLog(@"smoke summary saved: %@", url.path);
    BeaconWriteSmokeProgress(@"smoke-summary-saved", @{
        @"path": url.path ?: @""
    });
}

- (NSDictionary *)smokeRequestWithUserText:(NSString *)userText
                               categoryHint:(NSString *)categoryHint
                                  sessionId:(NSString *)sessionId
                               resetContext:(BOOL)resetContext
                                     locale:(NSString *)locale
                                  powerMode:(NSString *)powerMode
                           groundingContext:(NSString *)groundingContext
                                 imageBase64:(NSString *)imageBase64 {
    BOOL hasGrounding = BeaconTrimmedString(groundingContext ?: @"").length > 0;
    NSMutableDictionary *payload = [@{
        @"modelId": _loadedModelId ?: @"",
        @"userText": userText ?: @"",
        @"categoryHint": categoryHint ?: @"",
        @"sessionId": sessionId ?: @"smoke-session",
        @"resetContext": @(resetContext),
        @"locale": locale ?: @"en",
        @"powerMode": powerMode ?: @"normal",
        @"groundingContext": groundingContext ?: @"(none)",
        @"hasAuthoritativeEvidence": @(hasGrounding)
    } mutableCopy];
    NSString *normalizedImage = BeaconNormalizedBase64Blob(imageBase64);
    if (normalizedImage.length > 0) {
        payload[@"imageBase64"] = normalizedImage;
    }
    return payload;
}

- (NSDictionary *)runSmokeCheckNamed:(NSString *)name request:(NSDictionary *)request {
    CFAbsoluteTime startedAt = CFAbsoluteTimeGetCurrent();
    BeaconWriteSmokeProgress(@"smoke-check-started", @{
        @"name": name ?: @"unnamed",
        @"traceToken": BeaconSmokeTraceToken() ?: @""
    });
    NSError *error = nil;
    NSString *responseText = [self generateResponseForRequest:request error:&error];
    NSTimeInterval elapsedMs = (CFAbsoluteTimeGetCurrent() - startedAt) * 1000.0;

    if (responseText.length == 0) {
        BeaconWriteSmokeProgress(@"smoke-check-failed", @{
            @"name": name ?: @"unnamed",
            @"error": error.localizedDescription ?: @"empty response"
        });
        return @{
            @"name": name ?: @"unnamed",
            @"ok": @NO,
            @"durationMs": @((NSInteger)llround(elapsedMs)),
            @"error": error.localizedDescription ?: @"empty response",
            @"requestPreview": BeaconTruncatedPreview(request[@"userText"] ?: @"", 120)
        };
    }

    BeaconWriteSmokeProgress(@"smoke-check-finished", @{
        @"name": name ?: @"unnamed",
        @"durationMs": @((NSInteger)llround(elapsedMs))
    });
    return @{
        @"name": name ?: @"unnamed",
        @"ok": @YES,
        @"durationMs": @((NSInteger)llround(elapsedMs)),
        @"requestPreview": BeaconTruncatedPreview(request[@"userText"] ?: @"", 120),
        @"responsePreview": BeaconTruncatedPreview(responseText, 220),
        @"responseText": responseText
    };
}

- (void)runSmokeTests {
    NSString *traceToken = BeaconSmokeTraceToken();
    BeaconWriteSmokeProgress(@"smoke-tests-started", @{
        @"traceToken": traceToken ?: @""
    });
    NSString *queryOverride = BeaconSmokeQueryOverride();
    NSString *firePrompt = BeaconTrimmedString(queryOverride ?: @"I am trapped in a building fire with thick smoke and limited visibility. What should I do first?");
    NSString *lostPrompt = @"I went back home and now I am lost in the mountains with no signal and sunset is coming. What should I do first?";
    NSString *visualPrompt = @"Possible snakebite on my ankle.\nLook at this image and tell me what is dangerous and what to do next.";
    NSString *visualImageBase64 = @"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO5W6ucAAAAASUVORK5CYII=";
    NSString *fireGrounding = @"Source: Ready.gov Fire Survival\nActions:\n- Stay low under smoke and move to the nearest safe exit.\n- Cover nose and mouth with cloth if available.\n- Test doors for heat before opening.\nAvoid:\n- Do not use elevators.\nEscalate:\n- If trapped, seal the room, call or signal for rescue.";
    NSString *lostGrounding = @"Source: National Park Service Wilderness Travel Basics\nActions:\n- Stop moving, control panic, and stay near shelter before dark.\n- Put on extra insulation and protect from wind.\n- Mark your location and prepare visible signals.\nAvoid:\n- Do not keep wandering after losing the trail late in the day.\nEscalate:\n- If weather worsens or you cannot stay warm, signal for rescue immediately.";
    NSString *visualGrounding = @"Source: CDC Outdoor Hazards + Merck Manual\nActions:\n- Check for worsening swelling, bleeding, color change, and breathing trouble.\n- Keep the limb still and remove tight jewelry.\n- Seek urgent rescue if signs of severe envenomation appear.\nAvoid:\n- Do not cut, suck, or apply ice to the wound.\nEscalate:\n- Immediate rescue is needed for trouble breathing, fainting, or rapidly spreading swelling.";

    BeaconNativeLog(@"starting smoke tests; requestedQuery=%@", BeaconTruncatedPreview(firePrompt, 120));

    NSMutableArray<NSDictionary *> *checks = [NSMutableArray array];
    NSDictionary *fireCheck = [self runSmokeCheckNamed:@"triage.fire" request:[self smokeRequestWithUserText:firePrompt
                                                                                               categoryHint:@"Trapped in Fire"
                                                                                                  sessionId:@"smoke-fire"
                                                                                               resetContext:YES
                                                                                                     locale:@"en"
                                                                                                  powerMode:@"normal"
                                                                                            groundingContext:fireGrounding
                                                                                                  imageBase64:nil]];
    [checks addObject:fireCheck];

    NSDictionary *visualCheck = [self runSmokeCheckNamed:@"visual.snakebite" request:[self smokeRequestWithUserText:visualPrompt
                                                                                                      categoryHint:@"Visual Help / 视觉求助 / wound bleeding bite sting snake spider tick burn rash plant animal fracture poisoning"
                                                                                                         sessionId:@"smoke-visual"
                                                                                                      resetContext:YES
                                                                                                            locale:@"en"
                                                                                                         powerMode:@"normal"
                                                                                                  groundingContext:visualGrounding
                                                                                                        imageBase64:visualImageBase64]];
    [checks addObject:visualCheck];

    NSDictionary *resetCheck = [self runSmokeCheckNamed:@"triage.reset.new-session" request:[self smokeRequestWithUserText:lostPrompt
                                                                                                         categoryHint:@"Lost/Disconnected"
                                                                                                            sessionId:@"smoke-lost"
                                                                                                         resetContext:YES
                                                                                                               locale:@"en"
                                                                                                            powerMode:@"normal"
                                                                                                     groundingContext:lostGrounding
                                                                                                           imageBase64:nil]];
    [checks addObject:resetCheck];

    BOOL fireOk = [fireCheck[@"ok"] boolValue];
    BOOL visualOk = [visualCheck[@"ok"] boolValue];
    BOOL resetOk = [resetCheck[@"ok"] boolValue];
    NSString *fireResponse = fireCheck[@"responseText"];
    NSString *resetResponse = resetCheck[@"responseText"];
    BOOL outputsDiffer = fireResponse.length > 0 && resetResponse.length > 0 && ![fireResponse isEqualToString:resetResponse];

    if (!outputsDiffer) {
        BeaconNativeLog(@"smoke reset check warning: fire and reset responses are identical");
    }

    NSMutableDictionary *summary = [@{
        @"ok": @(fireOk && visualOk && resetOk && outputsDiffer),
        @"modelId": _loadedModelId ?: @"",
        @"profile": [self activeProfileName],
        @"checks": checks,
        @"resetProducedDifferentOutput": @(outputsDiffer),
        @"generatedAt": BeaconISO8601TimestampNow(),
        @"runtimeDiagnostics": [self runtimeDiagnosticsPayload]
    } mutableCopy];
    if (traceToken.length > 0) {
        summary[@"traceToken"] = traceToken;
    }
    [self persistSmokeSummary:summary];
    [[NSFileManager defaultManager] removeItemAtURL:BeaconSmokeRequestURL() error:nil];
    BeaconWriteSmokeProgress(@"smoke-request-removed", @{
        @"traceToken": traceToken ?: @""
    });

    if ([summary[@"ok"] boolValue]) {
        BeaconNativeLog(@"smoke tests passed; model=%@ profile=%@", _loadedModelId ?: @"(none)", [self activeProfileName]);
        return;
    }

    BeaconNativeLog(@"smoke tests failed; fire=%@ visual=%@ reset=%@ outputsDiffer=%@",
                    fireOk ? @"ok" : @"fail",
                    visualOk ? @"ok" : @"fail",
                    resetOk ? @"ok" : @"fail",
                    outputsDiffer ? @"yes" : @"no");
}

- (void)maybeScheduleSmokeTest {
    if (_didScheduleSmokeTest || !BeaconSmokeTestRequested() || !BeaconClaimSmokeRun()) {
        return;
    }
    _didScheduleSmokeTest = YES;
    dispatch_async(_workerQueue, ^{
        [self runSmokeTests];
    });
}

- (BOOL)ensureEngineLoaded:(NSString *)requestedModelId requiresVision:(BOOL)requiresVision error:(NSError **)error {
    NSString *targetModelId = requestedModelId.length > 0 ? requestedModelId : (_loadedModelId.length > 0 ? _loadedModelId : [self defaultAvailableModelId]);
    if (targetModelId.length == 0) {
        if (error != nil) {
            *error = [NSError errorWithDomain:@"BeaconNative" code:100 userInfo:@{NSLocalizedDescriptionKey: @"No bundled local model is available on this iPhone build."}];
        }
        BeaconNativeLog(@"engine load failed: no available model id");
        return NO;
    }

    NSDictionary *spec = [self modelSpecForId:targetModelId];
    NSURL *modelURL = spec != nil ? [self resolvedModelURLForSpec:spec] : nil;
    if (spec == nil || modelURL == nil) {
        if (error != nil) {
            *error = [NSError errorWithDomain:@"BeaconNative" code:101 userInfo:@{NSLocalizedDescriptionKey: @"Gemma 4 E2B is not packaged into this iOS build."}];
        }
        BeaconNativeLog(@"engine load failed: missing packaged model for %@", targetModelId);
        return NO;
    }

    if (_engine != NULL
        && [_loadedModelId isEqualToString:targetModelId]
        && (!requiresVision || _loadedEngineRequiresVision)) {
        BeaconNativeLog(@"reusing loaded engine for %@ (%@) vision=%@",
                        targetModelId,
                        modelURL.lastPathComponent ?: modelURL.path,
                        _loadedEngineRequiresVision ? @"enabled" : @"disabled");
        return YES;
    }

    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSString *failureCacheKey = BeaconEngineLoadCacheKey(targetModelId, requiresVision);
    if (_cachedEngineLoadFailure != nil
        && [_cachedEngineLoadFailureModelId isEqualToString:failureCacheKey]
        && (_cachedEngineLoadFailure.code == 109 || (now - _cachedEngineLoadFailureAt) < 5.0)) {
        if (error != nil) {
            *error = _cachedEngineLoadFailure;
        }
        BeaconNativeLog(@"skipping repeated engine init retry for %@ vision=%@ after recent failure",
                        targetModelId,
                        requiresVision ? @"enabled" : @"disabled");
        return NO;
    }

    NSError *unsupportedDeviceError = BeaconUnsupportedDeviceErrorForModelId(targetModelId);
    if (unsupportedDeviceError != nil) {
        _cachedEngineLoadFailure = unsupportedDeviceError;
        _cachedEngineLoadFailureModelId = [failureCacheKey copy];
        _cachedEngineLoadFailureAt = now;
        _lastEngineFailureMessage = unsupportedDeviceError.localizedDescription ?: @"unsupported device";
        if (error != nil) {
            *error = unsupportedDeviceError;
        }
        BeaconNativeLog(@"engine load blocked for %@: %@ (physicalMemory=%llu)",
                        targetModelId,
                        unsupportedDeviceError.localizedDescription ?: @"unsupported device",
                        [NSProcessInfo processInfo].physicalMemory);
        return NO;
    }

    NSDictionary *capability = [self capabilitySnapshotForSpec:spec];
    NSString *effectivePreferredBackend = [self effectivePreferredBackendForModelId:targetModelId
                                                                               spec:spec
                                                                         capability:capability];
    BOOL requestedGpuOnly = BeaconRequestedFlagEnabled(kBeaconLiteRtGpuOnlyEnvKey, @"gpuOnly");
    BOOL allowUnsafeGpuOnly = BeaconRequestedFlagEnabled(kBeaconLiteRtAllowUnsafeGpuOnlyEnvKey, @"allowUnsafeGpuOnly");
    BOOL skipGpuAttempt = BeaconRequestedFlagEnabled(kBeaconLiteRtSkipGpuEnvKey, @"skipGpu");
    BOOL gpuEligible = [capability[@"gpuEligible"] respondsToSelector:@selector(boolValue)] ? [capability[@"gpuEligible"] boolValue] : NO;
    NSString *supportedDeviceClass = [capability[@"supportedDeviceClass"] isKindOfClass:[NSString class]]
        ? capability[@"supportedDeviceClass"]
        : @"unknown";
    BOOL conservativeCpuProfile = BeaconUsesConservativeCpuProfileForDeviceClass(supportedDeviceClass);
    if (requestedGpuOnly && !gpuEligible && !allowUnsafeGpuOnly) {
        NSError *blockedGpuOnlyError = BeaconBlockedGpuOnlyErrorForModelId(targetModelId);
        _cachedEngineLoadFailure = blockedGpuOnlyError;
        _cachedEngineLoadFailureModelId = [failureCacheKey copy];
        _cachedEngineLoadFailureAt = now;
        _lastEngineFailureMessage = blockedGpuOnlyError.localizedDescription ?: @"gpu-only blocked";
        _lastGpuFailureMessage = blockedGpuOnlyError.localizedDescription ?: @"gpu-only blocked";
        if (error != nil) {
            *error = blockedGpuOnlyError;
        }
        BeaconNativeLog(@"engine load blocked for %@: %@", targetModelId, blockedGpuOnlyError.localizedDescription ?: @"gpu-only blocked");
        return NO;
    }
    BOOL shouldTryGpuAuto = !requestedGpuOnly
        && !skipGpuAttempt
        && gpuEligible
        && ![effectivePreferredBackend isEqualToString:@"cpu"];

    if (_conversation != NULL) {
        litert_lm_conversation_delete(_conversation);
        _conversation = NULL;
        _activeConversationRequiresVision = NO;
    }
    if (_engine != NULL) {
        litert_lm_engine_delete(_engine);
        _engine = NULL;
        _loadedEngineRequiresVision = NO;
    }
    _activeSessionId = nil;
    _activeConversationModelId = nil;
    _activeConversationPowerMode = nil;
    _activeBackend = nil;
    _activeVisionBackend = nil;
    _activeEngineAttempt = nil;
    _lastEngineAttemptLog = nil;
    _lastBenchmarkSummary = nil;
    _lastGpuFailureMessage = nil;
    _gpuAttemptedDuringLastLoad = NO;
    _gpuFallbackToCpuDuringLastLoad = NO;
    _lastRuntimeAudit = BeaconLiteRtRuntimeAudit();

    NSArray<NSDictionary *> *attempts = nil;
#if TARGET_OS_SIMULATOR
    if (requiresVision) {
        attempts = @[
            @{
                @"backend": @"cpu",
                @"visionBackend": @"cpu",
                @"parallel": @NO,
                @"maxTokens": @1024,
                @"prefillChunkSize": @128,
                @"activationDataType": @0
            },
            @{
                @"backend": @"cpu",
                @"visionBackend": @"cpu",
                @"parallel": @NO,
                @"maxTokens": @1024
            }
        ];
    } else {
        attempts = @[
            @{
                @"backend": @"cpu",
                @"parallel": @YES,
                // The bundled Gemma 4 E2B LiteRT package currently validates its
                // prefill/decode magic-number layout against a 1024-token main
                // window on iOS. Keeping CPU fallback aligned avoids
                // DYNAMIC_UPDATE_SLICE allocation failures at first prefill.
                @"maxTokens": @1024
            },
            @{
                @"backend": @"cpu",
                @"parallel": @NO,
                @"maxTokens": @2048
            },
            @{
                @"backend": @"cpu",
                @"parallel": @NO,
                @"maxTokens": @1024,
                @"prefillChunkSize": @128,
                @"activationDataType": @0
            },
            @{
                @"backend": @"cpu",
                @"parallel": @NO,
                @"maxTokens": @1024,
                @"prefillChunkSize": @128,
                @"activationDataType": @1
            },
            @{
                @"backend": @"cpu",
                @"parallel": @NO,
                @"maxTokens": @1024,
                @"prefillChunkSize": @128,
                @"activationDataType": @0
            }
        ];
    }
#else
    BOOL forceGpuOnly = requestedGpuOnly;
    if (requiresVision) {
        if (forceGpuOnly) {
            attempts = @[
                @{
                    @"backend": @"gpu",
                    @"visionBackend": @"gpu",
                    @"parallel": @NO,
                    @"maxTokens": @1024,
                    @"activationDataType": @1,
                    @"cacheMode": @"session-scoped"
                },
                @{
                    @"backend": @"gpu",
                    @"visionBackend": @"cpu",
                    @"parallel": @NO,
                    @"maxTokens": @1024,
                    @"activationDataType": @0,
                    @"cacheMode": @"default",
                    @"samplerBackend": @"cpu"
                }
            ];
        } else if (shouldTryGpuAuto) {
            attempts = @[
                @{
                    @"backend": @"gpu",
                    @"visionBackend": @"gpu",
                    @"parallel": @NO,
                    @"maxTokens": @1024,
                    @"activationDataType": @1,
                    @"cacheMode": @"session-scoped"
                },
                @{
                    @"backend": @"gpu",
                    @"visionBackend": @"cpu",
                    @"parallel": @NO,
                    @"maxTokens": @1024,
                    @"activationDataType": @0,
                    @"cacheMode": @"default",
                    @"samplerBackend": @"cpu"
                },
                @{
                    @"backend": @"cpu",
                    @"visionBackend": @"cpu",
                    @"parallel": @NO,
                    @"maxTokens": @1024,
                    @"prefillChunkSize": @128,
                    @"activationDataType": @0
                },
                @{
                    @"backend": @"cpu",
                    @"visionBackend": @"cpu",
                    @"parallel": @NO,
                    @"maxTokens": @1024
                }
            ];
        } else {
            attempts = conservativeCpuProfile ? @[
                @{
                    @"backend": @"cpu",
                    @"visionBackend": @"cpu",
                    @"parallel": @NO,
                    @"maxTokens": @1024,
                    @"prefillChunkSize": @128,
                    @"activationDataType": @0
                },
                @{
                    @"backend": @"cpu",
                    @"visionBackend": @"cpu",
                    @"parallel": @NO,
                    @"maxTokens": @1024,
                    @"prefillChunkSize": @128,
                    @"activationDataType": @1
                },
                @{
                    @"backend": @"cpu",
                    @"visionBackend": @"cpu",
                    @"parallel": @NO,
                    @"maxTokens": @512,
                    @"prefillChunkSize": @128,
                    @"activationDataType": @0
                },
                @{
                    @"backend": @"cpu",
                    @"visionBackend": @"cpu",
                    @"parallel": @NO,
                    @"maxTokens": @512,
                    @"prefillChunkSize": @128,
                    @"activationDataType": @1
                }
            ] : @[
                @{
                    @"backend": @"cpu",
                    @"visionBackend": @"cpu",
                    @"parallel": @NO,
                    @"maxTokens": @1024,
                    @"prefillChunkSize": @128,
                    @"activationDataType": @0
                },
                @{
                    @"backend": @"cpu",
                    @"visionBackend": @"cpu",
                    @"parallel": @NO,
                    @"maxTokens": @1024
                },
                @{
                    @"backend": @"cpu",
                    @"visionBackend": @"cpu",
                    @"parallel": @YES,
                    @"maxTokens": @1024,
                    @"prefillChunkSize": @128
                }
            ];
        }
    } else if (forceGpuOnly) {
        attempts = @[
            @{
                @"backend": @"gpu",
                @"parallel": @NO,
                @"maxTokens": @1024,
                @"activationDataType": @0,
                @"cacheMode": @"default",
                @"samplerBackend": @"cpu"
            },
            @{
                @"backend": @"gpu",
                @"parallel": @NO,
                @"maxTokens": @1024,
                @"activationDataType": @1,
                @"cacheMode": @"session-scoped",
                @"samplerBackend": @"cpu"
            },
            @{
                @"backend": @"gpu",
                @"parallel": @NO,
                @"maxTokens": @1024,
                @"activationDataType": @1,
                @"cacheMode": @"session-scoped"
            }
        ];
    } else if (shouldTryGpuAuto) {
        attempts = @[
            @{
                @"backend": @"gpu",
                @"parallel": @NO,
                @"maxTokens": @1024,
                @"activationDataType": @0,
                @"cacheMode": @"default",
                @"samplerBackend": @"cpu"
            },
            @{
                @"backend": @"gpu",
                @"parallel": @NO,
                @"maxTokens": @1024,
                @"activationDataType": @1,
                @"cacheMode": @"session-scoped",
                @"samplerBackend": @"cpu"
            },
            @{
                @"backend": @"cpu",
                @"parallel": @NO,
                @"maxTokens": @1024,
                @"prefillChunkSize": @128,
                @"activationDataType": @0
            },
            @{
                @"backend": @"cpu",
                @"parallel": @NO,
                @"maxTokens": @1024
            },
            @{
                @"backend": @"cpu",
                @"parallel": @YES,
                @"maxTokens": @1024,
                @"prefillChunkSize": @128
            }
        ];
    } else if (skipGpuAttempt) {
        attempts = conservativeCpuProfile ? @[
            @{
                @"backend": @"cpu",
                @"parallel": @NO,
                @"maxTokens": @1024,
                @"prefillChunkSize": @128,
                @"activationDataType": @0
            },
            @{
                @"backend": @"cpu",
                @"parallel": @NO,
                @"maxTokens": @1024,
                @"prefillChunkSize": @128,
                @"activationDataType": @1
            },
            @{
                @"backend": @"cpu",
                @"parallel": @NO,
                @"maxTokens": @512,
                @"prefillChunkSize": @128,
                @"activationDataType": @0
            },
            @{
                @"backend": @"cpu",
                @"parallel": @NO,
                @"maxTokens": @512,
                @"prefillChunkSize": @128,
                @"activationDataType": @1
            }
        ] : @[
            @{
                @"backend": @"cpu",
                @"parallel": @NO,
                @"maxTokens": @1024,
                @"prefillChunkSize": @128,
                @"activationDataType": @0
            },
            @{
                @"backend": @"cpu",
                @"parallel": @NO,
                @"maxTokens": @1024
            },
            @{
                @"backend": @"cpu",
                @"parallel": @YES,
                @"maxTokens": @1024,
                @"prefillChunkSize": @128
            },
            @{
                @"backend": @"cpu",
                @"parallel": @NO,
                @"maxTokens": @0,
                @"prefillChunkSize": @128
            }
        ];
    } else {
        attempts = conservativeCpuProfile ? @[
            @{
                @"backend": @"cpu",
                @"parallel": @NO,
                @"maxTokens": @1024,
                @"prefillChunkSize": @128,
                @"activationDataType": @0
            },
            @{
                @"backend": @"cpu",
                @"parallel": @NO,
                @"maxTokens": @1024,
                @"prefillChunkSize": @128,
                @"activationDataType": @1
            },
            @{
                @"backend": @"cpu",
                @"parallel": @NO,
                @"maxTokens": @512,
                @"prefillChunkSize": @128,
                @"activationDataType": @0
            },
            @{
                @"backend": @"cpu",
                @"parallel": @NO,
                @"maxTokens": @512,
                @"prefillChunkSize": @128,
                @"activationDataType": @1
            }
        ] : @[
            @{
                @"backend": @"cpu",
                @"parallel": @NO,
                @"maxTokens": @1024,
                @"prefillChunkSize": @128,
                @"activationDataType": @0
            },
            @{
                @"backend": @"cpu",
                @"parallel": @NO,
                @"maxTokens": @1024
            },
            @{
                @"backend": @"cpu",
                @"parallel": @YES,
                @"maxTokens": @1024,
                @"prefillChunkSize": @128
            },
            @{
                @"backend": @"cpu",
                @"parallel": @NO,
                @"maxTokens": @0,
                @"prefillChunkSize": @128
            }
        ];
    }
#endif

    NSString *requestedCacheMode = BeaconLiteRtRequestedCacheMode();
    NSString *requestedSamplerBackend = BeaconNormalizedBackendIdentifier(BeaconRequestedStringValue(kBeaconLiteRtSamplerBackendEnvKey, @"samplerBackend"));
    NSInteger requestedMaxTokens = 0;
    NSInteger requestedPrefillChunkSize = 0;
    NSInteger requestedActivationDataType = 0;
    BOOL requestedParallelFileLoading = NO;
    BOOL requestedInjectDispatchLibraryDir = NO;
    BOOL hasMaxTokensOverride = BeaconRequestedIntegerValue(kBeaconLiteRtMaxTokensEnvKey, @"maxTokens", &requestedMaxTokens);
    BOOL hasPrefillChunkSizeOverride = BeaconRequestedIntegerValue(kBeaconLiteRtPrefillChunkSizeEnvKey, @"prefillChunkSize", &requestedPrefillChunkSize);
    BOOL hasActivationDataTypeOverride = BeaconRequestedIntegerValue(kBeaconLiteRtActivationDataTypeEnvKey, @"activationDataType", &requestedActivationDataType);
    BOOL hasParallelFileLoadingOverride = BeaconRequestedFlagValue(kBeaconLiteRtParallelFileLoadingEnvKey, @"parallelFileLoading", &requestedParallelFileLoading);
    BOOL hasInjectDispatchLibraryDirOverride = BeaconRequestedFlagValue(kBeaconLiteRtInjectDispatchLibraryDirEnvKey, @"injectDispatchLibraryDir", &requestedInjectDispatchLibraryDir);

    LiteRtLmEngine *createdEngine = NULL;
    NSString *successfulAttempt = nil;
    NSMutableArray<NSString *> *attemptLogs = [NSMutableArray arrayWithCapacity:attempts.count];
    NSMutableArray<NSString *> *gpuFailureLogs = [NSMutableArray array];
    litert_lm_set_min_log_level(0);
    for (NSDictionary *attempt in attempts) {
        NSString *backend = [attempt[@"backend"] isKindOfClass:[NSString class]] ? attempt[@"backend"] : @"cpu";
        NSString *visionBackend = [attempt[@"visionBackend"] isKindOfClass:[NSString class]] ? attempt[@"visionBackend"] : nil;
        BOOL parallelFileLoading = [attempt[@"parallel"] respondsToSelector:@selector(boolValue)] ? [attempt[@"parallel"] boolValue] : YES;
        if (hasParallelFileLoadingOverride) {
            parallelFileLoading = requestedParallelFileLoading;
        }
        NSInteger maxTokens = [attempt[@"maxTokens"] respondsToSelector:@selector(integerValue)] ? [attempt[@"maxTokens"] integerValue] : 2048;
        if (hasMaxTokensOverride) {
            maxTokens = requestedMaxTokens;
        }
        NSNumber *prefillChunkSize = [attempt[@"prefillChunkSize"] respondsToSelector:@selector(integerValue)] ? attempt[@"prefillChunkSize"] : nil;
        if (hasPrefillChunkSizeOverride) {
            prefillChunkSize = @(requestedPrefillChunkSize);
        }
        NSNumber *activationDataType = [attempt[@"activationDataType"] respondsToSelector:@selector(integerValue)] ? attempt[@"activationDataType"] : nil;
        if (hasActivationDataTypeOverride) {
            activationDataType = @(requestedActivationDataType);
        }
        NSString *cacheModeOverride = [attempt[@"cacheMode"] isKindOfClass:[NSString class]] ? attempt[@"cacheMode"] : nil;
        if (requestedCacheMode.length > 0) {
            cacheModeOverride = requestedCacheMode;
        }
        NSString *samplerBackend = [attempt[@"samplerBackend"] isKindOfClass:[NSString class]] ? attempt[@"samplerBackend"] : nil;
        if (requestedSamplerBackend.length > 0) {
            samplerBackend = requestedSamplerBackend;
        }
        BOOL injectDispatchLibraryDir = [attempt[@"injectDispatchLibraryDir"] respondsToSelector:@selector(boolValue)]
            ? [attempt[@"injectDispatchLibraryDir"] boolValue]
            : BeaconLiteRtShouldInjectDispatchLibraryDir();
        if (hasInjectDispatchLibraryDirOverride) {
            injectDispatchLibraryDir = requestedInjectDispatchLibraryDir;
        }
        NSString *runtimeDispatchMode = injectDispatchLibraryDir ? @"explicit-dir" : (BeaconLiteRtShouldPreloadMetalAccelerator() ? @"preload-only" : @"disabled");

        NSMutableString *attemptDescription = [NSMutableString stringWithFormat:@"backend=%@ vision=%@ parallel=%@ maxTokens=%ld dispatch=%@ cache=%@ sampler=%@",
                                               backend,
                                               visionBackend.length > 0 ? visionBackend : @"(none)",
                                               parallelFileLoading ? @"on" : @"off",
                                               (long)maxTokens,
                                               runtimeDispatchMode,
                                               cacheModeOverride ?: @"(default)",
                                               samplerBackend ?: @"(default)"];
        if (prefillChunkSize != nil) {
            [attemptDescription appendFormat:@" prefill=%@", prefillChunkSize];
        }
        if (activationDataType != nil) {
            [attemptDescription appendFormat:@" activation=%@", activationDataType];
        }
        NSString *attemptLabel = [attemptDescription copy];
        BeaconNativeLog(@"trying engine %@ model=%@", attemptLabel, modelURL.path ?: @"(unknown)");
        BeaconWriteSmokeProgress(@"engine-attempt-start", @{
            @"attempt": attemptLabel,
            @"traceToken": BeaconSmokeTraceToken() ?: @""
        });
        if ([backend isEqualToString:@"gpu"]) {
            _gpuAttemptedDuringLastLoad = YES;
        }

        LiteRtLmEngineSettings *settings = litert_lm_engine_settings_create(modelURL.path.UTF8String,
                                                                            backend.UTF8String,
                                                                            visionBackend.length > 0 ? visionBackend.UTF8String : NULL,
                                                                            NULL);
        if (settings == NULL) {
            NSString *failureLog = [NSString stringWithFormat:@"%@ => settings-create-null", attemptLabel];
            [attemptLogs addObject:failureLog];
            if ([backend isEqualToString:@"gpu"]) {
                [gpuFailureLogs addObject:failureLog];
            }
            BeaconNativeLog(@"engine settings creation failed for %@", attemptLabel);
            BeaconWriteSmokeProgress(@"engine-settings-create-null", @{
                @"attempt": attemptLabel
            });
            continue;
        }
        NSString *cacheMode = nil;
        NSString *cachePath = BeaconLiteRtCacheSpecifierForAttempt(modelURL, backend, attemptLabel, cacheModeOverride, &cacheMode);
        litert_lm_engine_settings_set_cache_dir(settings, cachePath.UTF8String);
        if (samplerBackend.length > 0) {
            litert_lm_engine_settings_set_sampler_backend(settings, samplerBackend.UTF8String);
        }
        NSString *runtimeLibraryDir = BeaconLiteRtRuntimeLibraryDirectory();
        NSString *runtimeLibraryPath = runtimeLibraryDir.length > 0
            ? [runtimeLibraryDir stringByAppendingPathComponent:@"libLiteRtMetalAccelerator.dylib"]
            : @"";
        NSDictionary *runtimeLibraryProbe = BeaconLiteRtShouldPreloadMetalAccelerator()
            ? BeaconEnsureMetalAcceleratorPreloaded(runtimeLibraryPath)
            : @{
                @"path": runtimeLibraryPath ?: @"",
                @"exists": @(
                    runtimeLibraryPath.length > 0 &&
                    [[NSFileManager defaultManager] fileExistsAtPath:runtimeLibraryPath]
                ),
                @"loadable": @NO,
                @"preloaded": @NO,
                @"error": @"skipped-by-runtime-dispatch-mode"
            };
        if (runtimeLibraryDir.length > 0 && injectDispatchLibraryDir) {
            litert_lm_engine_settings_set_dispatch_library_dir(settings, runtimeLibraryDir.UTF8String);
        }
        litert_lm_engine_settings_enable_benchmark(settings);
        litert_lm_engine_settings_set_parallel_file_section_loading(settings, parallelFileLoading);
        litert_lm_engine_settings_set_max_num_tokens(settings, (int)maxTokens);
        if (requiresVision) {
            litert_lm_engine_settings_set_max_num_images(settings, 1);
        }
        if (prefillChunkSize != nil && [backend isEqualToString:@"cpu"]) {
            litert_lm_engine_settings_set_prefill_chunk_size(settings, [prefillChunkSize intValue]);
        }
        if (activationDataType != nil) {
            litert_lm_engine_settings_set_activation_data_type(settings, [activationDataType intValue]);
        }
        BeaconWriteSmokeProgress(@"engine-create-call", @{
            @"attempt": attemptLabel,
            @"samplerBackend": samplerBackend ?: @"(default)",
            @"cacheMode": cacheMode ?: @"default",
            @"cachePath": cachePath ?: @"",
            @"runtimeDispatchMode": runtimeDispatchMode,
            @"runtimeLibraryDir": runtimeLibraryDir ?: @"",
            @"runtimeLibraryPath": runtimeLibraryPath,
            @"runtimeLibraryExists": runtimeLibraryProbe[@"exists"] ?: @NO,
            @"runtimeLibraryLoadable": runtimeLibraryProbe[@"loadable"] ?: @NO,
            @"runtimeLibraryLoadError": runtimeLibraryProbe[@"error"] ?: @"",
            @"runtimeLibraryPreloaded": runtimeLibraryProbe[@"preloaded"] ?: @NO,
            @"dispatchLibraryDirInjected": @(runtimeLibraryDir.length > 0 && injectDispatchLibraryDir)
        });
        NSString *safeEngineCreateError = nil;
        createdEngine = BeaconLiteRtSafeEngineCreate(settings, &safeEngineCreateError);
        BeaconWriteSmokeProgress(@"engine-create-returned", @{
            @"attempt": attemptLabel,
            @"success": @(createdEngine != NULL),
            @"error": safeEngineCreateError ?: @""
        });
        litert_lm_engine_settings_delete(settings);
        if (createdEngine != NULL) {
            NSString *successLog = [NSString stringWithFormat:@"%@ => success", attemptLabel];
            [attemptLogs addObject:successLog];
            successfulAttempt = attemptLabel;
            _activeBackend = [backend copy];
            _activeVisionBackend = [visionBackend copy];
            _activeEngineAttempt = attemptLabel;
            _loadedEngineRequiresVision = requiresVision;
            _lastEngineFailureMessage = nil;
            if (_gpuAttemptedDuringLastLoad && ![backend isEqualToString:@"gpu"] && gpuFailureLogs.count > 0) {
                _gpuFallbackToCpuDuringLastLoad = YES;
            }
            NSString *persistedGpuReason = (_gpuAttemptedDuringLastLoad && ![backend isEqualToString:@"gpu"])
                ? [gpuFailureLogs componentsJoinedByString:@" | "]
                : @"";
            [self recordBackendPreferenceForModelId:targetModelId
                                            backend:[backend isEqualToString:@"gpu"] ? @"gpu" : @"cpu"
                                         gpuAttempted:_gpuAttemptedDuringLastLoad
                                        failureReason:persistedGpuReason];
            BeaconNativeLog(@"engine created successfully with %@", attemptLabel);
            break;
        }
        NSString *failureLog = safeEngineCreateError.length > 0
            ? [NSString stringWithFormat:@"%@ => %@", attemptLabel, safeEngineCreateError]
            : [NSString stringWithFormat:@"%@ => engine-create-null", attemptLabel];
        [attemptLogs addObject:failureLog];
        if ([backend isEqualToString:@"gpu"]) {
            [gpuFailureLogs addObject:failureLog];
        }
        BeaconNativeLog(@"engine init failed for %@ error=%@", attemptLabel, safeEngineCreateError ?: @"(null)");
    }
    _lastEngineAttemptLog = [attemptLogs copy];
    if (gpuFailureLogs.count > 0) {
        _lastGpuFailureMessage = [NSString stringWithFormat:@"GPU attempts failed before %@. %@", createdEngine != NULL ? @"fallback/success" : @"final failure", [gpuFailureLogs componentsJoinedByString:@" | "]];
    }

    if (createdEngine == NULL) {
        NSString *failureMessage = requestedGpuOnly
            ? @"GPU-only validation failed on this iOS runtime. Beacon can still use the real on-device CPU path in default auto-real mode."
            : @"LiteRT-LM failed to initialize Gemma 4 on this iOS runtime.";
        NSError *loadError = [NSError errorWithDomain:@"BeaconNative"
                                                 code:(requestedGpuOnly ? 118 : 102)
                                             userInfo:@{NSLocalizedDescriptionKey: failureMessage}];
        _cachedEngineLoadFailure = loadError;
        _cachedEngineLoadFailureModelId = [failureCacheKey copy];
        _cachedEngineLoadFailureAt = now;
        _lastEngineFailureMessage = [NSString stringWithFormat:@"LiteRT-LM init failed after attempts=%@", [attemptLogs componentsJoinedByString:@" | "]];
        [self recordBackendPreferenceForModelId:targetModelId
                                        backend:@"cpu"
                                     gpuAttempted:_gpuAttemptedDuringLastLoad
                                    failureReason:_lastGpuFailureMessage ?: [gpuFailureLogs componentsJoinedByString:@" | "]];
        if (error != nil) {
            *error = loadError;
        }
        BeaconNativeLog(@"engine load failed: LiteRT-LM could not initialize %@ after attempts=%@",
                        targetModelId,
                        [attemptLogs componentsJoinedByString:@" | "]);
        return NO;
    }

    _engine = createdEngine;
    _loadedModelId = [targetModelId copy];
    _cachedEngineLoadFailure = nil;
    _cachedEngineLoadFailureModelId = nil;
    _cachedEngineLoadFailureAt = 0;
    [[NSUserDefaults standardUserDefaults] setObject:_loadedModelId forKey:kBeaconLoadedModelIdKey];
    BeaconNativeLog(@"engine ready for %@ using file=%@ attempt=%@",
                    _loadedModelId,
                    modelURL.path ?: @"(unknown)",
                    successfulAttempt ?: @"(unknown)");
    return YES;
}

- (BOOL)conversationNeedsResetForSessionId:(NSString *)sessionId
                                 powerMode:(NSString *)powerMode
                            requiresVision:(BOOL)requiresVision
                                    reason:(NSString * __autoreleasing *)reason {
    NSString *computedReason = nil;
    if (_conversation == NULL) {
        computedReason = @"missing-conversation";
    } else if (_activeSessionId == nil || ![_activeSessionId isEqualToString:sessionId]) {
        computedReason = @"session-changed";
    } else if (_activeConversationModelId == nil || ![_activeConversationModelId isEqualToString:_loadedModelId]) {
        computedReason = @"model-changed";
    } else if (_activeConversationPowerMode == nil || ![_activeConversationPowerMode isEqualToString:(powerMode ?: @"normal")]) {
        computedReason = @"power-mode-changed";
    } else if (requiresVision && !_activeConversationRequiresVision) {
        computedReason = @"vision-mode-changed";
    }

    if (reason != nil) {
        *reason = computedReason;
    }
    return computedReason != nil;
}

- (BOOL)prepareConversationForSessionId:(NSString *)sessionId powerMode:(NSString *)powerMode requiresVision:(BOOL)requiresVision error:(NSError **)error {
    NSString *resetReason = nil;
    BOOL needsReset = [self conversationNeedsResetForSessionId:sessionId
                                                     powerMode:powerMode
                                                requiresVision:requiresVision
                                                        reason:&resetReason];

    if (!needsReset && _conversation != NULL) {
        needsReset = YES;
        resetReason = @"conversation reset per turn to keep session memory stable";
    }

    if (!needsReset) {
        BeaconNativeLog(@"reusing conversation session=%@ model=%@", sessionId ?: @"(none)", _loadedModelId ?: @"(none)");
        return YES;
    }

    if (_conversation != NULL) {
        litert_lm_conversation_delete(_conversation);
        _conversation = NULL;
        _activeConversationRequiresVision = NO;
    }
    BeaconNativeLog(@"creating conversation session=%@ powerMode=%@ reason=%@", sessionId ?: @"(none)", powerMode ?: @"normal", resetReason ?: @"unknown");

    LiteRtLmSessionConfig *sessionConfig = litert_lm_session_config_create();
    if (sessionConfig == NULL) {
        if (error != nil) {
            *error = [NSError errorWithDomain:@"BeaconNative" code:103 userInfo:@{NSLocalizedDescriptionKey: @"Failed to create LiteRT-LM session config."}];
        }
        return NO;
    }

    LiteRtLmSamplerParams samplerParams;
    samplerParams.type = kTopP;
    BOOL doomsday = [powerMode isEqualToString:@"doomsday"];
    samplerParams.top_k = requiresVision ? (doomsday ? 32 : 40) : (doomsday ? 36 : 48);
    samplerParams.top_p = requiresVision ? (doomsday ? 0.88f : 0.90f) : (doomsday ? 0.90f : 0.92f);
    samplerParams.temperature = requiresVision ? (doomsday ? 0.35f : 0.45f) : (doomsday ? 0.40f : 0.55f);
    samplerParams.seed = 17;
    litert_lm_session_config_set_sampler_params(sessionConfig, &samplerParams);
    NSString *supportedDeviceClass = BeaconSupportedDeviceClass();
    BOOL conservativeCpuProfile = [_activeBackend isEqualToString:@"cpu"]
        && BeaconUsesConservativeCpuProfileForDeviceClass(supportedDeviceClass);
    NSInteger requestedSessionMaxOutputTokens = 0;
    BOOL hasSessionMaxOutputTokensOverride = BeaconRequestedIntegerValue(kBeaconLiteRtSessionMaxOutputTokensEnvKey,
                                                                        @"sessionMaxOutputTokens",
                                                                        &requestedSessionMaxOutputTokens);
    int sessionMaxOutputTokens = [powerMode isEqualToString:@"doomsday"] ? 96 : 128;
    if (requiresVision) {
        sessionMaxOutputTokens = [powerMode isEqualToString:@"doomsday"] ? 64 : 80;
    }
    if ([_activeBackend isEqualToString:@"cpu"]) {
        sessionMaxOutputTokens = [powerMode isEqualToString:@"doomsday"] ? 80 : 96;
        if (requiresVision) {
            sessionMaxOutputTokens = [powerMode isEqualToString:@"doomsday"] ? 56 : 72;
        }
    }
    if (conservativeCpuProfile) {
        sessionMaxOutputTokens = [powerMode isEqualToString:@"doomsday"] ? 48 : 64;
        if (requiresVision) {
            sessionMaxOutputTokens = [powerMode isEqualToString:@"doomsday"] ? 48 : 64;
        }
    }
    if (hasSessionMaxOutputTokensOverride && requestedSessionMaxOutputTokens > 0) {
        sessionMaxOutputTokens = (int)requestedSessionMaxOutputTokens;
    }
    litert_lm_session_config_set_max_output_tokens(sessionConfig, sessionMaxOutputTokens);
    if (requiresVision) {
        litert_lm_session_config_set_vision_modality_enabled(sessionConfig, true);
    }

    NSString *systemMessage = BeaconJSONString(@{ @"type": @"text", @"text": BeaconSystemInstruction() });
    NSString *safeConversationConfigError = nil;
    LiteRtLmConversationConfig *conversationConfig = BeaconLiteRtSafeConversationConfigCreate(
        _engine,
        sessionConfig,
        systemMessage.UTF8String,
        NULL,
        NULL,
        false,
        &safeConversationConfigError
    );
    litert_lm_session_config_delete(sessionConfig);

    if (conversationConfig == NULL) {
        if (error != nil) {
            NSString *message = safeConversationConfigError.length > 0
                ? safeConversationConfigError
                : @"Failed to create LiteRT-LM conversation config.";
            *error = [NSError errorWithDomain:@"BeaconNative" code:104 userInfo:@{NSLocalizedDescriptionKey: message}];
        }
        BeaconNativeLog(@"conversation config creation failed for session=%@", sessionId ?: @"(none)");
        return NO;
    }

    NSString *safeConversationError = nil;
    LiteRtLmConversation *conversation = BeaconLiteRtSafeConversationCreate(_engine, conversationConfig, &safeConversationError);
    litert_lm_conversation_config_delete(conversationConfig);
    if (conversation == NULL) {
        if (error != nil) {
            NSString *message = safeConversationError.length > 0
                ? safeConversationError
                : @"Failed to create LiteRT-LM conversation.";
            *error = [NSError errorWithDomain:@"BeaconNative" code:105 userInfo:@{NSLocalizedDescriptionKey: message}];
        }
        BeaconNativeLog(@"conversation creation failed for session=%@", sessionId ?: @"(none)");
        return NO;
    }

    _conversation = conversation;
    _activeSessionId = [sessionId copy];
    _activeConversationModelId = [_loadedModelId copy];
    _activeConversationPowerMode = [powerMode copy] ?: @"normal";
    _activeConversationRequiresVision = requiresVision;
    BeaconNativeLog(@"conversation ready session=%@ model=%@", _activeSessionId ?: @"(none)", _activeConversationModelId ?: @"(none)");
    return YES;
}

- (NSString *)generateResponseForRequest:(NSDictionary *)request error:(NSError **)error {
    NSString *requestedModelId = [request[@"modelId"] isKindOfClass:[NSString class]] ? request[@"modelId"] : nil;
    NSString *sessionId = [request[@"sessionId"] isKindOfClass:[NSString class]] ? request[@"sessionId"] : @"default-session";
    NSString *userText = [request[@"userText"] isKindOfClass:[NSString class]] ? request[@"userText"] : @"";
    NSString *locale = [request[@"locale"] isKindOfClass:[NSString class]] ? request[@"locale"] : @"en";
    NSString *powerMode = [request[@"powerMode"] isKindOfClass:[NSString class]] ? request[@"powerMode"] : @"normal";
    NSString *categoryHint = [request[@"categoryHint"] isKindOfClass:[NSString class]] ? request[@"categoryHint"] : nil;
    NSString *groundingContext = [request[@"groundingContext"] isKindOfClass:[NSString class]] ? request[@"groundingContext"] : nil;
    NSString *imageBase64 = BeaconNormalizedBase64Blob([request[@"imageBase64"] isKindOfClass:[NSString class]] ? request[@"imageBase64"] : nil);
    BOOL hasAuthoritativeEvidence = [request[@"hasAuthoritativeEvidence"] respondsToSelector:@selector(boolValue)] ? [request[@"hasAuthoritativeEvidence"] boolValue] : NO;
    BOOL resetContext = [request[@"resetContext"] respondsToSelector:@selector(boolValue)] ? [request[@"resetContext"] boolValue] : NO;
    BOOL requiresVision = imageBase64.length > 0;
    CFAbsoluteTime startedAt = CFAbsoluteTimeGetCurrent();

    BeaconNativeLog(@"inference start session=%@ locale=%@ category=%@ reset=%@ evidence=%@ image=%@ user=%@",
                    sessionId,
                    locale,
                    BeaconTrimmedString(categoryHint ?: @""),
                    resetContext ? @"yes" : @"no",
                    hasAuthoritativeEvidence ? @"yes" : @"no",
                    requiresVision ? @"yes" : @"no",
                    BeaconTruncatedPreview(userText, 100));
    BeaconWriteSmokeProgress(@"inference-entered", @{
        @"sessionId": sessionId ?: @"",
        @"categoryHint": BeaconTrimmedString(categoryHint ?: @"")
    });

    BeaconWriteSmokeProgress(@"engine-load-start", @{
        @"sessionId": sessionId ?: @""
    });
    if (![self ensureEngineLoaded:requestedModelId requiresVision:requiresVision error:error]) {
        BeaconWriteSmokeProgress(@"engine-load-failed", @{
            @"sessionId": sessionId ?: @"",
            @"error": (error != nil && *error != nil) ? ((*error).localizedDescription ?: @"unknown") : @"unknown"
        });
        return nil;
    }
    BeaconWriteSmokeProgress(@"engine-load-ready", @{
        @"sessionId": sessionId ?: @"",
        @"backend": _activeBackend ?: @"",
        @"visionBackend": _activeVisionBackend ?: @""
    });

    if (resetContext && _conversation != NULL) {
        litert_lm_conversation_delete(_conversation);
        _conversation = NULL;
        _activeSessionId = nil;
        _activeConversationModelId = nil;
        _activeConversationPowerMode = nil;
        _activeConversationRequiresVision = NO;
        BeaconNativeLog(@"conversation explicitly reset for session=%@", sessionId);
    }

    BOOL shouldInjectPromptMemory = YES;
    NSDictionary<NSString *, NSString *> *promptMemory = [self promptMemoryForSessionId:sessionId resetContext:resetContext];

    BeaconWriteSmokeProgress(@"conversation-prepare-start", @{
        @"sessionId": sessionId ?: @""
    });
    if (![self prepareConversationForSessionId:sessionId powerMode:powerMode requiresVision:requiresVision error:error]) {
        BeaconWriteSmokeProgress(@"conversation-prepare-failed", @{
            @"sessionId": sessionId ?: @"",
            @"error": (error != nil && *error != nil) ? ((*error).localizedDescription ?: @"unknown") : @"unknown"
        });
        return nil;
    }
    BeaconWriteSmokeProgress(@"conversation-ready", @{
        @"sessionId": sessionId ?: @""
    });

    NSString *prompt = BeaconBuildUserPrompt(locale,
                                             powerMode,
                                             categoryHint,
                                             userText,
                                             groundingContext,
                                             hasAuthoritativeEvidence,
                                             requiresVision,
                                             shouldInjectPromptMemory ? promptMemory[@"sessionSummary"] : nil,
                                             shouldInjectPromptMemory ? promptMemory[@"recentChatContext"] : nil,
                                             shouldInjectPromptMemory ? promptMemory[@"lastVisualContext"] : nil);
    NSString *messageJSONString = BeaconJSONString(@{
        @"role": @"user",
        @"content": BeaconBuildConversationContent(prompt, imageBase64)
    });
    if (messageJSONString.length == 0) {
        if (error != nil) {
            *error = [NSError errorWithDomain:@"BeaconNative" code:106 userInfo:@{NSLocalizedDescriptionKey: @"Failed to encode the Beacon request for LiteRT-LM."}];
        }
        return nil;
    }

    BeaconWriteSmokeProgress(@"send-message-start", @{
        @"sessionId": sessionId ?: @""
    });
    BeaconNativeBlockingStreamContext *streamContext = [BeaconNativeBlockingStreamContext new];
    void *callbackData = (__bridge_retained void *)streamContext;
    NSString *safeStreamError = nil;
    int streamResult = BeaconLiteRtSafeConversationSendMessageStream(_conversation,
                                                                     messageJSONString.UTF8String,
                                                                     NULL,
                                                                     BeaconNativeBlockingStreamCallback,
                                                                     callbackData,
                                                                     &safeStreamError);
    if (streamResult != 0) {
        CFBridgingRelease(callbackData);
        if (error != nil) {
            NSString *message = safeStreamError.length > 0
                ? safeStreamError
                : @"LiteRT-LM could not start a response stream for this emergency turn.";
            *error = [NSError errorWithDomain:@"BeaconNative"
                                         code:107
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }
        BeaconNativeLog(@"inference failed: stream start error session=%@ code=%d detail=%@", sessionId, streamResult, safeStreamError ?: @"");
        return nil;
    }
    BOOL streamCompleted = [streamContext waitForCompletionWithTimeout:(requiresVision ? 75.0 : 30.0)];
    if (!streamCompleted) {
        litert_lm_conversation_cancel_process(_conversation);
        streamCompleted = [streamContext waitForCompletionWithTimeout:2.0];
    }
    NSString *streamError = [streamContext finalError];
    NSString *text = BeaconSanitizeModelText([streamContext accumulatedText]);
    BeaconWriteSmokeProgress(@"send-message-returned", @{
        @"sessionId": sessionId ?: @"",
        @"hasResponse": @(text.length > 0),
        @"streamCompleted": @(streamCompleted),
        @"streamError": streamError ?: @""
    });

    if (!streamCompleted && !BeaconHasMeaningfulModelText(text)) {
        if (error != nil) {
            *error = [NSError errorWithDomain:@"BeaconNative"
                                         code:107
                                     userInfo:@{NSLocalizedDescriptionKey: @"LiteRT-LM timed out before finishing this emergency turn."}];
        }
        BeaconNativeLog(@"inference failed: stream timeout session=%@", sessionId);
        return nil;
    }

    if (!BeaconHasMeaningfulModelText(text)) {
        if (error != nil) {
            NSString *message = streamError.length > 0 ? streamError : @"LiteRT-LM produced an empty response.";
            *error = [NSError errorWithDomain:@"BeaconNative"
                                         code:108
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }
        BeaconNativeLog(@"inference failed: empty response session=%@ error=%@", sessionId, streamError);
        return nil;
    }

    if (streamError.length > 0) {
        BeaconNativeLog(@"inference recovered partial streamed response after terminal error session=%@ error=%@",
                        sessionId,
                        streamError);
    }

    [self rememberSessionMemoryForSessionId:sessionId
                                    modelId:_loadedModelId
                               categoryHint:categoryHint
                                   userText:userText
                               responseText:text
                               isVisualTurn:requiresVision];

    _lastBenchmarkSummary = [self benchmarkSummaryForConversation:_conversation];
    NSTimeInterval elapsedMs = (CFAbsoluteTimeGetCurrent() - startedAt) * 1000.0;
    if (_lastBenchmarkSummary != nil) {
        BeaconNativeLog(@"inference done session=%@ backend=%@ ttftMs=%@ decodeTps=%@ durationMs=%ld response=%@",
                        sessionId,
                        _activeBackend ?: @"unknown",
                        _lastBenchmarkSummary[@"timeToFirstTokenMs"] ?: @(0),
                        _lastBenchmarkSummary[@"lastDecodeTokensPerSecond"] ?: @(0),
                        (long)llround(elapsedMs),
                        BeaconTruncatedPreview(text, 220));
    } else {
        BeaconNativeLog(@"inference done session=%@ durationMs=%ld response=%@",
                        sessionId,
                        (long)llround(elapsedMs),
                        BeaconTruncatedPreview(text, 220));
    }
    [self releaseFinishedConversationWithReason:@"response-complete-sidecar-memory"];
    return text;
}

- (void)listModels:(CAPPluginCall *)call {
    [self bootstrapStateIfNeeded];
    dispatch_async(_workerQueue, ^{
        NSArray<NSDictionary *> *models = [self buildModelArray];
        dispatch_async(dispatch_get_main_queue(), ^{
            [call resolve:@{ @"models": models }];
        });
    });
}

- (void)loadModel:(CAPPluginCall *)call {
    [self bootstrapStateIfNeeded];
    NSString *modelId = [call getString:@"modelId" defaultValue:kBeaconDefaultModelId];
    dispatch_async(_workerQueue, ^{
        NSError *error = nil;
        BOOL loaded = [self ensureEngineLoaded:modelId requiresVision:NO error:&error];
        NSArray<NSDictionary *> *models = [self buildModelArray];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!loaded) {
                [self rejectCall:call message:(error.localizedDescription ?: @"Failed to load bundled Gemma 4 E2B on iOS.") error:error];
                return;
            }
            [call resolve:@{ @"models": models }];
        });
    });
}

- (void)downloadModel:(CAPPluginCall *)call {
    [self bootstrapStateIfNeeded];
    NSString *modelId = [call getString:@"modelId" defaultValue:kBeaconDefaultModelId];
    dispatch_async(_workerQueue, ^{
        NSDictionary *spec = [self modelSpecForId:modelId];
        NSURL *resolvedURL = spec != nil ? [self resolvedModelURLForSpec:spec] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (spec == nil || resolvedURL == nil) {
                [self rejectCall:call message:@"This iOS build currently ships with bundled Gemma 4 E2B only." error:nil];
                return;
            }
            [self notifyListeners:@"modelDownloadProgress" data:@{
                @"modelId": modelId,
                @"receivedBytes": spec[@"sizeInBytes"] ?: @(0),
                @"totalBytes": spec[@"sizeInBytes"] ?: @(0),
                @"fraction": @1,
                @"isResumed": @NO,
                @"status": @"succeeded",
                @"done": @YES
            }];
            [call resolve:@{
                @"modelId": modelId,
                @"localPath": resolvedURL.path ?: @"",
                @"downloaded": @YES
            }];
        });
    });
}

- (void)getRuntimeDiagnostics:(CAPPluginCall *)call {
    [self bootstrapStateIfNeeded];
    dispatch_async(_workerQueue, ^{
        NSDictionary *payload = [self runtimeDiagnosticsPayload];
        dispatch_async(dispatch_get_main_queue(), ^{
            [call resolve:payload];
        });
    });
}

- (void)triage:(CAPPluginCall *)call {
    NSString *userText = [call getString:@"userText" defaultValue:nil];
    if (BeaconTrimmedString(userText ?: @"").length == 0) {
        [self rejectCall:call message:@"userText is required." error:nil];
        return;
    }

    NSDictionary *request = call.options ?: @{};
    dispatch_async(_workerQueue, ^{
        NSError *error = nil;
        NSString *responseText = [self generateResponseForRequest:request error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (responseText.length == 0) {
                [self rejectCall:call message:(error.localizedDescription ?: @"Local model inference failed.") error:error];
                return;
            }
            [call resolve:@{
                @"text": responseText,
                @"modelId": self->_loadedModelId ?: @"",
                @"usedProfileName": [self activeProfileName]
            }];
        });
    });
}

- (void)triageStream:(CAPPluginCall *)call {
    NSString *userText = [call getString:@"userText" defaultValue:nil];
    if (BeaconTrimmedString(userText ?: @"").length == 0) {
        [self rejectCall:call message:@"userText is required." error:nil];
        return;
    }

    NSDictionary *request = call.options ?: @{};
    dispatch_async(_workerQueue, ^{
        NSError *error = nil;
        NSString *requestedModelId = [request[@"modelId"] isKindOfClass:[NSString class]] ? request[@"modelId"] : nil;
        NSString *streamId = [request[@"streamId"] isKindOfClass:[NSString class]] ? request[@"streamId"] : [[NSUUID UUID] UUIDString];
        NSString *sessionId = [request[@"sessionId"] isKindOfClass:[NSString class]] ? request[@"sessionId"] : @"default-session";
        NSString *locale = [request[@"locale"] isKindOfClass:[NSString class]] ? request[@"locale"] : @"en";
        NSString *powerMode = [request[@"powerMode"] isKindOfClass:[NSString class]] ? request[@"powerMode"] : @"normal";
        NSString *categoryHint = [request[@"categoryHint"] isKindOfClass:[NSString class]] ? request[@"categoryHint"] : nil;
        NSString *groundingContext = [request[@"groundingContext"] isKindOfClass:[NSString class]] ? request[@"groundingContext"] : nil;
        NSString *imageBase64 = BeaconNormalizedBase64Blob([request[@"imageBase64"] isKindOfClass:[NSString class]] ? request[@"imageBase64"] : nil);
        BOOL hasAuthoritativeEvidence = [request[@"hasAuthoritativeEvidence"] respondsToSelector:@selector(boolValue)] ? [request[@"hasAuthoritativeEvidence"] boolValue] : NO;
        BOOL resetContext = [request[@"resetContext"] respondsToSelector:@selector(boolValue)] ? [request[@"resetContext"] boolValue] : NO;
        BOOL requiresVision = imageBase64.length > 0;
        CFAbsoluteTime startedAt = CFAbsoluteTimeGetCurrent();

        BeaconNativeLog(@"stream start stream=%@ session=%@ locale=%@ category=%@ reset=%@ evidence=%@ image=%@ user=%@",
                        streamId,
                        sessionId,
                        locale,
                        BeaconTrimmedString(categoryHint ?: @""),
                        resetContext ? @"yes" : @"no",
                        hasAuthoritativeEvidence ? @"yes" : @"no",
                        requiresVision ? @"yes" : @"no",
                        BeaconTruncatedPreview(userText, 100));

        if (![self ensureEngineLoaded:requestedModelId requiresVision:requiresVision error:&error]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self rejectCall:call message:(error.localizedDescription ?: @"Local model inference failed.") error:error];
            });
            return;
        }

        if (resetContext && self->_conversation != NULL) {
            litert_lm_conversation_delete(self->_conversation);
            self->_conversation = NULL;
            self->_activeSessionId = nil;
            self->_activeConversationModelId = nil;
            self->_activeConversationPowerMode = nil;
            self->_activeConversationRequiresVision = NO;
            BeaconNativeLog(@"conversation explicitly reset for stream session=%@", sessionId);
        }

        BOOL shouldInjectPromptMemory = YES;
        NSDictionary<NSString *, NSString *> *promptMemory = [self promptMemoryForSessionId:sessionId resetContext:resetContext];

        if (![self prepareConversationForSessionId:sessionId powerMode:powerMode requiresVision:requiresVision error:&error]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self rejectCall:call message:(error.localizedDescription ?: @"Local model inference failed.") error:error];
            });
            return;
        }

        NSString *prompt = BeaconBuildUserPrompt(locale,
                                                 powerMode,
                                                 categoryHint,
                                                 userText,
                                                 groundingContext,
                                                 hasAuthoritativeEvidence,
                                                 requiresVision,
                                                 shouldInjectPromptMemory ? promptMemory[@"sessionSummary"] : nil,
                                                 shouldInjectPromptMemory ? promptMemory[@"recentChatContext"] : nil,
                                                 shouldInjectPromptMemory ? promptMemory[@"lastVisualContext"] : nil);
        NSString *messageJSONString = BeaconJSONString(@{
            @"role": @"user",
            @"content": BeaconBuildConversationContent(prompt, imageBase64)
        });
        if (messageJSONString.length == 0) {
            NSError *encodingError = [NSError errorWithDomain:@"BeaconNative"
                                                         code:110
                                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to encode the Beacon request for LiteRT-LM streaming."}];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self rejectCall:call message:encodingError.localizedDescription error:encodingError];
            });
            return;
        }

        BeaconNativeStreamContext *context = [[BeaconNativeStreamContext alloc] initWithPlugin:self
                                                                                       streamId:streamId
                                                                                      sessionId:sessionId
                                                                                        modelId:self->_loadedModelId
                                                                                    categoryHint:categoryHint
                                                                                        userText:userText
                                                                                    isVisualTurn:requiresVision
                                                                                      startedAt:startedAt];
        void *callbackData = (__bridge_retained void *)context;
        NSString *safeStreamStartError = nil;
        int streamResult = BeaconLiteRtSafeConversationSendMessageStream(self->_conversation,
                                                                         messageJSONString.UTF8String,
                                                                         NULL,
                                                                         BeaconNativeTriageStreamCallback,
                                                                         callbackData,
                                                                         &safeStreamStartError);
        if (streamResult != 0) {
            CFBridgingRelease(callbackData);
            NSError *streamError = [NSError errorWithDomain:@"BeaconNative"
                                                       code:111
                                                   userInfo:@{NSLocalizedDescriptionKey: safeStreamStartError.length > 0 ? safeStreamStartError : @"LiteRT-LM could not start a streaming response."}];
            BeaconNativeLog(@"stream failed to start stream=%@ session=%@ code=%d",
                            streamId,
                            sessionId,
                            streamResult);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self rejectCall:call message:streamError.localizedDescription error:streamError];
            });
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [call resolve:@{ @"streamId": streamId ?: @"" }];
        });
    });
}

- (void)cancelActiveInference:(CAPPluginCall *)call {
    LiteRtLmConversation *conversation = _conversation;
    BOOL cancelled = NO;

    if (conversation != NULL) {
        litert_lm_conversation_cancel_process(conversation);
        cancelled = YES;
        BeaconNativeLog(@"active inference cancel requested for session=%@", _activeSessionId ?: @"");
    } else {
        BeaconNativeLog(@"active inference cancel requested with no live conversation");
    }

    [call resolve:@{ @"cancelled": @(cancelled) }];
}

- (void)analyzeVisual:(CAPPluginCall *)call {
    NSMutableDictionary *request = [NSMutableDictionary dictionaryWithDictionary:(call.options ?: @{})];
    NSString *imageBase64 = BeaconNormalizedBase64Blob([request[@"imageBase64"] isKindOfClass:[NSString class]] ? request[@"imageBase64"] : nil);
    request[@"userText"] = BeaconResolvedVisualUserText([request[@"userText"] isKindOfClass:[NSString class]] ? request[@"userText"] : nil,
                                                        imageBase64.length > 0);
    dispatch_async(_workerQueue, ^{
        NSError *error = nil;
        NSString *responseText = [self generateResponseForRequest:request error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (responseText.length == 0) {
                [self rejectCall:call message:(error.localizedDescription ?: @"Local visual guidance failed.") error:error];
                return;
            }
            [call resolve:@{
                @"text": responseText,
                @"modelId": self->_loadedModelId ?: @"",
                @"usedProfileName": [self activeProfileName]
            }];
        });
    });
}

@end
