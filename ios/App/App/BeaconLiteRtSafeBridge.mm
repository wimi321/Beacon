#import "BeaconLiteRtSafeBridge.h"
#include "engine.h"

#include <exception>
#include <cstring>
#include <dlfcn.h>
#include <new>

typedef LiteRtLmEngine *_Nullable (*BeaconLiteRtEngineCreateWithErrorFn)(
    const LiteRtLmEngineSettings *_Nullable settings,
    char *_Nullable error_buffer,
    size_t error_buffer_size);
typedef LiteRtLmConversation *_Nullable (*BeaconLiteRtConversationCreateWithErrorFn)(
    LiteRtLmEngine *_Nullable engine,
    LiteRtLmConversationConfig *_Nullable config,
    char *_Nullable error_buffer,
    size_t error_buffer_size);

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
        BeaconLiteRtEngineCreateWithErrorFn createWithError =
            reinterpret_cast<BeaconLiteRtEngineCreateWithErrorFn>(
                dlsym(RTLD_DEFAULT, "litert_lm_engine_create_with_error")
            );
        if (createWithError != nullptr) {
            char errorBuffer[4096] = {0};
            LiteRtLmEngine *engine = createWithError(settings, errorBuffer, sizeof(errorBuffer));
            if (engine == nullptr && errorBuffer[0] != '\0') {
                BeaconLiteRtAssignError(
                    errorMessage,
                    [NSString stringWithFormat:@"LiteRT-LM engine creation failed: %s", errorBuffer]
                );
            }
            return engine;
        }
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
    (void)engine;
    try {
        LiteRtLmConversationConfig *config = litert_lm_conversation_config_create();
        if (config == NULL) {
            return NULL;
        }
        if (sessionConfig != NULL) {
            litert_lm_conversation_config_set_session_config(config, sessionConfig);
        }
        if (systemMessageJson != NULL && std::strlen(systemMessageJson) > 0) {
            litert_lm_conversation_config_set_system_message(config, systemMessageJson);
        }
        if (toolsJson != NULL && std::strlen(toolsJson) > 0) {
            litert_lm_conversation_config_set_tools(config, toolsJson);
        }
        if (messagesJson != NULL && std::strlen(messagesJson) > 0) {
            litert_lm_conversation_config_set_messages(config, messagesJson);
        }
        litert_lm_conversation_config_set_enable_constrained_decoding(
            config,
            enableConstrainedDecoding
        );
        return config;
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
        BeaconLiteRtConversationCreateWithErrorFn createWithError =
            reinterpret_cast<BeaconLiteRtConversationCreateWithErrorFn>(
                dlsym(RTLD_DEFAULT, "litert_lm_conversation_create_with_error")
            );
        if (createWithError != nullptr) {
            char errorBuffer[4096] = {0};
            LiteRtLmConversation *conversation = createWithError(
                engine,
                config,
                errorBuffer,
                sizeof(errorBuffer)
            );
            if (conversation == nullptr && errorBuffer[0] != '\0') {
                BeaconLiteRtAssignError(
                    errorMessage,
                    [NSString stringWithFormat:@"LiteRT-LM conversation creation failed: %s", errorBuffer]
                );
            }
            return conversation;
        }
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

LiteRtLmSession *_Nullable BeaconLiteRtSafeEngineCreateSession(
    LiteRtLmEngine *_Nullable engine,
    LiteRtLmSessionConfig *_Nullable config,
    NSString *_Nullable *_Nullable errorMessage) {
    try {
        return litert_lm_engine_create_session(engine, config);
    } catch (const std::bad_alloc &exception) {
        BeaconLiteRtAssignError(errorMessage, BeaconLiteRtDescribeBadAlloc(exception));
    } catch (const std::exception &exception) {
        BeaconLiteRtAssignError(errorMessage, BeaconLiteRtDescribeStdException(exception));
    } catch (...) {
        BeaconLiteRtAssignError(errorMessage, @"LiteRT-LM text session creation crashed with a non-standard exception.");
    }
    return NULL;
}

int BeaconLiteRtSafeSessionGenerateTextStream(
    LiteRtLmSession *_Nullable session,
    const char *_Nullable inputText,
    LiteRtLmStreamCallback _Nullable callback,
    void *_Nullable callbackData,
    NSString *_Nullable *_Nullable errorMessage) {
    try {
        if (inputText == NULL) {
            BeaconLiteRtAssignError(errorMessage, @"LiteRT-LM text session received an empty prompt pointer.");
            return -1;
        }
        LiteRtLmInputData input;
        input.type = kLiteRtLmInputDataTypeText;
        input.data = inputText;
        input.size = std::strlen(inputText);
        return litert_lm_session_generate_content_stream(
            session,
            &input,
            1,
            callback,
            callbackData
        );
    } catch (const std::bad_alloc &exception) {
        BeaconLiteRtAssignError(errorMessage, BeaconLiteRtDescribeBadAlloc(exception));
    } catch (const std::exception &exception) {
        BeaconLiteRtAssignError(errorMessage, BeaconLiteRtDescribeStdException(exception));
    } catch (...) {
        BeaconLiteRtAssignError(errorMessage, @"LiteRT-LM text streaming crashed with a non-standard exception.");
    }
    return -1;
}

int BeaconLiteRtSafeConversationSendMessageStream(
    LiteRtLmConversation *_Nullable conversation,
    const char *_Nullable messageJson,
    const char *_Nullable extraContext,
    int visualTokenBudget,
    LiteRtLmStreamCallback _Nullable callback,
    void *_Nullable callbackData,
    NSString *_Nullable *_Nullable errorMessage) {
    try {
        LiteRtLmConversationOptionalArgs *optionalArgs = litert_lm_conversation_optional_args_create();
        if (optionalArgs != NULL && visualTokenBudget > 0) {
            litert_lm_conversation_optional_args_set_visual_token_budget(optionalArgs, visualTokenBudget);
        }
        int status = litert_lm_conversation_send_message_stream(
            conversation,
            messageJson,
            extraContext,
            optionalArgs,
            callback,
            callbackData
        );
        if (optionalArgs != NULL) {
            litert_lm_conversation_optional_args_delete(optionalArgs);
        }
        return status;
    } catch (const std::bad_alloc &exception) {
        BeaconLiteRtAssignError(errorMessage, BeaconLiteRtDescribeBadAlloc(exception));
    } catch (const std::exception &exception) {
        BeaconLiteRtAssignError(errorMessage, BeaconLiteRtDescribeStdException(exception));
    } catch (...) {
        BeaconLiteRtAssignError(errorMessage, @"LiteRT-LM response streaming crashed with a non-standard exception.");
    }
    return -1;
}
