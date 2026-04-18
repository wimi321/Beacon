package com.beacon.sos

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BeaconPromptComposerTest {
    @Test
    fun `system instruction stays minimal and neutral`() {
        val systemInstruction = BeaconPromptComposer.buildSystemInstruction()

        assertTrue(systemInstruction.contains("You are Beacon."))
        assertTrue(systemInstruction.contains("Answer directly based on the user's input."))
        assertTrue(systemInstruction.contains("The knowledge base is only a reference."))
        assertTrue(systemInstruction.contains("If the knowledge base does not cover the question, you must still answer."))
        assertFalse(systemInstruction.contains("Stay focused on the user's current situation."))
        assertFalse(systemInstruction.contains("Do not introduce unrelated emergencies, diseases, or what-if scenarios."))
        assertFalse(systemInstruction.contains("Use plain text only."))
        assertFalse(systemInstruction.contains("Do not use markdown, asterisks, bold markers, or bullet symbols."))
        assertFalse(systemInstruction.contains("offline emergency survival assistant"))
        assertFalse(systemInstruction.contains("Answer strictly in Japanese"))
    }

    @Test
    fun `user prompt carries locale memory user input and knowledge base`() {
        val prompt = BeaconPromptComposer.buildUserPrompt(
            BeaconPromptTurn(
                locale = "ja",
                powerMode = "normal",
                categoryHint = "Smoke inhalation",
                userText = "Need help breathing in a fire.",
                groundingContext = "[Authority] Keep low and avoid smoke.",
                hasAuthoritativeEvidence = true,
                sessionSummary = "Earlier the user reported thick smoke in a hallway.",
                recentChatContext = "U1: Found smoke in hallway\nB1: Stay low and move away from smoke.",
                lastVisualContext = "Photo suggested airway irritation and poor visibility near the doorway.",
            ),
        )

        assertTrue(prompt.contains("Answer strictly in Japanese."))
        assertTrue(prompt.contains("Write the final answer only in Japanese. If retrieved knowledge is in another language, translate it into Japanese before answering."))
        assertTrue(prompt.contains("Earlier context:\nEarlier the user reported thick smoke in a hallway."))
        assertTrue(prompt.contains("Recent chat:\nU1: Found smoke in hallway\nB1: Stay low and move away from smoke."))
        assertTrue(prompt.contains("Last image context:\nPhoto suggested airway irritation and poor visibility near the doorway."))
        assertTrue(prompt.contains("User message:\nNeed help breathing in a fire."))
        assertTrue(prompt.contains("Retrieved knowledge for reference:\n[Authority] Keep low and avoid smoke."))
        assertTrue(prompt.contains("[Authority] Keep low and avoid smoke."))
        assertFalse(prompt.contains("CATEGORY_HINT"))
        assertFalse(prompt.contains("Respond only to the current situation."))
        assertFalse(prompt.contains("Use only the retrieved knowledge that matches this situation. Do not branch into unrelated emergencies."))
    }

    @Test
    fun `user prompt falls back cleanly when no knowledge base exists`() {
        val prompt = BeaconPromptComposer.buildUserPrompt(
            BeaconPromptTurn(
                locale = "en",
                powerMode = "doomsday",
                categoryHint = null,
                userText = "I feel wrong but cannot explain what happened.",
                groundingContext = null,
                hasAuthoritativeEvidence = false,
                sessionSummary = null,
                recentChatContext = null,
                lastVisualContext = null,
            ),
        )

        assertTrue(prompt.contains("Answer strictly in English."))
        assertTrue(prompt.contains("Write the final answer only in English. If retrieved knowledge is in another language, translate it into English before answering."))
        assertTrue(prompt.contains("User message:\nI feel wrong but cannot explain what happened."))
        assertTrue(prompt.contains("Retrieved knowledge for reference:\n(none)"))
        assertFalse(prompt.contains("Use only the retrieved knowledge that matches this situation. Do not branch into unrelated emergencies."))
    }

    @Test
    fun `turn prompt estimate grows with memory and image context`() {
        val promptChars = BeaconPromptComposer.estimateTurnPromptChars(
            userText = "I am lost in the forest and it is getting dark.",
            groundingContext = "Do: stay put, make yourself visible, keep warm.",
            sessionSummary = "Earlier the user said there is no cell service.",
            recentChatContext = "U1: I am lost\nB1: Stay calm and stay visible.",
            lastVisualContext = "The last photo showed fading daylight under tree cover.",
            hasImage = true,
        )

        assertTrue(promptChars > 200)
    }
}
