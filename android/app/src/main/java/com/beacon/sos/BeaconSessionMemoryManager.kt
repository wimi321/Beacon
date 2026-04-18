package com.beacon.sos

internal data class BeaconSessionMemoryTurn(
    val userText: String,
    val assistantText: String,
)

internal data class BeaconSessionMemory(
    val sessionId: String,
    val modelId: String,
    val rollingSummary: String = "",
    val recentTurns: List<BeaconSessionMemoryTurn> = emptyList(),
    val lastVisualContext: String? = null,
)

internal data class BeaconPromptMemoryContext(
    val sessionSummary: String? = null,
    val recentChatContext: String? = null,
    val lastVisualContext: String? = null,
)

internal object BeaconSessionMemoryManager {
    private const val maxRecentTurns = 6
    private const val maxRollingSummaryChars = 420
    private const val maxRecentChatContextChars = 960
    private const val maxVisualContextChars = 260
    private const val maxUserTurnChars = 160
    private const val maxAssistantTurnChars = 260
    private val malformedAssistantArtifactRegex = Regex(
        """\$\s*l?rightarrow\s*\$|\\(?:l?rightarrow)|\bstrightarrow\b""",
        RegexOption.IGNORE_CASE,
    )

    fun clearForReset(
        current: BeaconSessionMemory?,
        sessionId: String,
        resetContext: Boolean,
    ): BeaconSessionMemory? {
        if (resetContext) {
            return null
        }
        if (current != null && current.sessionId != sessionId) {
            return null
        }
        return current
    }

    fun buildPromptMemory(
        current: BeaconSessionMemory?,
        sessionId: String,
        resetContext: Boolean,
    ): BeaconPromptMemoryContext {
        if (resetContext) {
            return BeaconPromptMemoryContext()
        }

        val memory = current?.takeIf { it.sessionId == sessionId } ?: return BeaconPromptMemoryContext()
        return BeaconPromptMemoryContext(
            sessionSummary = truncateTailPreservingRecent(memory.rollingSummary, maxRollingSummaryChars)
                .takeIf { it.isNotBlank() },
            recentChatContext = renderRecentChatContext(memory.recentTurns),
            lastVisualContext = truncateCollapsed(memory.lastVisualContext, maxVisualContextChars)
                .takeIf { it.isNotBlank() },
        )
    }

    fun rememberTurn(
        current: BeaconSessionMemory?,
        sessionId: String,
        modelId: String,
        categoryHint: String?,
        userText: String,
        responseText: String,
        isVisualTurn: Boolean,
    ): BeaconSessionMemory? {
        val rememberedUserText = buildRememberedUserText(
            categoryHint = categoryHint,
            userText = userText,
            isVisualTurn = isVisualTurn,
        )
        val rememberedAssistantText = sanitizeRememberedAssistantText(responseText)
        if (rememberedUserText.isBlank() || rememberedAssistantText.isBlank()) {
            return current?.takeIf { it.sessionId == sessionId }?.copy(modelId = modelId)
        }

        val baseMemory = current?.takeIf { it.sessionId == sessionId } ?: BeaconSessionMemory(
            sessionId = sessionId,
            modelId = modelId,
        )
        val combinedTurns = baseMemory.recentTurns + BeaconSessionMemoryTurn(
            userText = rememberedUserText,
            assistantText = rememberedAssistantText,
        )
        val overflowTurns = if (combinedTurns.size > maxRecentTurns) {
            combinedTurns.dropLast(maxRecentTurns)
        } else {
            emptyList()
        }
        val keptTurns = combinedTurns.takeLast(maxRecentTurns)
        val updatedSummary = mergeRollingSummary(baseMemory.rollingSummary, overflowTurns)
        val updatedVisualContext = if (isVisualTurn) {
            buildVisualContext(responseText)
        } else {
            baseMemory.lastVisualContext
        }

        return BeaconSessionMemory(
            sessionId = sessionId,
            modelId = modelId,
            rollingSummary = updatedSummary,
            recentTurns = keptTurns,
            lastVisualContext = updatedVisualContext,
        )
    }

