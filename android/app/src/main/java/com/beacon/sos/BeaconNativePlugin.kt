package com.beacon.sos

import android.content.Context
import android.content.SharedPreferences
import android.util.Base64
import android.util.Log
import com.getcapacitor.JSArray
import com.getcapacitor.JSObject
import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginMethod
import com.getcapacitor.annotation.CapacitorPlugin
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.BenchmarkInfo
import com.google.ai.edge.litertlm.Content
import com.google.ai.edge.litertlm.Conversation
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.ExperimentalApi
import com.google.ai.edge.litertlm.Message
import com.google.ai.edge.litertlm.MessageCallback
import com.google.ai.edge.litertlm.SamplerConfig
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.OptIn

@CapacitorPlugin(name = "BeaconNative")
class BeaconNativePlugin : Plugin() {
    private val logTag = "BeaconNative"
    private val bundledModelsAssetDir = "models"
    private val progressNotifyStepBytes = 8L * 1024L * 1024L
    private val modelControlCharsRegex = Regex("[\\u0000-\\u0008\\u000B\\u000C\\u000E-\\u001F\\u007F]")

    private data class ModelSpec(
        val id: String,
        val tier: String,
        val name: String,
        val fileName: String,
        val sizeLabel: String,
        val downloadUrl: String,
        val sizeInBytes: Long,
        val defaultProfileName: String?,
        val recommendedFor: String?,
        val supportsImageInput: Boolean,
        val accelerators: List<String>,
    )

    private data class SessionRuntime(
        val sessionId: String,
        val modelId: String,
        val conversation: Conversation,
        val completedTurns: Int = 0,
        val estimatedChars: Int = 0,
    )

    private data class PreparedSessionRuntime(
        val runtime: SessionRuntime,
        val promptMemory: BeaconPromptMemoryContext,
        val shouldInjectPromptMemory: Boolean,
    )

    private data class PreparedStreamTurn(
        val runtime: SessionRuntime,
        val effectiveModelId: String,
        val promptMemory: BeaconPromptMemoryContext,
        val shouldInjectPromptMemory: Boolean,
        val promptChars: Int,
    )

    private val executor = Executors.newSingleThreadExecutor()
    private val runtimeLock = Any()
    @Volatile
    private var modelCatalog: List<ModelSpec> = emptyList()

    private lateinit var prefs: SharedPreferences
    private var engine: Engine? = null
    private var loadedModelId: String? = null
    private var activeSession: SessionRuntime? = null
    private var activeBackendName: String = "uninitialized"
    private var activeVisionBackendName: String? = null
    private var lastEngineAttempt: String? = null
    private var lastEngineFailure: String? = null
    private var lastBenchmarkInfo: BenchmarkInfo? = null
    private var sessionMemory: BeaconSessionMemory? = null

    override fun load() {
        super.load()
        prefs = context.getSharedPreferences("beacon-native", Context.MODE_PRIVATE)
        loadedModelId = prefs.getString("loadedModelId", null)
        ensureModelCatalogLoaded()
        refreshAllowlistInBackground()
        executor.execute {
            try {
                ensureEngineLoaded(requestedModelId = null, forceReload = false)
            } catch (error: Exception) {
                Log.w(logTag, "Warm start skipped. A bundled or downloaded model is not ready yet.", error)
            }
        }
        Log.i(logTag, "Plugin loaded. persistedModelId=$loadedModelId")
    }

    @PluginMethod
    fun listModels(call: PluginCall) {
        try {
            call.resolve(JSObject().apply {
                put("models", buildModelArray())
            })
        } catch (error: Exception) {
            call.reject("Failed to list local models.", error)
        }
    }

    @PluginMethod
    fun loadModel(call: PluginCall) {
        val modelId = call.getString("modelId")
        if (modelId.isNullOrBlank()) {
            call.reject("modelId is required.")
            return
        }

        executor.execute {
            try {
                Log.i(logTag, "Explicit model load requested. modelId=$modelId")
                ensureEngineLoaded(modelId, forceReload = false)
                call.resolve(JSObject().apply {
                    put("models", buildModelArray())
                })
            } catch (error: Exception) {
                call.reject("Failed to load local model $modelId.", error)
            }
        }
    }

    @PluginMethod
    fun getRuntimeDiagnostics(call: PluginCall) {
        try {
            call.resolve(buildRuntimeDiagnostics())
        } catch (error: Exception) {
            call.reject("Failed to collect runtime diagnostics.", error)
        }
    }

