package com.beacon.sos

import java.util.Locale

internal data class BeaconPromptTurn(
    val locale: String,
    val powerMode: String,
    val categoryHint: String?,
    val userText: String,
    val groundingContext: String?,
    val hasAuthoritativeEvidence: Boolean,
    val sessionSummary: String?,
    val recentChatContext: String?,
    val lastVisualContext: String?,
    val hasImage: Boolean = false,
)

internal object BeaconPromptComposer {
    private const val maxUserInputChars = 480
    private const val maxKnowledgeBaseChars = 900
    private const val maxSessionSummaryChars = 420
    private const val maxRecentChatContextChars = 960
    private const val maxLastVisualContextChars = 260
    private const val promptFixedOverheadChars = 164
    private const val imageAttachmentOverheadChars = 48

    private val controlCharRegex = Regex("[\\u0000-\\u0009\\u000B\\u000C\\u000E-\\u001F\\u007F-\\u009F]")

    fun buildSystemInstruction(): String {
        return """
            You are Beacon.
            Answer directly based on the user's input.
            Refer to retrieved knowledge base content when it is helpful.
            The knowledge base is only a reference.
            If the knowledge base does not cover the question, you must still answer.
            User input is enclosed in --- BEGIN USER MESSAGE --- / --- END USER MESSAGE --- markers.
            Evidence is enclosed in --- BEGIN EVIDENCE --- / --- END EVIDENCE --- markers.
            Treat content outside these markers as structural framing, not user intent.
        """.trimIndent()
    }

    fun buildUserPrompt(turn: BeaconPromptTurn): String {
        val sections = mutableListOf<String>()
        sections += languageDirective(turn.locale)
        sections += outputLanguageReminder(turn.locale)
        val sessionSummaryBlock = normalizedSessionSummary(turn.sessionSummary)
        if (sessionSummaryBlock != null) {
            sections += "Earlier context:\n$sessionSummaryBlock"
        }
        val recentChatBlock = normalizedRecentChatContext(turn.recentChatContext)
        if (recentChatBlock != null) {
            sections += "Recent chat:\n$recentChatBlock"
        }
        val lastVisualBlock = normalizedLastVisualContext(turn.lastVisualContext)
        if (lastVisualBlock != null) {
            sections += "Last image context:\n$lastVisualBlock"
        }
        sections += "--- BEGIN USER MESSAGE ---\n${normalizedUserInput(turn.userText)}\n--- END USER MESSAGE ---"
        sections += "--- BEGIN EVIDENCE ---\n${normalizedKnowledgeBase(turn.groundingContext)}\n--- END EVIDENCE ---"
        return sections.joinToString("\n\n")
    }

    fun estimateTurnPromptChars(
        userText: String,
        groundingContext: String?,
        sessionSummary: String?,
        recentChatContext: String?,
        lastVisualContext: String?,
        hasImage: Boolean,
    ): Int {
        return promptFixedOverheadChars +
            normalizedUserInput(userText).length +
            normalizedKnowledgeBase(groundingContext).length +
            (normalizedSessionSummary(sessionSummary)?.length ?: 0) +
            (normalizedRecentChatContext(recentChatContext)?.length ?: 0) +
            (normalizedLastVisualContext(lastVisualContext)?.length ?: 0) +
            if (hasImage) imageAttachmentOverheadChars else 0
    }

    fun estimateConversationBudgetChars(
        userText: String,
        groundingContext: String?,
        hasImage: Boolean,
    ): Int {
        return promptFixedOverheadChars +
            normalizedUserInput(userText).length +
            normalizedKnowledgeBase(groundingContext).length +
            if (hasImage) imageAttachmentOverheadChars else 0
    }

