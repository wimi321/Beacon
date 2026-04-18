#import <Foundation/Foundation.h>

// Force the linker to pull in LiteRT-LM's engine registration translation unit
// from the static archive. Without this anchor, the app can reach the C API
// wrapper while the engine factory remains unregistered at runtime.
extern void BeaconLiteRtEngineFactoryRegisterAnchor(void)
    __asm__(
        "__ZN6litert2lm13EngineFactory8RegisterENS1_10EngineTypeEN4absl12lts_2026010712AnyInvocableIFNS4_8StatusOrINSt3__110unique_ptrINS0_6EngineENS7_14default_deleteIS9_EEEEEENS0_14EngineSettingsENS7_17basic_string_viewIcNS7_11char_traitsIcEEEEEEE");

__attribute__((used)) static void *const kBeaconLiteRtLinkAnchor =
    (void *)&BeaconLiteRtEngineFactoryRegisterAnchor;
