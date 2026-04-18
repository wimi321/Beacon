package com.beacon.sos

import java.io.File

internal data class BeaconResolvedModelFiles(
    val primaryFile: File,
    val partialFile: File,
    val legacyFile: File,
    val completeFile: File?,
    val completeFileNeedsFinalize: Boolean,
    val resumableFile: File?,
    val downloadStatus: BeaconDownloadStatus,
)

internal object BeaconModelFiles {
    fun resolve(
        fileName: String,
        expectedBytes: Long,
        primaryDir: File,
        legacyDir: File,
    ): BeaconResolvedModelFiles {
        val primaryFile = File(primaryDir, fileName)
        val partialFile = File(primaryFile.absolutePath + ".part")
        val legacyFile = File(legacyDir, fileName)
        val normalizedExpectedBytes = expectedBytes.coerceAtLeast(0L)

        if (isComplete(primaryFile, normalizedExpectedBytes)) {
            return BeaconResolvedModelFiles(
                primaryFile = primaryFile,
                partialFile = partialFile,
                legacyFile = legacyFile,
                completeFile = primaryFile,
                completeFileNeedsFinalize = false,
                resumableFile = null,
                downloadStatus = BeaconDownloadStatus.SUCCEEDED,
            )
        }

        if (isComplete(legacyFile, normalizedExpectedBytes)) {
            return BeaconResolvedModelFiles(
                primaryFile = primaryFile,
                partialFile = partialFile,
                legacyFile = legacyFile,
                completeFile = legacyFile,
                completeFileNeedsFinalize = false,
                resumableFile = null,
                downloadStatus = BeaconDownloadStatus.SUCCEEDED,
            )
        }

        if (isComplete(partialFile, normalizedExpectedBytes)) {
            return BeaconResolvedModelFiles(
                primaryFile = primaryFile,
                partialFile = partialFile,
                legacyFile = legacyFile,
                completeFile = partialFile,
                completeFileNeedsFinalize = true,
                resumableFile = null,
                downloadStatus = BeaconDownloadStatus.SUCCEEDED,
            )
        }

        val resumableFile = listOf(partialFile, primaryFile, legacyFile).firstOrNull {
            isPartial(it, normalizedExpectedBytes)
        }

        return BeaconResolvedModelFiles(
            primaryFile = primaryFile,
            partialFile = partialFile,
            legacyFile = legacyFile,
            completeFile = null,
            completeFileNeedsFinalize = false,
            resumableFile = resumableFile,
            downloadStatus = if (resumableFile != null) {
                BeaconDownloadStatus.PARTIALLY_DOWNLOADED
            } else {
                BeaconDownloadStatus.NOT_DOWNLOADED
            },
        )
    }

    fun replaceFile(source: File, destination: File): Boolean {
        if (!source.exists()) {
            return false
        }

        if (source.absolutePath == destination.absolutePath) {
            return true
        }

        destination.parentFile?.mkdirs()
        if (destination.exists() && !destination.delete()) {
            return false
        }

        if (source.renameTo(destination)) {
            return true
        }

        return try {
            source.inputStream().use { input ->
                destination.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
            source.delete()
        } catch (_: Exception) {
            destination.delete()
            false
        }
    }

    private fun isComplete(file: File, expectedBytes: Long): Boolean {
        if (!file.exists() || !file.isFile) {
            return false
        }
        val actualBytes = file.length()
        if (actualBytes <= 0L) {
            return false
        }
        return expectedBytes <= 0L || actualBytes >= expectedBytes
    }

    private fun isPartial(file: File, expectedBytes: Long): Boolean {
        if (!file.exists() || !file.isFile) {
            return false
        }
        val actualBytes = file.length()
        if (actualBytes <= 0L) {
            return false
        }
        return expectedBytes <= 0L || actualBytes < expectedBytes
    }
}
