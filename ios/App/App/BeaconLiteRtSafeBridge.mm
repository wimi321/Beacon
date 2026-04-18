#import "BeaconLiteRtSafeBridge.h"
#include "engine.h"

#include <exception>
#include <new>

static void BeaconLiteRtAssignError(NSString *_Nullable *_Nullable target, NSString *message) {
    if (target != NULL) {
        *target = message;
    }
}

static NSString *BeaconLiteRtDescribeBadAlloc(const std::bad_alloc &exception) {
    const char *what = exception.what();
    NSString *detail = what != nullptr ? [NSString stringWithUTF8String:what] : nil;
    return detail.length > 0
        ? [NSString stringWithFormat:@"LiteRT-LM threw std::bad_alloc: %@", detail]
        : @"LiteRT-LM threw std::bad_alloc during iOS runtime initialization.";
}

static NSString *BeaconLiteRtDescribeStdException(const std::exception &exception) {
    const char *what = exception.what();
    NSString *detail = what != nullptr ? [NSString stringWithUTF8String:what] : nil;
    return detail.length > 0
        ? [NSString stringWithFormat:@"LiteRT-LM threw a C++ exception: %@", detail]
        : @"LiteRT-LM threw an unknown C++ exception on this iOS runtime.";
}

LiteRtLmEngine *_Nullable BeaconLiteRtSafeEngineCreate(
    const LiteRtLmEngineSettings *_Nullable settings,
    NSString *_Nullable *_Nullable errorMessage) {
    try {
        return litert_lm_engine_create(settings);
    } catch (const std::bad_alloc &exception) {
        BeaconLiteRtAssignError(errorMessage, BeaconLiteRtDescribeBadAlloc(exception));
    } catch (const std::exception &exception) {
        BeaconLiteRtAssignError(errorMessage, BeaconLiteRtDescribeStdException(exception));
    } catch (...) {
        BeaconLiteRtAssignError(errorMessage, @"LiteRT-LM engine initialization crashed with a non-standard exception.");
    }
    return NULL;
}

LiteRtLmConversationConfig *_Nullable BeaconLiteRtSafeConversationConfigCreate(
    LiteRtLmEngine *_Nullable engine,
    const LiteRtLmSessionConfig *_Nullable sessionConfig,
    const char *_Nullable systemMessageJson,
    const char *_Nullable toolsJson,
    const char *_Nullable messagesJson,
    BOOL enableConstrainedDecoding,
    NSString *_Nullable *_Nullable errorMessage) {
    try {
        return litert_lm_conversation_config_create(
            engine,
            sessionConfig,
            systemMessageJson,
            toolsJson,
            messagesJson,
            enableConstrainedDecoding
        );
    } catch (const std::bad_alloc &exception) {
        BeaconLiteRtAssignError(errorMessage, BeaconLiteRtDescribeBadAlloc(exception));
    } catch (const std::exception &exception) {
        BeaconLiteRtAssignError(errorMessage, BeaconLiteRtDescribeStdException(exception));
    } catch (...) {
        BeaconLiteRtAssignError(errorMessage, @"LiteRT-LM conversation config creation crashed with a non-standard exception.");
    }
    return NULL;
}

LiteRtLmConversation *_Nullable BeaconLiteRtSafeConversationCreate(
    LiteRtLmEngine *_Nullable engine,
    LiteRtLmConversationConfig *_Nullable config,
    NSString *_Nullable *_Nullable errorMessage) {
    try {
        return litert_lm_conversation_create(engine, config);
    } catch (const std::bad_alloc &exception) {
        BeaconLiteRtAssignError(errorMessage, BeaconLiteRtDescribeBadAlloc(exception));
    } catch (const std::exception &exception) {
        BeaconLiteRtAssignError(errorMessage, BeaconLiteRtDescribeStdException(exception));
    } catch (...) {
        BeaconLiteRtAssignError(errorMessage, @"LiteRT-LM conversation creation crashed with a non-standard exception.");
    }
    return NULL;
}

int BeaconLiteRtSafeConversationSendMessageStream(
    LiteRtLmConversation *_Nullable conversation,
    const char *_Nullable messageJson,
    const char *_Nullable extraContext,
    LiteRtLmStreamCallback _Nullable callback,
    void *_Nullable callbackData,
    NSString *_Nullable *_Nullable errorMessage) {
    try {
        return litert_lm_conversation_send_message_stream(
            conversation,
            messageJson,
            extraContext,
            callback,
            callbackData
        );
    } catch (const std::bad_alloc &exception) {
        BeaconLiteRtAssignError(errorMessage, BeaconLiteRtDescribeBadAlloc(exception));
    } catch (const std::exception &exception) {
        BeaconLiteRtAssignError(errorMessage, BeaconLiteRtDescribeStdException(exception));
    } catch (...) {
        BeaconLiteRtAssignError(errorMessage, @"LiteRT-LM response streaming crashed with a non-standard exception.");
    }
    return -1;
}
