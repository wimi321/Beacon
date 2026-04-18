package com.beacon.sos

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BeaconDownloadEstimatorTest {
    @Test
    fun `sample reports speed and remaining time once transfer advances`() {
        val estimator = BeaconDownloadEstimator()

        estimator.sample(
            receivedBytes = 100L,
            totalBytes = 1000L,
            isResumed = true,
            status = BeaconDownloadStatus.PARTIALLY_DOWNLOADED,
            nowMs = 1_000L,
        )
        val progress = estimator.sample(
            receivedBytes = 600L,
            totalBytes = 1000L,
            isResumed = true,
            status = BeaconDownloadStatus.IN_PROGRESS,
            nowMs = 2_000L,
        )

        assertEquals(500L, progress.bytesPerSecond)
        assertEquals(800L, progress.remainingMs)
        assertEquals(BeaconDownloadStatus.IN_PROGRESS, progress.status)
    }

    @Test
    fun `sample marks terminal progress as done with zero remaining time`() {
        val estimator = BeaconDownloadEstimator()
        val progress = estimator.sample(
            receivedBytes = 1000L,
            totalBytes = 1000L,
            isResumed = false,
            status = BeaconDownloadStatus.SUCCEEDED,
            nowMs = 5_000L,
            done = true,
        )

        assertTrue(progress.done)
        assertEquals(0L, progress.remainingMs)
        assertEquals(BeaconDownloadStatus.SUCCEEDED, progress.status)
    }
}
