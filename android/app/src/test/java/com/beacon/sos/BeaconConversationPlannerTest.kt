package com.beacon.sos

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class BeaconConversationPlannerTest {
    @Test
    fun `starts a new conversation when no session is active`() {
        val reason = BeaconConversationPlanner.resetReason(
            current = null,
            nextSessionId = "session-new",
            nextModelId = "gemma-4-e2b",
            resetContext = false,
        )

        assertEquals("no active conversation", reason)
    }

    @Test
    fun `resets when frontend explicitly requests a fresh chat`() {
        val reason = BeaconConversationPlanner.resetReason(
            current = BeaconConversationSnapshot(
                sessionId = "session-old",
                modelId = "gemma-4-e2b",
            ),
            nextSessionId = "session-old",
            nextModelId = "gemma-4-e2b",
            resetContext = true,
        )

        assertEquals("explicit reset requested", reason)
    }

    @Test
    fun `resets when the session id changes even if the model stays hot`() {
        val reason = BeaconConversationPlanner.resetReason(
            current = BeaconConversationSnapshot(
                sessionId = "session-old",
                modelId = "gemma-4-e2b",
            ),
            nextSessionId = "session-new",
            nextModelId = "gemma-4-e2b",
            resetContext = false,
        )

        assertEquals("session changed from session-old to session-new", reason)
    }

    @Test
    fun `keeps the same conversation when session and model both match`() {
        val reason = BeaconConversationPlanner.resetReason(
            current = BeaconConversationSnapshot(
                sessionId = "session-same",
                modelId = "gemma-4-e2b",
                completedTurns = 2,
                estimatedChars = 640,
            ),
            nextSessionId = "session-same",
            nextModelId = "gemma-4-e2b",
            resetContext = false,
            nextPromptEstimateChars = 240,
            budget = BeaconConversationBudget(
                maxTurns = 6,
                maxEstimatedChars = 2400,
            ),
        )

        assertNull(reason)
    }

    @Test
    fun `resets when the rolling turn budget is exhausted`() {
        val reason = BeaconConversationPlanner.resetReason(
            current = BeaconConversationSnapshot(
                sessionId = "session-same",
                modelId = "gemma-4-e2b",
                completedTurns = 4,
                estimatedChars = 1500,
            ),
            nextSessionId = "session-same",
            nextModelId = "gemma-4-e2b",
            resetContext = false,
            nextPromptEstimateChars = 220,
            budget = BeaconConversationBudget(
                maxTurns = 4,
                maxEstimatedChars = 2400,
            ),
        )

        assertEquals("conversation turn budget reached (4/4)", reason)
    }

    @Test
    fun `resets when the rolling context budget is exhausted`() {
        val reason = BeaconConversationPlanner.resetReason(
            current = BeaconConversationSnapshot(
                sessionId = "session-same",
                modelId = "gemma-4-e2b",
                completedTurns = 2,
                estimatedChars = 2300,
            ),
            nextSessionId = "session-same",
            nextModelId = "gemma-4-e2b",
            resetContext = false,
            nextPromptEstimateChars = 180,
            budget = BeaconConversationBudget(
                maxTurns = 6,
                maxEstimatedChars = 2400,
            ),
        )

        assertEquals("conversation context budget reached (2480/2400 chars)", reason)
    }
}