    private fun renderRecentChatContext(turns: List<BeaconSessionMemoryTurn>): String? {
        if (turns.isEmpty()) {
            return null
        }

        val renderedTurns = turns.takeLast(maxRecentTurns).mapIndexed { index, turn ->
            "U${index + 1}: ${turn.userText}\nB${index + 1}: ${turn.assistantText}"
        }
        val keptTurns = ArrayDeque<String>()
        var usedChars = 0
        for (segment in renderedTurns.asReversed()) {
            val segmentChars = segment.length + if (keptTurns.isEmpty()) 0 else 1
            if (usedChars + segmentChars > maxRecentChatContextChars && keptTurns.isNotEmpty()) {
                break
            }
            if (segmentChars > maxRecentChatContextChars && keptTurns.isEmpty()) {
                return truncateTailPreservingRecent(segment, maxRecentChatContextChars)
            }
            keptTurns.addFirst(segment)
            usedChars += segmentChars
        }

        return keptTurns.joinToString("\n").takeIf { it.isNotBlank() }
    }

    private fun mergeRollingSummary(
        existingSummary: String,
        overflowTurns: List<BeaconSessionMemoryTurn>,
    ): String {
        if (overflowTurns.isEmpty()) {
            return truncateTailPreservingRecent(existingSummary, maxRollingSummaryChars)
        }

        var merged = truncateTailPreservingRecent(existingSummary, maxRollingSummaryChars)
        overflowTurns.forEach { turn ->
            val segment = listOf(
                turn.userText.takeIf { it.isNotBlank() }?.let { "User: $it" },
                turn.assistantText.takeIf { it.isNotBlank() }?.let { "Beacon: $it" },
            ).joinToString(" ")
            if (segment.isBlank()) {
                return@forEach
            }
            merged = if (merged.isBlank()) {
                segment
            } else {
                "$merged $segment"
            }
            merged = truncateTailPreservingRecent(merged, maxRollingSummaryChars)
        }
        return merged
    }

    private fun buildRememberedUserText(
        categoryHint: String?,
        userText: String,
        isVisualTurn: Boolean,
    ): String {
        val normalizedUserText = truncateCollapsed(userText, maxUserTurnChars)
        if (normalizedUserText.isNotBlank()) {
            return normalizedUserText
        }
        val normalizedCategory = truncateCollapsed(categoryHint, maxUserTurnChars)
        if (normalizedCategory.isNotBlank()) {
            return normalizedCategory
        }
        if (isVisualTurn) {
            return "Visual analysis request."
        }
        return ""
    }

    private fun buildVisualContext(responseText: String): String? {
        val lines = responseText
            .lineSequence()
            .map(::collapseWhitespace)
            .filter { it.isNotBlank() }
            .take(3)
            .toList()
        if (lines.isEmpty()) {
            return null
        }
        return truncateCollapsed(lines.joinToString(" "), maxVisualContextChars)
    }

    private fun sanitizeRememberedAssistantText(value: String): String {
        val normalized = truncateCollapsed(value, maxAssistantTurnChars)
        if (normalized.isBlank()) {
            return ""
        }

        val lower = normalized.lowercase()
        val promptEchoCount = listOf("a:", "s:", "do:", "avoid:", "help:")
            .count { marker -> lower.contains(marker) }
        if (malformedAssistantArtifactRegex.containsMatchIn(normalized) || promptEchoCount >= 4) {
            return ""
        }

        return normalized
    }

    private fun truncateCollapsed(value: String?, maxChars: Int): String {
        val normalized = collapseWhitespace(value.orEmpty())
        if (normalized.length <= maxChars) {
            return normalized
        }
        return normalized.take(maxChars).trimEnd() + "..."
    }

    private fun truncateTailPreservingRecent(value: String?, maxChars: Int): String {
        val normalized = collapseWhitespace(value.orEmpty())
        if (normalized.length <= maxChars) {
            return normalized
        }
        if (maxChars <= 3) {
            return normalized.takeLast(maxChars)
        }
        return "..." + normalized.takeLast(maxChars - 3).trimStart()
    }

    private fun collapseWhitespace(value: String): String {
        return value.replace(Regex("\\s+"), " ").trim()
    }
}