    @PluginMethod
    fun downloadModel(call: PluginCall) {
        val modelId = call.getString("modelId")
        if (modelId.isNullOrBlank()) {
            call.reject("modelId is required.")
            return
        }

        val spec = currentModelCatalog().find { it.id == modelId }
        if (spec == null) {
            call.reject("Unknown model: $modelId")
            return
        }

        executor.execute {
            try {
                val existingLocal = resolveExistingModelFile(spec)
                if (existingLocal != null) {
                    Log.i(
                        logTag,
                        "Model already present. Skipping download for modelId=${spec.id} path=${existingLocal.absolutePath} bytes=${existingLocal.length()}"
                    )
                    notifyDownloadProgress(
                        spec.id,
                        BeaconDownloadEstimator().sample(
                            receivedBytes = existingLocal.length(),
                            totalBytes = existingLocal.length(),
                            isResumed = false,
                            status = BeaconDownloadStatus.SUCCEEDED,
                            done = true,
                        ),
                    )
                    call.resolve(JSObject().apply {
                        put("modelId", spec.id)
                        put("localPath", existingLocal.absolutePath)
                        put("downloaded", true)
                    })
                    return@execute
                }

                seedBundledModelIfAvailable(spec)?.let { bundledFile ->
                    call.resolve(JSObject().apply {
                        put("modelId", spec.id)
                        put("localPath", bundledFile.absolutePath)
                        put("downloaded", true)
                    })
                    return@execute
                }

                val estimator = BeaconDownloadEstimator()
                val files = resolveModelFiles(spec)
                finalizeCompletedPartialIfNeeded(files)?.let { existing ->
                    Log.i(
                        logTag,
                        "Model already present. Skipping download for modelId=${spec.id} path=${existing.absolutePath} bytes=${existing.length()}"
                    )
                    notifyDownloadProgress(
                        spec.id,
                        estimator.sample(
                            receivedBytes = existing.length(),
                            totalBytes = existing.length(),
                            isResumed = false,
                            status = BeaconDownloadStatus.SUCCEEDED,
                            done = true,
                        ),
                    )
                    call.resolve(JSObject().apply {
                        put("modelId", spec.id)
                        put("localPath", existing.absolutePath)
                        put("downloaded", true)
                    })
                    return@execute
                }

                val modelFile = files.primaryFile
                modelFile.parentFile?.mkdirs()
                val tempFile = files.partialFile
                if (!tempFile.exists()) {
                    files.resumableFile?.let { resumable ->
                        if (!BeaconModelFiles.replaceFile(resumable, tempFile)) {
                            throw IllegalStateException("Failed to prepare partial model file for resume: ${spec.id}")
                        }
                        Log.i(
                            logTag,
                            "Prepared resumable partial file for modelId=${spec.id} source=${resumable.absolutePath} bytes=${tempFile.length()}"
                        )
                    }
                }
                var existingBytes = if (tempFile.exists()) tempFile.length() else 0L
                Log.i(
                    logTag,
                    "Starting model download. modelId=${spec.id} target=${modelFile.absolutePath} resumeBytes=$existingBytes"
                )
                var connection = openDownloadConnection(spec.downloadUrl, existingBytes)
                if (existingBytes > 0L && connection.responseCode != HttpURLConnection.HTTP_PARTIAL) {
                    Log.w(
                        logTag,
                        "Server ignored resume request for modelId=${spec.id}; restarting download from byte 0."
                    )
                    connection.disconnect()
                    tempFile.delete()
                    existingBytes = 0L
                    connection = openDownloadConnection(spec.downloadUrl, existingBytes)
                }
                val expectedBytes = resolveExpectedBytes(connection, existingBytes).coerceAtLeast(spec.sizeInBytes)
                val isResumed = existingBytes > 0L && connection.responseCode == HttpURLConnection.HTTP_PARTIAL

                if (isResumed) {
                    notifyDownloadProgress(
                        spec.id,
                        estimator.sample(
                            receivedBytes = existingBytes,
                            totalBytes = expectedBytes,
                            isResumed = true,
                            status = BeaconDownloadStatus.PARTIALLY_DOWNLOADED,
                        ),
                    )
                }

                connection.inputStream.use { input ->
                    FileOutputStream(tempFile, isResumed).use { output ->
                        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                        var receivedBytes = existingBytes
                        var lastNotifiedBytes = existingBytes
                        var lastNotifiedAt = System.currentTimeMillis()
                        while (true) {
                            val read = input.read(buffer)
                            if (read <= 0) {
                                break
                            }
                            output.write(buffer, 0, read)
                            receivedBytes += read.toLong()
                            if (shouldNotifyProgress(receivedBytes, lastNotifiedBytes, lastNotifiedAt)) {
                                notifyDownloadProgress(
                                    spec.id,
                                    estimator.sample(
                                        receivedBytes = receivedBytes,
                                        totalBytes = expectedBytes,
                                        isResumed = isResumed,
                                        status = BeaconDownloadStatus.IN_PROGRESS,
                                    ),
                                )
                                lastNotifiedBytes = receivedBytes
                                lastNotifiedAt = System.currentTimeMillis()
                            }
                        }
                    }
                }

                if (modelFile.exists()) {
                    modelFile.delete()
                }
                if (!BeaconModelFiles.replaceFile(tempFile, modelFile)) {
                    throw IllegalStateException("Failed to finalize downloaded model file for ${spec.id}.")
                }
                Log.i(
                    logTag,
                    "Model download finished. modelId=${spec.id} path=${modelFile.absolutePath} bytes=${modelFile.length()}"
                )
                notifyDownloadProgress(
                    spec.id,
                    estimator.sample(
                        receivedBytes = modelFile.length(),
                        totalBytes = modelFile.length(),
                        isResumed = isResumed,
                        status = BeaconDownloadStatus.SUCCEEDED,
                        done = true,
                    ),
                )
                call.resolve(JSObject().apply {
                    put("modelId", spec.id)
                    put("localPath", modelFile.absolutePath)
                    put("downloaded", true)
                })
            } catch (error: Exception) {
                Log.e(logTag, "Model download failed for modelId=${spec.id}", error)
                val partialBytes = File(File(modelsDir(), spec.fileName).absolutePath + ".part")
                    .takeIf { it.exists() }
                    ?.length()
                    ?: 0L
                notifyDownloadProgress(
                    spec.id,
                    BeaconDownloadEstimator().sample(
                        receivedBytes = partialBytes,
                        totalBytes = spec.sizeInBytes,
                        isResumed = partialBytes > 0L,
                        status = BeaconDownloadStatus.FAILED,
                        errorMessage = error.message ?: "Unknown download error",
                        done = true,
                    ),
                )
                call.reject("Failed to download model ${spec.id}.", error)
            }
        }
    }

    @PluginMethod
    fun triage(call: PluginCall) {
        val userText = call.getString("userText")
        if (userText.isNullOrBlank()) {
            call.reject("userText is required.")
            return
        }

        executor.execute {
            try {
                Log.i(
                    logTag,
                    "Triage request received. requestedModelId=${call.getString("modelId")} sessionId=${call.getString("sessionId") ?: "default-session"} locale=${call.getString("locale") ?: "en"} resetContext=${call.getBoolean("resetContext", false) ?: false}"
                )
                val responseText = generateResponse(
                    modelId = call.getString("modelId"),
                    sessionId = call.getString("sessionId") ?: "default-session",
                    resetContext = call.getBoolean("resetContext", false) ?: false,
                    userText = userText,
                    locale = call.getString("locale") ?: "en",
                    powerMode = call.getString("powerMode") ?: "normal",
                    categoryHint = call.getString("categoryHint"),
                    groundingContext = call.getString("groundingContext"),
                    hasAuthoritativeEvidence = call.getBoolean("hasAuthoritativeEvidence", false) ?: false,
                    imageBase64 = call.getString("imageBase64"),
                )
                Log.i(
                    logTag,
                    "Triage complete. activeModelId=${loadedModelId ?: ""} responseChars=${responseText.length}"
                )
                call.resolve(JSObject().apply {
                    put("text", responseText)
                    put("modelId", loadedModelId ?: "")
                    put("usedProfileName", activeModelName())
                })
            } catch (error: Exception) {
                call.reject("Local model inference failed.", error)
            }
        }
    }

