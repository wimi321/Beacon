package com.beacon.sos

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class BeaconSessionMemoryManagerTest {
    @Test
    fun `keeps the latest six turns and rolls older chat into summary`() {
        var memory: BeaconSessionMemory? = null

        repeat(8) { index ->
            memory = BeaconSessionMemoryManager.rememberTurn(
                current = memory,
                sessionId = "session-forest",
                modelId = "gemma-4-e2b",
                categoryHint = null,
                userText = "Turn ${index + 1}: I am still in the forest.",
                responseText = "Reply ${index + 1}: Stay visible and conserve energy.",
                isVisualTurn = false,
            )
        }

        requireNotNull(memory)
        assertEquals(6, memory.recentTurns.size)
        assertTrue(memory.recentTurns.first().userText.contains("Turn 3"))
        assertTrue(memory.recentTurns.last().assistantText.contains("Reply 8"))
        assertTrue(memory.rollingSummary.contains("Turn 1"))
        assertTrue(memory.rollingSummary.contains("Reply 2"))

        val promptMemory = BeaconSessionMemoryManager.buildPromptMemory(
            current = memory,
            sessionId = "session-forest",
            resetContext = false,
        )

        assertNotNull(promptMemory.sessionSummary)
        assertNotNull(promptMemory.recentChatContext)
        val recentChatContext = requireNotNull(promptMemory.recentChatContext)
        assertTrue(recentChatContext.contains("U1: Turn 3"))
        assertTrue(recentChatContext.contains("B6: Reply 8"))
    }

    @Test
    fun `visual context survives later text follow ups`() {
        var memory = BeaconSessionMemoryManager.rememberTurn(
            current = null,
            sessionId = "session-wound",
            modelId = "gemma-4-e2b",
            categoryHint = "Visual Analysis",
            userText = "",
            responseText = "The image shows a deep cut with active bleeding.\nApply firm direct pressure now.",
            isVisualTurn = true,
        )

        memory = BeaconSessionMemoryManager.rememberTurn(
            current = memory,
            sessionId = "session-wound",
            modelId = "gemma-4-e2b",
            categoryHint = null,
            userText = "Should I rinse it first?",
            responseText = "Do not rinse heavily while it is still bleeding. Keep pressure first.",
            isVisualTurn = false,
        )

        requireNotNull(memory)
        assertTrue(requireNotNull(memory.lastVisualContext).contains("deep cut"))
        val promptMemory = BeaconSessionMemoryManager.buildPromptMemory(
            current = memory,
            sessionId = "session-wound",
            resetContext = false,
        )

        assertNotNull(promptMemory.lastVisualContext)
        assertTrue(requireNotNull(promptMemory.recentChatContext).contains("Should I rinse it first?"))
    }

    @Test
    fun `reset and session change clear remembered context`() {
        val memory = BeaconSessionMemoryManager.rememberTurn(
            current = null,
            sessionId = "session-a",
            modelId = "gemma-4-e2b",
            categoryHint = null,
            userText = "My chest hurts.",
            responseText = "Stop moving and monitor your breathing.",
            isVisualTurn = false,
        )

        assertNull(
            BeaconSessionMemoryManager.clearForReset(
                current = memory,
                sessionId = "session-a",
                resetContext = true,
            ),
        )
        assertNull(
            BeaconSessionMemoryManager.clearForReset(
                current = memory,
                sessionId = "session-b",
                resetContext = false,
            ),
        )

        val promptMemory = BeaconSessionMemoryManager.buildPromptMemory(
            current = memory,
            sessionId = "session-b",
            resetContext = false,
        )

        assertNull(promptMemory.sessionSummary)
        assertNull(promptMemory.recentChatContext)
        assertNull(promptMemory.lastVisualContext)
    }

    @Test
    fun `malformed prompt-echo responses do not pollute remembered context`() {
        val memory = BeaconSessionMemoryManager.rememberTurn(
            current = null,
            sessionId = "session-bad-output",
            modelId = "gemma-4-e2b",
            categoryHint = "Lost and disconnected",
            userText = "I am in the forest.",
            responseText = "Do: stay put Avoid: keep moving Help: signal hard A: source S: source \$lrightarrow\$",
            isVisualTurn = false,
        )

        val promptMemory = BeaconSessionMemoryManager.buildPromptMemory(
            current = memory,
            sessionId = "session-bad-output",
            resetContext = false,
        )

        assertNull(memory)
        assertNull(promptMemory.recentChatContext)
    }
}