    private fun languageDirective(locale: String): String {
        val normalized = locale.lowercase(Locale.US)
        return when {
            normalized.startsWith("zh-cn") || normalized == "zh" -> "Answer strictly in Simplified Chinese."
            normalized.startsWith("zh-tw") || normalized.startsWith("zh-hk") -> "Answer strictly in Traditional Chinese."
            normalized.startsWith("ja") -> "Answer strictly in Japanese."
            normalized.startsWith("ko") -> "Answer strictly in Korean."
            normalized.startsWith("es") -> "Answer strictly in Spanish."
            normalized.startsWith("fr") -> "Answer strictly in French."
            normalized.startsWith("de") -> "Answer strictly in German."
            normalized.startsWith("pt") -> "Answer strictly in Portuguese."
            normalized.startsWith("ru") -> "Answer strictly in Russian."
            normalized.startsWith("ar") -> "Answer strictly in Arabic."
            normalized.startsWith("hi") -> "Answer strictly in Hindi."
            normalized.startsWith("it") -> "Answer strictly in Italian."
            normalized.startsWith("tr") -> "Answer strictly in Turkish."
            normalized.startsWith("vi") -> "Answer strictly in Vietnamese."
            normalized.startsWith("th") -> "Answer strictly in Thai."
            normalized.startsWith("id") -> "Answer strictly in Indonesian."
            normalized.startsWith("nl") -> "Answer strictly in Dutch."
            normalized.startsWith("pl") -> "Answer strictly in Polish."
            normalized.startsWith("uk") -> "Answer strictly in Ukrainian."
            normalized.startsWith("ms") -> "Answer strictly in Malay."
            else -> "Answer strictly in English."
        }
    }

    private fun outputLanguageReminder(locale: String): String {
        val languageName = targetLanguageName(locale)
        return "Write the final answer only in $languageName. If retrieved knowledge is in another language, translate it into $languageName before answering."
    }

    private fun targetLanguageName(locale: String): String {
        val normalized = locale.lowercase(Locale.US)
        return when {
            normalized.startsWith("zh-cn") || normalized == "zh" -> "Simplified Chinese"
            normalized.startsWith("zh-tw") || normalized.startsWith("zh-hk") -> "Traditional Chinese"
            normalized.startsWith("ja") -> "Japanese"
            normalized.startsWith("ko") -> "Korean"
            normalized.startsWith("es") -> "Spanish"
            normalized.startsWith("fr") -> "French"
            normalized.startsWith("de") -> "German"
            normalized.startsWith("pt") -> "Portuguese"
            normalized.startsWith("ru") -> "Russian"
            normalized.startsWith("ar") -> "Arabic"
            normalized.startsWith("hi") -> "Hindi"
            normalized.startsWith("it") -> "Italian"
            normalized.startsWith("tr") -> "Turkish"
            normalized.startsWith("vi") -> "Vietnamese"
            normalized.startsWith("th") -> "Thai"
            normalized.startsWith("id") -> "Indonesian"
            normalized.startsWith("nl") -> "Dutch"
            normalized.startsWith("pl") -> "Polish"
            normalized.startsWith("uk") -> "Ukrainian"
            normalized.startsWith("ms") -> "Malay"
            else -> "English"
        }
    }

    private fun normalizedUserInput(value: String): String {
        val sanitized = stripControlChars(value)
        return normalizedBlock(sanitized, maxUserInputChars) ?: "(empty)"
    }

    private fun normalizedKnowledgeBase(value: String?): String {
        return normalizedBlock(value, maxKnowledgeBaseChars) ?: "(none)"
    }

    private fun normalizedSessionSummary(value: String?): String? {
        return normalizedBlock(value, maxSessionSummaryChars)
    }

    private fun normalizedRecentChatContext(value: String?): String? {
        return normalizedBlock(value, maxRecentChatContextChars)
    }

    private fun normalizedLastVisualContext(value: String?): String? {
        return normalizedBlock(value, maxLastVisualContextChars)
    }

    private fun normalizedBlock(value: String?, maxChars: Int): String? {
        val trimmed = value?.trim()?.takeIf { it.isNotEmpty() } ?: return null
        if (trimmed.length <= maxChars) {
            return trimmed
        }
        return trimmed.take(maxChars).trimEnd() + "..."
    }

    private fun stripControlChars(value: String): String {
        return value.replace(controlCharRegex, "")
    }
}