    @PluginMethod
    fun triageStream(call: PluginCall) {
        val userText = call.getString("userText")
        if (userText.isNullOrBlank()) {
            call.reject("userText is required.")
            return
        }

        val streamId = call.getString("streamId")
        if (streamId.isNullOrBlank()) {
            call.reject("streamId is required.")
            return
        }

        val requestedModelId = call.getString("modelId")
        val sessionId = call.getString("sessionId") ?: "default-session"
        val locale = call.getString("locale") ?: "en"
        val resetContext = call.getBoolean("resetContext", false) ?: false
        val powerMode = call.getString("powerMode") ?: "normal"
        val categoryHint = call.getString("categoryHint")
        val groundingContext = call.getString("groundingContext")
        val hasAuthoritativeEvidence = call.getBoolean("hasAuthoritativeEvidence", false) ?: false
        val imageBase64 = call.getString("imageBase64")

        call.resolve(
            JSObject().apply {
                put("streamId", streamId)
            },
        )

        executor.execute {
            try {
                Log.i(
                    logTag,
                    "Triage stream request received. requestedModelId=$requestedModelId sessionId=$sessionId locale=$locale resetContext=$resetContext streamId=$streamId"
                )
                val responseText = generateResponseStream(
                    modelId = requestedModelId,
                    sessionId = sessionId,
                    resetContext = resetContext,
                    userText = userText,
                    locale = locale,
                    powerMode = powerMode,
                    categoryHint = categoryHint,
                    groundingContext = groundingContext,
                    hasAuthoritativeEvidence = hasAuthoritativeEvidence,
                    imageBase64 = imageBase64,
                    streamId = streamId,
                )
                Log.i(
                    logTag,
                    "Triage stream complete. activeModelId=${loadedModelId ?: ""} responseChars=${responseText.length} streamId=$streamId"
                )
            } catch (error: Exception) {
                Log.e(logTag, "Triage stream failed. streamId=$streamId", error)
                notifyTriageStreamCompletion(
                    streamId = streamId,
                    errorMessage = error.message ?: "Local model inference failed.",
                )
            }
        }
    }

    @PluginMethod
    fun cancelActiveInference(call: PluginCall) {
        try {
            val cancelled = synchronized(runtimeLock) {
                val conversation = activeSession?.conversation
                if (conversation != null) {
                    conversation.cancelProcess()
                    true
                } else {
                    false
                }
            }

            Log.i(logTag, "Active inference cancel requested. cancelled=$cancelled")
            call.resolve(
                JSObject().apply {
                    put("cancelled", cancelled)
                },
            )
        } catch (error: Exception) {
            call.reject("Failed to cancel active inference.", error)
        }
    }

    @PluginMethod
    fun analyzeVisual(call: PluginCall) {
        val userText = call.getString("userText")
        if (userText.isNullOrBlank()) {
            call.reject("userText is required.")
            return
        }

        executor.execute {
            try {
                Log.i(
                    logTag,
                    "Visual assistance request received. requestedModelId=${call.getString("modelId")} sessionId=${call.getString("sessionId") ?: "default-session"} locale=${call.getString("locale") ?: "en"} resetContext=${call.getBoolean("resetContext", false) ?: false}"
                )
                val responseText = generateResponse(
                    modelId = call.getString("modelId"),
                    sessionId = call.getString("sessionId") ?: "default-session",
                    resetContext = call.getBoolean("resetContext", false) ?: false,
                    userText = userText,
                    locale = call.getString("locale") ?: "en",
                    powerMode = call.getString("powerMode") ?: "normal",
                    categoryHint = call.getString("categoryHint"),
                    groundingContext = call.getString("groundingContext"),
                    hasAuthoritativeEvidence = call.getBoolean("hasAuthoritativeEvidence", false) ?: false,
                    imageBase64 = call.getString("imageBase64"),
                )
                Log.i(
                    logTag,
                    "Visual assistance complete. activeModelId=${loadedModelId ?: ""} responseChars=${responseText.length}"
                )
                call.resolve(JSObject().apply {
                    put("text", responseText)
                    put("modelId", loadedModelId ?: "")
                    put("usedProfileName", activeModelName())
                })
            } catch (error: Exception) {
                call.reject("Local visual guidance failed.", error)
            }
        }
    }

    @OptIn(ExperimentalApi::class)
    private fun generateResponse(
        modelId: String?,
        sessionId: String,
        resetContext: Boolean,
        userText: String,
        locale: String,
        powerMode: String,
        categoryHint: String?,
        groundingContext: String?,
        hasAuthoritativeEvidence: Boolean,
        imageBase64: String?,
        allowDegenerateRetry: Boolean = true,
    ): String {
        val engineInstance = ensureEngineLoaded(modelId, forceReload = false)
        val normalizedImageBase64 = normalizeBase64Blob(imageBase64)
        val requiresVision = normalizedImageBase64 != null
        val pendingPromptChars = BeaconPromptComposer.estimateConversationBudgetChars(
            userText = userText,
            groundingContext = groundingContext,
            hasImage = requiresVision,
        )

        synchronized(runtimeLock) {
            val effectiveModelId = loadedModelId.orEmpty()
            val prepared = prepareConversationSession(
                engineInstance = engineInstance,
                sessionId = sessionId,
                resetContext = resetContext,
                pendingPromptChars = pendingPromptChars,
                powerMode = powerMode,
                requiresVision = requiresVision,
            )
            val runtime = prepared.runtime
            val promptChars = BeaconPromptComposer.estimateConversationBudgetChars(
                userText = userText,
                groundingContext = groundingContext,
                hasImage = requiresVision,
            )
            val prompt = BeaconPromptComposer.buildUserPrompt(
                BeaconPromptTurn(
                    locale = locale,
                    powerMode = powerMode,
                    categoryHint = categoryHint,
                    userText = userText,
                    groundingContext = groundingContext,
                    hasAuthoritativeEvidence = hasAuthoritativeEvidence,
                    sessionSummary = prepared.promptMemory.sessionSummary.takeIf { prepared.shouldInjectPromptMemory },
                    recentChatContext = prepared.promptMemory.recentChatContext.takeIf { prepared.shouldInjectPromptMemory },
                    lastVisualContext = prepared.promptMemory.lastVisualContext.takeIf { prepared.shouldInjectPromptMemory },
                    hasImage = requiresVision,
                ),
            )

            val responseText = runtime.conversation.sendMessage(
                buildRequestContents(prompt, normalizedImageBase64),
                emptyMap<String, Any>(),
            ).contents.toString().let(::sanitizeModelText)

            if (shouldRetryDegenerateResponse(responseText, locale) && allowDegenerateRetry) {
                Log.w(
                    logTag,
                    "Detected degenerate response for session=$sessionId locale=$locale text=${responseText.take(40)}; retrying with a fresh conversation."
                )
                resetActiveConversation(runtime)
                return generateResponse(
                    modelId = modelId,
                    sessionId = sessionId,
                    resetContext = resetContext,
                    userText = userText,
                    locale = locale,
                    powerMode = powerMode,
                    categoryHint = categoryHint,
                    groundingContext = groundingContext,
                    hasAuthoritativeEvidence = hasAuthoritativeEvidence,
                    imageBase64 = normalizedImageBase64,
                    allowDegenerateRetry = false,
                )
            }

            val benchmarkInfo = runCatching { runtime.conversation.getBenchmarkInfo() }.getOrNull()
            lastBenchmarkInfo = benchmarkInfo
            rememberConversationProgress(
                runtime = runtime,
                promptChars = promptChars,
                responseText = responseText,
            )
            rememberTurnCarryover(
                sessionId = sessionId,
                modelId = effectiveModelId,
                categoryHint = categoryHint,
                userText = userText,
                responseText = responseText,
                isVisualTurn = requiresVision,
            )
            if (benchmarkInfo != null) {
                Log.i(
                    logTag,
                    "Inference benchmark session=$sessionId backend=${activeBackendName} ttftMs=${(benchmarkInfo.timeToFirstTokenInSecond * 1000.0).toInt()} decodeTps=${"%.2f".format(benchmarkInfo.lastDecodeTokensPerSecond)} responseChars=${responseText.length}"
                )
            }
            releaseFinishedConversation(
                runtime = runtime,
                reason = "response-complete-sidecar-memory",
            )
            return responseText
        }
    }

