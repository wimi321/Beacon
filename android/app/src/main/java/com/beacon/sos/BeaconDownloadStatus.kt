package com.beacon.sos

internal enum class BeaconDownloadStatus(val wireValue: String) {
    NOT_DOWNLOADED("not_downloaded"),
    PARTIALLY_DOWNLOADED("partially_downloaded"),
    IN_PROGRESS("in_progress"),
    SUCCEEDED("succeeded"),
    FAILED("failed"),
}

internal data class BeaconDownloadProgressPayload(
    val receivedBytes: Long,
    val totalBytes: Long,
    val fraction: Double,
    val isResumed: Boolean,
    val status: BeaconDownloadStatus,
    val bytesPerSecond: Long,
    val remainingMs: Long,
    val errorMessage: String? = null,
    val done: Boolean = false,
)

internal class BeaconDownloadEstimator {
    private var baselineTimeMs: Long? = null
    private var baselineBytes: Long? = null

    fun sample(
        receivedBytes: Long,
        totalBytes: Long,
        isResumed: Boolean,
        status: BeaconDownloadStatus,
        nowMs: Long = System.currentTimeMillis(),
        errorMessage: String? = null,
        done: Boolean = false,
    ): BeaconDownloadProgressPayload {
        if (baselineTimeMs == null || baselineBytes == null) {
            baselineTimeMs = nowMs
            baselineBytes = receivedBytes
        }

        val startTime = baselineTimeMs ?: nowMs
        val startBytes = baselineBytes ?: receivedBytes
        val elapsedMs = (nowMs - startTime).coerceAtLeast(0L)
        val transferredBytes = (receivedBytes - startBytes).coerceAtLeast(0L)
        val bytesPerSecond =
            if (elapsedMs > 0L && transferredBytes > 0L) {
                (transferredBytes * 1000L) / elapsedMs
            } else {
                0L
            }
        val remainingMs =
            when {
                done -> 0L
                totalBytes <= 0L || receivedBytes >= totalBytes || bytesPerSecond <= 0L -> -1L
                else -> ((totalBytes - receivedBytes) * 1000L) / bytesPerSecond
            }

        return BeaconDownloadProgressPayload(
            receivedBytes = receivedBytes,
            totalBytes = totalBytes,
            fraction = if (totalBytes > 0L) receivedBytes.toDouble() / totalBytes.toDouble() else 0.0,
            isResumed = isResumed,
            status = status,
            bytesPerSecond = bytesPerSecond,
            remainingMs = remainingMs,
            errorMessage = errorMessage,
            done = done,
        )
    }
}
