package com.beacon.sos

internal data class BeaconConversationSnapshot(
    val sessionId: String,
    val modelId: String,
    val completedTurns: Int = 0,
    val estimatedChars: Int = 0,
)

internal data class BeaconConversationBudget(
    val maxTurns: Int,
    val maxEstimatedChars: Int,
)

internal object BeaconConversationPlanner {
    fun resetReason(
        current: BeaconConversationSnapshot?,
        nextSessionId: String,
        nextModelId: String,
        resetContext: Boolean,
        nextPromptEstimateChars: Int = 0,
        budget: BeaconConversationBudget? = null,
    ): String? {
        return when {
            current == null -> "no active conversation"
            resetContext -> "explicit reset requested"
            current.modelId != nextModelId -> "model changed from ${current.modelId} to $nextModelId"
            current.sessionId != nextSessionId -> "session changed from ${current.sessionId} to $nextSessionId"
            budget != null && current.completedTurns >= budget.maxTurns ->
                "conversation turn budget reached (${current.completedTurns}/${budget.maxTurns})"
            budget != null && current.estimatedChars + nextPromptEstimateChars > budget.maxEstimatedChars ->
                "conversation context budget reached (${current.estimatedChars + nextPromptEstimateChars}/${budget.maxEstimatedChars} chars)"
            else -> null
        }
    }
}