    @OptIn(ExperimentalApi::class)
    private fun generateResponseStream(
        modelId: String?,
        sessionId: String,
        resetContext: Boolean,
        userText: String,
        locale: String,
        powerMode: String,
        categoryHint: String?,
        groundingContext: String?,
        hasAuthoritativeEvidence: Boolean,
        imageBase64: String?,
        streamId: String,
        allowDegenerateRetry: Boolean = true,
    ): String {
        val engineInstance = ensureEngineLoaded(modelId, forceReload = false)
        val normalizedImageBase64 = normalizeBase64Blob(imageBase64)
        val requiresVision = normalizedImageBase64 != null
        val pendingPromptChars = BeaconPromptComposer.estimateConversationBudgetChars(
            userText = userText,
            groundingContext = groundingContext,
            hasImage = requiresVision,
        )
        val preparedTurn = synchronized(runtimeLock) {
            val loadedModel = loadedModelId.orEmpty()
            val prepared = prepareConversationSession(
                engineInstance = engineInstance,
                sessionId = sessionId,
                resetContext = resetContext,
                pendingPromptChars = pendingPromptChars,
                powerMode = powerMode,
                requiresVision = requiresVision,
            )
            PreparedStreamTurn(
                runtime = prepared.runtime,
                effectiveModelId = loadedModel,
                promptMemory = prepared.promptMemory,
                shouldInjectPromptMemory = prepared.shouldInjectPromptMemory,
                promptChars = BeaconPromptComposer.estimateConversationBudgetChars(
                    userText = userText,
                    groundingContext = groundingContext,
                    hasImage = requiresVision,
                ),
            )
        }
        val runtime = preparedTurn.runtime
        val effectiveModelId = preparedTurn.effectiveModelId
        val promptMemory = preparedTurn.promptMemory
        val shouldInjectPromptMemory = preparedTurn.shouldInjectPromptMemory
        val promptChars = preparedTurn.promptChars

        val prompt = BeaconPromptComposer.buildUserPrompt(
            BeaconPromptTurn(
                locale = locale,
                powerMode = powerMode,
                categoryHint = categoryHint,
                userText = userText,
                groundingContext = groundingContext,
                hasAuthoritativeEvidence = hasAuthoritativeEvidence,
                sessionSummary = promptMemory.sessionSummary.takeIf { shouldInjectPromptMemory },
                recentChatContext = promptMemory.recentChatContext.takeIf { shouldInjectPromptMemory },
                lastVisualContext = promptMemory.lastVisualContext.takeIf { shouldInjectPromptMemory },
                hasImage = requiresVision,
            ),
        )
        val requestContents = buildRequestContents(prompt, normalizedImageBase64)
        val doneSignal = CountDownLatch(1)
        val stateLock = Any()
        val fullText = StringBuilder()
        val snapshotText = StringBuilder()
        var failure: Throwable? = null

        runtime.conversation.sendMessageAsync(
            requestContents,
            object : MessageCallback {
                override fun onMessage(message: Message) {
                    val nextText = sanitizeModelText(message.contents.toString())
                    if (!hasMeaningfulModelText(nextText)) {
                        return
                    }

                    val delta = synchronized(stateLock) {
                        updateStreamText(
                            snapshotText = snapshotText,
                            fullText = fullText,
                            nextText = nextText,
                        )
                    }

                    if (delta.isNotEmpty()) {
                        notifyTriageStreamDelta(streamId, delta)
                    }
                }

                override fun onDone() {
                    doneSignal.countDown()
                }

                override fun onError(throwable: Throwable) {
                    failure = throwable
                    doneSignal.countDown()
                }
            },
            emptyMap<String, Any>(),
        )

        if (!doneSignal.await(10, TimeUnit.MINUTES)) {
            runtime.conversation.cancelProcess()
            throw IllegalStateException("Local model inference timed out.")
        }

        failure?.let { throw it }

        val responseText = synchronized(stateLock) {
            sanitizeModelText(fullText.toString()).ifEmpty {
                sanitizeModelText(snapshotText.toString())
            }
        }
        if (!hasMeaningfulModelText(responseText)) {
            throw IllegalStateException("Local model inference failed.")
        }

        if (shouldRetryDegenerateResponse(responseText, locale) && allowDegenerateRetry) {
            Log.w(
                logTag,
                "Detected degenerate streamed response for session=$sessionId locale=$locale text=${responseText.take(40)}; retrying with a fresh conversation."
            )
            synchronized(runtimeLock) {
                resetActiveConversation(runtime)
            }
            return generateResponseStream(
                modelId = modelId,
                sessionId = sessionId,
                resetContext = resetContext,
                userText = userText,
                locale = locale,
                powerMode = powerMode,
                categoryHint = categoryHint,
                groundingContext = groundingContext,
                hasAuthoritativeEvidence = hasAuthoritativeEvidence,
                imageBase64 = normalizedImageBase64,
                streamId = streamId,
                allowDegenerateRetry = false,
            )
        }

        synchronized(runtimeLock) {
            rememberConversationProgress(
                runtime = runtime,
                promptChars = promptChars,
                responseText = responseText,
            )
            rememberTurnCarryover(
                sessionId = sessionId,
                modelId = effectiveModelId,
                categoryHint = categoryHint,
                userText = userText,
                responseText = responseText,
                isVisualTurn = requiresVision,
            )
        }

        val benchmarkInfo = runCatching { runtime.conversation.getBenchmarkInfo() }.getOrNull()
        lastBenchmarkInfo = benchmarkInfo
        if (benchmarkInfo != null) {
            Log.i(
                logTag,
                "Inference benchmark session=$sessionId backend=${activeBackendName} ttftMs=${(benchmarkInfo.timeToFirstTokenInSecond * 1000.0).toInt()} decodeTps=${"%.2f".format(benchmarkInfo.lastDecodeTokensPerSecond)} responseChars=${responseText.length} streamId=$streamId"
            )
        }

        synchronized(runtimeLock) {
            releaseFinishedConversation(
                runtime = runtime,
                reason = "stream-complete-sidecar-memory",
            )
        }

        notifyTriageStreamCompletion(
            streamId = streamId,
            finalText = responseText,
            modelId = loadedModelId,
            usedProfileName = activeModelName(),
        )

        return responseText
    }

