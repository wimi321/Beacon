#import <Foundation/Foundation.h>
#include <stdbool.h>

typedef struct LiteRtLmEngine LiteRtLmEngine;
typedef struct LiteRtLmEngineSettings LiteRtLmEngineSettings;
typedef struct LiteRtLmSession LiteRtLmSession;
typedef struct LiteRtLmConversation LiteRtLmConversation;
typedef struct LiteRtLmConversationConfig LiteRtLmConversationConfig;
typedef struct LiteRtLmSessionConfig LiteRtLmSessionConfig;
typedef struct LiteRtLmConversationOptionalArgs LiteRtLmConversationOptionalArgs;
typedef void (*LiteRtLmStreamCallback)(
    void *_Nullable callback_data,
    const char *_Nullable chunk,
    bool is_final,
    const char *_Nullable error_msg);

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT LiteRtLmEngine *_Nullable BeaconLiteRtSafeEngineCreate(
    const LiteRtLmEngineSettings *_Nullable settings,
    NSString *_Nullable *_Nullable errorMessage);

FOUNDATION_EXPORT LiteRtLmConversationConfig *_Nullable BeaconLiteRtSafeConversationConfigCreate(
    LiteRtLmEngine *_Nullable engine,
    const LiteRtLmSessionConfig *_Nullable sessionConfig,
    const char *_Nullable systemMessageJson,
    const char *_Nullable toolsJson,
    const char *_Nullable messagesJson,
    BOOL enableConstrainedDecoding,
    NSString *_Nullable *_Nullable errorMessage);

FOUNDATION_EXPORT LiteRtLmConversation *_Nullable BeaconLiteRtSafeConversationCreate(
    LiteRtLmEngine *_Nullable engine,
    LiteRtLmConversationConfig *_Nullable config,
    NSString *_Nullable *_Nullable errorMessage);

FOUNDATION_EXPORT LiteRtLmSession *_Nullable BeaconLiteRtSafeEngineCreateSession(
    LiteRtLmEngine *_Nullable engine,
    LiteRtLmSessionConfig *_Nullable config,
    NSString *_Nullable *_Nullable errorMessage);

FOUNDATION_EXPORT int BeaconLiteRtSafeSessionGenerateTextStream(
    LiteRtLmSession *_Nullable session,
    const char *_Nullable inputText,
    LiteRtLmStreamCallback _Nullable callback,
    void *_Nullable callbackData,
    NSString *_Nullable *_Nullable errorMessage);

FOUNDATION_EXPORT int BeaconLiteRtSafeConversationSendMessageStream(
    LiteRtLmConversation *_Nullable conversation,
    const char *_Nullable messageJson,
    const char *_Nullable extraContext,
    int visualTokenBudget,
    LiteRtLmStreamCallback _Nullable callback,
    void *_Nullable callbackData,
    NSString *_Nullable *_Nullable errorMessage);

NS_ASSUME_NONNULL_END
