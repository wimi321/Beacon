package com.beacon.sos

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BeaconModelAllowlistRepositoryTest {
    @Test
    fun `parse builds valid model entries from json allowlist`() {
        val allowlist = BeaconModelAllowlistRepository.parse(
            """
            {
              "schemaVersion": 1,
              "refreshIntervalHours": 12,
              "remoteUrl": "https://example.com/model_allowlist.json",
              "models": [
                {
                  "id": "gemma-4-e2b",
                  "tier": "e2b",
                  "name": "Gemma 4 E2B",
                  "fileName": "gemma-4-E2B-it.litertlm",
                  "sizeLabel": "2B / Survival Baseline",
                  "downloadUrl": "https://example.com/e2b.litertlm",
                  "sizeInBytes": 123,
                  "defaultProfileName": "gemma-4-e2b-balanced",
                  "recommendedFor": "Default offline triage",
                  "supportsImageInput": false,
                  "accelerators": ["gpu", "cpu"]
                }
              ]
            }
            """.trimIndent(),
        )

        assertEquals(1, allowlist.models.size)
        assertEquals("https://example.com/model_allowlist.json", allowlist.remoteUrl)
        assertEquals("gemma-4-e2b", allowlist.models.first().id)
        assertEquals(listOf("gpu", "cpu"), allowlist.models.first().accelerators)
        assertFalse(allowlist.models.first().supportsImageInput)
    }

    @Test
    fun `parse ignores malformed rows but keeps valid models`() {
        val allowlist = BeaconModelAllowlistRepository.parse(
            """
            {
              "models": [
                {
                  "id": "",
                  "tier": "e2b",
                  "name": "Broken",
                  "fileName": "broken.litertlm",
                  "downloadUrl": "https://example.com/broken"
                },
                {
                  "id": "gemma-4-e4b",
                  "tier": "e4b",
                  "name": "Gemma 4 E4B",
                  "fileName": "gemma-4-E4B-it.litertlm",
                  "sizeLabel": "4B / High Precision",
                  "downloadUrl": "https://example.com/e4b.litertlm"
                }
              ]
            }
            """.trimIndent(),
        )

        assertEquals(1, allowlist.models.size)
        assertEquals("gemma-4-e4b", allowlist.models.first().id)
        assertTrue(allowlist.models.first().sizeLabel.contains("High Precision"))
    }

    @Test
    fun `choosePreferred keeps bundled snapshot when it is newer than cache`() {
        val bundled = BeaconModelAllowlist(
            schemaVersion = 2,
            updatedAt = "2026-04-12",
            refreshIntervalHours = 12,
            remoteUrl = "https://example.com/bundled.json",
            models = listOf(
                BeaconAllowedModel(
                    id = "gemma-4-e2b",
                    tier = "e2b",
                    name = "Gemma 4 E2B",
                    fileName = "gemma-4-E2B-it.litertlm",
                    sizeLabel = "2B",
                    downloadUrl = "https://example.com/e2b",
                    sizeInBytes = 123,
                    defaultProfileName = null,
                    recommendedFor = null,
                    supportsImageInput = false,
                    accelerators = listOf("gpu"),
                ),
            ),
        )
        val cached = bundled.copy(schemaVersion = 1, updatedAt = "2026-04-10")

        val preferred = BeaconModelAllowlistRepository.choosePreferred(bundled, cached)

        assertEquals(bundled, preferred)
    }
}