    private fun shouldRetryDegenerateResponse(responseText: String, locale: String): Boolean {
        val normalized = responseText
            .replace(Regex("\\s+"), " ")
            .trim()
        if (normalized.isBlank()) {
            return false
        }

        val tokenCount = normalized.split(' ').count { it.isNotBlank() }
        val asciiOnly = normalized.matches(Regex("[A-Za-z0-9 _.,:/+-]+"))
        val singleAsciiWord = normalized.matches(Regex("[A-Za-z0-9_-]{1,24}"))
        val eastAsianLocale = locale.lowercase().startsWith("zh")
            || locale.lowercase().startsWith("ja")
            || locale.lowercase().startsWith("ko")

        return when {
            normalized.length <= 2 -> true
            tokenCount <= 2 && normalized.length <= 18 && singleAsciiWord -> true
            eastAsianLocale && asciiOnly && normalized.length <= 24 -> true
            asciiOnly && tokenCount == 1 && normalized.length <= 12 -> true
            else -> false
        }
    }

    private fun resetActiveConversation(runtime: SessionRuntime) {
        val current = activeSession
        if (current?.conversation !== runtime.conversation) {
            return
        }
        current.conversation.close()
        activeSession = null
        Log.i(logTag, "Closed active conversation to recover from a degenerate response. sessionId=${current.sessionId}")
    }

    private fun releaseFinishedConversation(runtime: SessionRuntime, reason: String) {
        val current = activeSession
        if (current?.conversation !== runtime.conversation) {
            return
        }
        current.conversation.close()
        activeSession = null
        Log.i(logTag, "Released finished conversation. sessionId=${current.sessionId} reason=$reason")
    }

    private fun normalizeBase64Blob(value: String?): String? {
        val trimmed = value?.trim()?.takeIf { it.isNotEmpty() } ?: return null
        val rawPayload = if (trimmed.startsWith("data:", ignoreCase = true)) {
            trimmed.substringAfter(',', "")
        } else {
            trimmed
        }
        return rawPayload
            .replace("\r", "")
            .replace("\n", "")
            .replace(" ", "")
            .takeIf { it.isNotEmpty() }
    }

    private fun decodeImageBytes(imageBase64: String): ByteArray {
        return try {
            Base64.decode(imageBase64, Base64.DEFAULT)
        } catch (error: IllegalArgumentException) {
            throw IllegalStateException("Invalid image payload for local visual guidance.", error)
        }
    }

    private fun buildRequestContents(prompt: String, imageBase64: String?): Contents {
        if (imageBase64.isNullOrBlank()) {
            return Contents.of(prompt)
        }
        val imageBytes = decodeImageBytes(imageBase64)
        return Contents.of(
            listOf(
                Content.Text("Emergency photo attached."),
                Content.ImageBytes(imageBytes),
                Content.Text(prompt),
            ),
        )
    }

    private fun prepareConversationSession(
        engineInstance: Engine,
        sessionId: String,
        resetContext: Boolean,
        pendingPromptChars: Int,
        powerMode: String,
        requiresVision: Boolean,
    ): PreparedSessionRuntime {
        val activeModelId = loadedModelId.orEmpty()
        sessionMemory = BeaconSessionMemoryManager.clearForReset(
            current = sessionMemory,
            sessionId = sessionId,
            resetContext = resetContext,
        )
        val promptMemory = BeaconSessionMemoryManager.buildPromptMemory(
            current = sessionMemory,
            sessionId = sessionId,
            resetContext = resetContext,
        )
        val current = activeSession
        val budget = conversationBudget(requiresVision)
        val resetReason = BeaconConversationPlanner.resetReason(
            current = current?.let {
                BeaconConversationSnapshot(
                    sessionId = it.sessionId,
                    modelId = it.modelId,
                    completedTurns = it.completedTurns,
                    estimatedChars = it.estimatedChars,
                )
            },
            nextSessionId = sessionId,
            nextModelId = activeModelId,
            resetContext = resetContext,
            nextPromptEstimateChars = pendingPromptChars,
            budget = budget,
        ) ?: current?.let {
            "conversation reset per turn to keep session memory stable"
        }

        if (current != null) {
            Log.i(logTag, "Resetting conversation context. reason=$resetReason")
            current.conversation.close()
        } else {
            Log.i(logTag, "Creating fresh conversation. reason=$resetReason")
        }

        return PreparedSessionRuntime(
            runtime = SessionRuntime(
                sessionId = sessionId,
                modelId = activeModelId,
                conversation = engineInstance.createConversation(
                    ConversationConfig(
                        samplerConfig = buildSamplerConfig(powerMode, requiresVision),
                        systemInstruction = Contents.of(BeaconPromptComposer.buildSystemInstruction()),
                    ),
                ),
                completedTurns = 0,
                estimatedChars = BeaconPromptComposer.buildSystemInstruction().length,
            ).also {
                activeSession = it
            },
            promptMemory = promptMemory,
            shouldInjectPromptMemory = true,
        )
    }

    private fun buildSamplerConfig(powerMode: String, requiresVision: Boolean): SamplerConfig {
        val normalizedPowerMode = powerMode.trim().lowercase()
        val isDoomsday = normalizedPowerMode == "doomsday"
        val topK = when {
            requiresVision && isDoomsday -> 32
            requiresVision -> 40
            isDoomsday -> 36
            else -> 48
        }
        val topP = when {
            requiresVision && isDoomsday -> 0.88
            requiresVision -> 0.90
            isDoomsday -> 0.90
            else -> 0.92
        }
        val temperature = when {
            requiresVision && isDoomsday -> 0.35
            requiresVision -> 0.45
            isDoomsday -> 0.40
            else -> 0.55
        }
        return SamplerConfig(
            topK = topK,
            topP = topP,
            temperature = temperature,
        )
    }

