package com.beacon.sos

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import kotlin.io.path.createTempDirectory

class BeaconModelFilesTest {
    @Test
    fun `resolve treats undersized primary file as resumable partial`() {
        val primaryDir = createTempDirectory(prefix = "beacon-primary").toFile()
        val legacyDir = createTempDirectory(prefix = "beacon-legacy").toFile()
        try {
            val partial = File(primaryDir, "gemma.litertlm")
            partial.writeBytes(ByteArray(256))

            val resolved = BeaconModelFiles.resolve(
                fileName = "gemma.litertlm",
                expectedBytes = 1024L,
                primaryDir = primaryDir,
                legacyDir = legacyDir,
            )

            assertEquals(BeaconDownloadStatus.PARTIALLY_DOWNLOADED, resolved.downloadStatus)
            assertEquals(partial.absolutePath, resolved.resumableFile?.absolutePath)
            assertEquals(null, resolved.completeFile)
        } finally {
            primaryDir.deleteRecursively()
            legacyDir.deleteRecursively()
        }
    }

    @Test
    fun `resolve prefers complete primary file over partial artifacts`() {
        val primaryDir = createTempDirectory(prefix = "beacon-primary").toFile()
        val legacyDir = createTempDirectory(prefix = "beacon-legacy").toFile()
        try {
            val primary = File(primaryDir, "gemma.litertlm")
            val partial = File(primary.absolutePath + ".part")
            primary.writeBytes(ByteArray(2048))
            partial.writeBytes(ByteArray(512))

            val resolved = BeaconModelFiles.resolve(
                fileName = "gemma.litertlm",
                expectedBytes = 1024L,
                primaryDir = primaryDir,
                legacyDir = legacyDir,
            )

            assertEquals(BeaconDownloadStatus.SUCCEEDED, resolved.downloadStatus)
            assertEquals(primary.absolutePath, resolved.completeFile?.absolutePath)
            assertFalse(resolved.completeFileNeedsFinalize)
            assertEquals(null, resolved.resumableFile)
        } finally {
            primaryDir.deleteRecursively()
            legacyDir.deleteRecursively()
        }
    }

    @Test
    fun `replaceFile copies source when renaming into destination`() {
        val primaryDir = createTempDirectory(prefix = "beacon-primary").toFile()
        try {
            val source = File(primaryDir, "model.part")
            val destination = File(primaryDir, "model.litertlm")
            source.writeBytes(ByteArray(128))

            val replaced = BeaconModelFiles.replaceFile(source, destination)

            assertTrue(replaced)
            assertTrue(destination.exists())
            assertEquals(128L, destination.length())
            assertFalse(source.exists())
        } finally {
            primaryDir.deleteRecursively()
        }
    }

    @Test
    fun `resolve marks completed part file as finalized candidate`() {
        val primaryDir = createTempDirectory(prefix = "beacon-primary").toFile()
        val legacyDir = createTempDirectory(prefix = "beacon-legacy").toFile()
        try {
            val partial = File(primaryDir, "gemma.litertlm.part")
            partial.writeBytes(ByteArray(2048))

            val resolved = BeaconModelFiles.resolve(
                fileName = "gemma.litertlm",
                expectedBytes = 1024L,
                primaryDir = primaryDir,
                legacyDir = legacyDir,
            )

            assertEquals(BeaconDownloadStatus.SUCCEEDED, resolved.downloadStatus)
            assertNotNull(resolved.completeFile)
            assertTrue(resolved.completeFileNeedsFinalize)
            assertEquals(partial.absolutePath, resolved.completeFile?.absolutePath)
        } finally {
            primaryDir.deleteRecursively()
            legacyDir.deleteRecursively()
        }
    }
}