    private fun ensureEngineLoaded(requestedModelId: String?, forceReload: Boolean): Engine {
        val targetModelId = requestedModelId ?: loadedModelId ?: defaultAvailableModelId()
            ?: throw IllegalStateException("No bundled or downloaded local model found. Gemma 4 E2B is not ready on this device.")
        val spec = currentModelCatalog().find { it.id == targetModelId }
            ?: throw IllegalStateException("Unknown model requested: $targetModelId")
        val modelFile = resolveExistingModelFile(spec)
            ?: seedBundledModelIfAvailable(spec)
            ?: throw IllegalStateException("Requested model $targetModelId is not available on this device.")

        synchronized(runtimeLock) {
            if (!forceReload && engine != null && loadedModelId == targetModelId) {
                Log.i(logTag, "Reusing loaded engine for modelId=$targetModelId")
                return engine!!
            }

            Log.i(
                logTag,
                "Initializing engine. modelId=$targetModelId path=${modelFile.absolutePath} forceReload=$forceReload"
            )
            activeSession?.conversation?.close()
            activeSession = null
            engine?.close()
            lastBenchmarkInfo = null

            val gpuAttempt = "backend=gpu vision=gpu maxTokens=2048"
            val gpuConfig = EngineConfig(
                modelPath = modelFile.absolutePath,
                backend = Backend.GPU(),
                visionBackend = Backend.GPU(),
                maxNumTokens = 2048,
                cacheDir = context.cacheDir.absolutePath,
            )

            val initializedEngine = try {
                Engine(gpuConfig).also {
                    it.initialize()
                    activeBackendName = "gpu"
                    activeVisionBackendName = "gpu"
                    lastEngineAttempt = gpuAttempt
                    lastEngineFailure = null
                    Log.i(logTag, "Engine initialized with GPU backend for modelId=$targetModelId")
                }
            } catch (gpuError: Throwable) {
                Log.w(logTag, "GPU backend failed for modelId=$targetModelId. Falling back to CPU.", gpuError)
                lastEngineFailure = gpuError.message ?: gpuError.javaClass.simpleName
                val cpuAttempt = "backend=cpu vision=cpu maxTokens=1024"
                Engine(
                    EngineConfig(
                        modelPath = modelFile.absolutePath,
                        backend = Backend.CPU(),
                        visionBackend = Backend.CPU(),
                        maxNumTokens = 1024,
                        cacheDir = context.cacheDir.absolutePath,
                    ),
                ).also {
                    it.initialize()
                    activeBackendName = "cpu"
                    activeVisionBackendName = "cpu"
                    lastEngineAttempt = cpuAttempt
                    Log.i(logTag, "Engine initialized with CPU backend for modelId=$targetModelId")
                }
            }

            engine = initializedEngine
            loadedModelId = targetModelId
            prefs.edit().putString("loadedModelId", targetModelId).apply()
            Log.i(logTag, "Engine ready. loadedModelId=$loadedModelId")
            return initializedEngine
        }
    }

    private fun buildModelArray(): JSArray {
        val models = JSArray()
        currentModelCatalog().forEach { spec ->
            val files = resolveModelFiles(spec)
            val downloadedFile = finalizeCompletedPartialIfNeeded(files)
            val displayFile = downloadedFile ?: files.primaryFile
            val bundled = hasBundledAsset(spec.fileName)
            val reportedStatus = when {
                downloadedFile != null -> BeaconDownloadStatus.SUCCEEDED
                files.downloadStatus == BeaconDownloadStatus.PARTIALLY_DOWNLOADED -> files.downloadStatus
                bundled -> BeaconDownloadStatus.IN_PROGRESS
                else -> files.downloadStatus
            }
            models.put(JSObject().apply {
                val acceleratorHints = JSArray()
                spec.accelerators.forEach { acceleratorHints.put(it) }
                val isActiveModel = loadedModelId == spec.id && downloadedFile != null
                put("id", spec.id)
                put("tier", spec.tier)
                put("name", spec.name)
                put("localPath", displayFile.absolutePath)
                put("sizeLabel", spec.sizeLabel)
                put("sizeBytes", spec.sizeInBytes)
                put("defaultProfileName", spec.defaultProfileName)
                put("recommendedFor", spec.recommendedFor)
                put("supportsImageInput", spec.supportsImageInput)
                put("acceleratorHints", acceleratorHints)
                put("isBundled", bundled)
                put("isLoaded", isActiveModel)
                put("isDownloaded", downloadedFile != null)
                put("activeBackend", if (isActiveModel) activeBackendName else null)
                put("activeVisionBackend", if (isActiveModel) activeVisionBackendName else null)
                put("acceleratorFamily", if (isActiveModel) acceleratorFamily() else "unknown")
                put("downloadStatus", reportedStatus.wireValue)
            })
        }
        return models
    }

    private fun activeModelName(): String {
        return currentModelCatalog().find { it.id == loadedModelId }?.name ?: "Gemma 4"
    }

    private fun resolveModelFile(modelId: String): File? {
        val spec = currentModelCatalog().find { it.id == modelId } ?: return null
        return resolveExistingModelFile(spec)
    }

    private fun defaultAvailableModelId(): String? {
        currentModelCatalog().firstOrNull { resolveExistingModelFile(it) != null }?.let {
            return it.id
        }
        return currentModelCatalog().firstOrNull { hasBundledAsset(it.fileName) }?.id
    }

    private fun modelsDir(): File {
        return File(context.filesDir, "models")
    }

    private fun legacyExternalModelsDir(): File {
        val baseDir = context.getExternalFilesDir(null) ?: context.filesDir
        return File(baseDir, "models")
    }

    private fun resolveExistingModelFile(spec: ModelSpec): File? {
        return finalizeCompletedPartialIfNeeded(resolveModelFiles(spec))
    }

    private fun resolveModelFiles(spec: ModelSpec): BeaconResolvedModelFiles {
        return BeaconModelFiles.resolve(
            fileName = spec.fileName,
            expectedBytes = spec.sizeInBytes,
            primaryDir = modelsDir(),
            legacyDir = legacyExternalModelsDir(),
        )
    }

    private fun bundledAssetPath(fileName: String): String {
        return "$bundledModelsAssetDir/$fileName"
    }

    private fun hasBundledAsset(fileName: String): Boolean {
        val assetPath = bundledAssetPath(fileName)
        return try {
            context.assets.openFd(assetPath).close()
            true
        } catch (_: Exception) {
            try {
                context.assets.open(assetPath).close()
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    private fun seedBundledModelIfAvailable(spec: ModelSpec): File? {
        resolveExistingModelFile(spec)?.let { return it }
        if (!hasBundledAsset(spec.fileName)) {
            return null
        }

        val files = resolveModelFiles(spec)
        finalizeCompletedPartialIfNeeded(files)?.let { return it }

        val assetPath = bundledAssetPath(spec.fileName)
        val targetFile = files.primaryFile
        val partialFile = files.partialFile
        targetFile.parentFile?.mkdirs()

        if (!partialFile.exists()) {
            files.resumableFile
                ?.takeIf { it.absolutePath != partialFile.absolutePath }
                ?.let { resumable ->
                    if (!BeaconModelFiles.replaceFile(resumable, partialFile)) {
                        throw IllegalStateException("Failed to prepare bundled model partial file for ${spec.id}.")
                    }
                }
        }

        val resumedBytes = if (partialFile.exists()) partialFile.length() else 0L
        val totalBytes = spec.sizeInBytes.coerceAtLeast(resumedBytes)
        val estimator = BeaconDownloadEstimator()
        val isResumed = resumedBytes > 0L

        if (isResumed) {
            notifyDownloadProgress(
                spec.id,
                estimator.sample(
                    receivedBytes = resumedBytes,
                    totalBytes = totalBytes,
                    isResumed = true,
                    status = BeaconDownloadStatus.PARTIALLY_DOWNLOADED,
                ),
            )
        }

        Log.i(
            logTag,
            "Seeding bundled model from app assets. modelId=${spec.id} asset=$assetPath target=${targetFile.absolutePath} resumeBytes=$resumedBytes"
        )

        context.assets.open(assetPath).use { input ->
            skipFully(input, resumedBytes)
            FileOutputStream(partialFile, isResumed).use { output ->
                val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                var receivedBytes = resumedBytes
                var lastNotifiedBytes = resumedBytes
                var lastNotifiedAt = System.currentTimeMillis()
                while (true) {
                    val read = input.read(buffer)
                    if (read <= 0) {
                        break
                    }
                    output.write(buffer, 0, read)
                    receivedBytes += read.toLong()
                    if (shouldNotifyProgress(receivedBytes, lastNotifiedBytes, lastNotifiedAt)) {
                        notifyDownloadProgress(
                            spec.id,
                            estimator.sample(
                                receivedBytes = receivedBytes,
                                totalBytes = totalBytes,
                                isResumed = isResumed,
                                status = BeaconDownloadStatus.IN_PROGRESS,
                            ),
                        )
                        lastNotifiedBytes = receivedBytes
                        lastNotifiedAt = System.currentTimeMillis()
                    }
                }
            }
        }

        if (!BeaconModelFiles.replaceFile(partialFile, targetFile)) {
            throw IllegalStateException("Failed to finalize bundled model file for ${spec.id}.")
        }

        Log.i(
            logTag,
            "Bundled model seeded successfully. modelId=${spec.id} path=${targetFile.absolutePath} bytes=${targetFile.length()}"
        )
        notifyDownloadProgress(
            spec.id,
            estimator.sample(
                receivedBytes = targetFile.length(),
                totalBytes = totalBytes.coerceAtLeast(targetFile.length()),
                isResumed = isResumed,
                status = BeaconDownloadStatus.SUCCEEDED,
                done = true,
            ),
        )
        return targetFile
    }

    private fun finalizeCompletedPartialIfNeeded(files: BeaconResolvedModelFiles): File? {
        val completeFile = files.completeFile ?: return null
        if (!files.completeFileNeedsFinalize) {
            return completeFile
        }

        if (!BeaconModelFiles.replaceFile(completeFile, files.primaryFile)) {
            throw IllegalStateException("Failed to finalize completed partial model file: ${files.primaryFile.name}")
        }
        return files.primaryFile
    }

    private fun currentModelCatalog(): List<ModelSpec> {
        ensureModelCatalogLoaded()
        return modelCatalog
    }

    private fun ensureModelCatalogLoaded() {
        if (modelCatalog.isNotEmpty()) {
            return
        }

        synchronized(runtimeLock) {
            if (modelCatalog.isNotEmpty()) {
                return
            }

            modelCatalog = BeaconModelAllowlistRepository.load(context).models.map { allowed ->
                ModelSpec(
                    id = allowed.id,
                    tier = allowed.tier,
                    name = allowed.name,
                    fileName = allowed.fileName,
                    sizeLabel = allowed.sizeLabel,
                    downloadUrl = allowed.downloadUrl,
                    sizeInBytes = allowed.sizeInBytes,
                    defaultProfileName = allowed.defaultProfileName,
                    recommendedFor = allowed.recommendedFor,
                    supportsImageInput = allowed.supportsImageInput,
                    accelerators = allowed.accelerators,
                )
            }
        }
    }

    private fun refreshAllowlistInBackground() {
        executor.execute {
            val refreshed = BeaconModelAllowlistRepository.refreshIfStale(context) ?: return@execute
            synchronized(runtimeLock) {
                modelCatalog = refreshed.models.map { allowed ->
                    ModelSpec(
                        id = allowed.id,
                        tier = allowed.tier,
                        name = allowed.name,
                        fileName = allowed.fileName,
                        sizeLabel = allowed.sizeLabel,
                        downloadUrl = allowed.downloadUrl,
                        sizeInBytes = allowed.sizeInBytes,
                        defaultProfileName = allowed.defaultProfileName,
                        recommendedFor = allowed.recommendedFor,
                        supportsImageInput = allowed.supportsImageInput,
                        accelerators = allowed.accelerators,
                    )
                }
            }
            Log.i(logTag, "Model allowlist refreshed in background. models=${modelCatalog.size}")
        }
    }

    private fun skipFully(input: InputStream, bytesToSkip: Long) {
        var remaining = bytesToSkip
        while (remaining > 0L) {
            val skipped = input.skip(remaining)
            if (skipped > 0L) {
                remaining -= skipped
                continue
            }

            if (input.read() == -1) {
                break
            }
            remaining -= 1L
        }
    }

    private fun shouldNotifyProgress(
        receivedBytes: Long,
        lastNotifiedBytes: Long,
        lastNotifiedAtMs: Long,
    ): Boolean {
        if (receivedBytes <= 0L) {
            return false
        }
        val bytesAdvanced = receivedBytes - lastNotifiedBytes
        val elapsedMs = System.currentTimeMillis() - lastNotifiedAtMs
        return bytesAdvanced >= progressNotifyStepBytes || elapsedMs >= 250L
    }

    private fun updateStreamText(
        snapshotText: StringBuilder,
        fullText: StringBuilder,
        nextText: String,
    ): String {
        val previousSnapshot = snapshotText.toString()
        return when {
            previousSnapshot.isEmpty() -> {
                snapshotText.append(nextText)
                fullText.append(nextText)
                nextText
            }

            nextText.startsWith(previousSnapshot) -> {
                val delta = nextText.removePrefix(previousSnapshot)
                snapshotText.setLength(0)
                snapshotText.append(nextText)
                fullText.setLength(0)
                fullText.append(nextText)
                delta
            }

            previousSnapshot.endsWith(nextText) -> {
                ""
            }

            else -> {
                snapshotText.append(nextText)
                fullText.append(nextText)
                nextText
            }
        }
    }

    private fun rememberTurnCarryover(
        sessionId: String,
        modelId: String,
        categoryHint: String?,
        userText: String,
        responseText: String,
        isVisualTurn: Boolean,
    ) {
        sessionMemory = BeaconSessionMemoryManager.rememberTurn(
            current = sessionMemory,
            sessionId = sessionId,
            modelId = modelId,
            categoryHint = categoryHint,
            userText = userText,
            responseText = responseText,
            isVisualTurn = isVisualTurn,
        )
        val remembered = sessionMemory ?: return
        Log.i(
            logTag,
            "Updated session memory. sessionId=$sessionId recentTurns=${remembered.recentTurns.size} summaryChars=${remembered.rollingSummary.length} visual=${!remembered.lastVisualContext.isNullOrBlank()}"
        )
    }

    private fun rememberConversationProgress(
        runtime: SessionRuntime,
        promptChars: Int,
        responseText: String,
    ) {
        val current = activeSession ?: return
        if (current.conversation !== runtime.conversation) {
            return
        }
        val responseChars = responseText.trim().take(640).length
        activeSession = current.copy(
            completedTurns = current.completedTurns + 1,
            estimatedChars = current.estimatedChars + promptChars + responseChars,
        )
        Log.i(
            logTag,
            "Updated conversation budget. sessionId=${current.sessionId} turns=${current.completedTurns + 1} estimatedChars=${current.estimatedChars + promptChars + responseChars}"
        )
    }

    private fun conversationBudget(requiresVision: Boolean): BeaconConversationBudget {
        return when {
            activeBackendName == "cpu" && requiresVision -> BeaconConversationBudget(
                maxTurns = 2,
                maxEstimatedChars = 1350,
            )

            activeBackendName == "cpu" -> BeaconConversationBudget(
                maxTurns = 4,
                maxEstimatedChars = 2200,
            )

            requiresVision -> BeaconConversationBudget(
                maxTurns = 3,
                maxEstimatedChars = 2400,
            )

            else -> BeaconConversationBudget(
                maxTurns = 6,
                maxEstimatedChars = 3600,
            )
        }
    }

    private fun sanitizeModelText(value: String): String {
        return value
            .replace("\r\n", "\n")
            .replace('\r', '\n')
            .replace(Regex("""\$\s*\\?l?rightarrow\s*\$""", RegexOption.IGNORE_CASE), " -> ")
            .replace(modelControlCharsRegex, "")
    }

    private fun hasMeaningfulModelText(value: String): Boolean {
        return sanitizeModelText(value).any { !it.isWhitespace() }
    }

    private fun notifyTriageStreamDelta(streamId: String, delta: String) {
        if (delta.isEmpty() || !hasListeners("triageStreamEvent")) {
            return
        }
        notifyListeners(
            "triageStreamEvent",
            JSObject().apply {
                put("streamId", streamId)
                put("delta", delta)
                put("done", false)
            },
        )
    }

    private fun notifyTriageStreamCompletion(
        streamId: String,
        finalText: String? = null,
        modelId: String? = null,
        usedProfileName: String? = null,
        errorMessage: String? = null,
    ) {
        if (!hasListeners("triageStreamEvent")) {
            return
        }
        notifyListeners(
            "triageStreamEvent",
            JSObject().apply {
                put("streamId", streamId)
                put("done", true)
                put("finalText", finalText)
                put("modelId", modelId)
                put("usedProfileName", usedProfileName)
                put("error", errorMessage)
            },
        )
    }

    private fun notifyDownloadProgress(
        modelId: String,
        payload: BeaconDownloadProgressPayload,
    ) {
        if (!hasListeners("modelDownloadProgress")) {
            return
        }
        notifyListeners("modelDownloadProgress", JSObject().apply {
            put("modelId", modelId)
            put("receivedBytes", payload.receivedBytes)
            put("totalBytes", payload.totalBytes)
            put("fraction", payload.fraction)
            put("isResumed", payload.isResumed)
            put("status", payload.status.wireValue)
            put("bytesPerSecond", payload.bytesPerSecond)
            put("remainingMs", payload.remainingMs)
            put("errorMessage", payload.errorMessage)
            put("done", payload.done)
        })
    }

    private fun openDownloadConnection(url: String, existingBytes: Long): HttpURLConnection {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.instanceFollowRedirects = true
        connection.connectTimeout = 15_000
        connection.readTimeout = 30_000
        connection.setRequestProperty("Accept", "application/octet-stream")
        connection.setRequestProperty("User-Agent", "Beacon/1.0")
        if (existingBytes > 0) {
            connection.setRequestProperty("Range", "bytes=$existingBytes-")
        }
        connection.connect()
        if (connection.responseCode !in 200..299 && connection.responseCode != 206) {
            throw IllegalStateException("Download request failed with HTTP ${connection.responseCode}")
        }
        return connection
    }

    private fun resolveExpectedBytes(connection: HttpURLConnection, existingBytes: Long): Long {
        val contentLength = connection.contentLengthLong
        return if (connection.responseCode == 206 && contentLength > 0) {
            existingBytes + contentLength
        } else {
            contentLength
        }
    }

    private fun buildRuntimeDiagnostics(): JSObject {
        val loadedModel = loadedModelId
        val benchmarkInfo = lastBenchmarkInfo
        return JSObject().apply {
            put("platform", "android")
            put("loadedModelId", loadedModel)
            put("isLoaded", engine != null && !loadedModel.isNullOrBlank())
            put("activeBackend", activeBackendName)
            put("activeVisionBackend", activeVisionBackendName)
            put("acceleratorFamily", acceleratorFamily())
            put("lastEngineAttempt", lastEngineAttempt)
            put("lastEngineFailure", lastEngineFailure)
            if (benchmarkInfo != null) {
                put("benchmark", benchmarkToJs(benchmarkInfo))
            }
        }
    }

    private fun acceleratorFamily(): String {
        return when (activeBackendName.lowercase()) {
            "gpu" -> "gpu"
            "cpu" -> "cpu"
            else -> "unknown"
        }
    }

    private fun benchmarkToJs(info: BenchmarkInfo): JSObject {
        return JSObject().apply {
            put("totalInitMs", info.initTimeInSecond * 1000.0)
            put("timeToFirstTokenMs", info.timeToFirstTokenInSecond * 1000.0)
            put("lastPrefillTokenCount", info.lastPrefillTokenCount)
            put("lastDecodeTokenCount", info.lastDecodeTokenCount)
            put("lastPrefillTokensPerSecond", info.lastPrefillTokensPerSecond)
            put("lastDecodeTokensPerSecond", info.lastDecodeTokensPerSecond)
        }
    }
}
