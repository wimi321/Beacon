package com.beacon.sos

import android.content.Context
import android.util.Log
import com.google.gson.Gson
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

internal data class BeaconAllowedModel(
    val id: String,
    val tier: String,
    val name: String,
    val fileName: String,
    val sizeLabel: String,
    val downloadUrl: String,
    val sizeInBytes: Long,
    val defaultProfileName: String?,
    val recommendedFor: String?,
    val supportsImageInput: Boolean,
    val accelerators: List<String>,
)

internal data class BeaconModelAllowlist(
    val schemaVersion: Int,
    val updatedAt: String?,
    val refreshIntervalHours: Int,
    val remoteUrl: String?,
    val models: List<BeaconAllowedModel>,
)

internal object BeaconModelAllowlistRepository {
    private const val LOG_TAG = "BeaconAllowlist"
    private const val BUNDLED_ASSET_PATH = "public/model_allowlist.json"
    private const val CACHE_FILE_NAME = "model_allowlist_cache.json"
    private val gson = Gson()

    private data class RawAllowlist(
        val schemaVersion: Int? = 1,
        val updatedAt: String? = null,
        val refreshIntervalHours: Int? = 12,
        val remoteUrl: String? = null,
        val models: List<RawAllowedModel>? = emptyList(),
    )

    private data class RawAllowedModel(
        val id: String? = null,
        val tier: String? = null,
        val name: String? = null,
        val fileName: String? = null,
        val sizeLabel: String? = null,
        val downloadUrl: String? = null,
        val sizeInBytes: Long? = 0L,
        val defaultProfileName: String? = null,
        val recommendedFor: String? = null,
        val supportsImageInput: Boolean? = false,
        val accelerators: List<String>? = emptyList(),
    )

    fun load(context: Context): BeaconModelAllowlist {
        val bundled = loadBundled(context)
        val cached = loadCached(context) ?: return bundled
        return choosePreferred(bundled, cached)
    }

    fun refreshIfStale(context: Context, nowMs: Long = System.currentTimeMillis()): BeaconModelAllowlist? {
        val current = load(context)
        val remoteUrl = current.remoteUrl?.trim().orEmpty()
        if (remoteUrl.isEmpty()) {
            return null
        }

        val cacheFile = cacheFile(context)
        val refreshIntervalMs = current.refreshIntervalHours.coerceIn(1, 24 * 7) * 60L * 60L * 1000L
        if (cacheFile.exists()) {
            val ageMs = nowMs - cacheFile.lastModified()
            if (ageMs in 0 until refreshIntervalMs) {
                return null
            }
        }

        return try {
            val payload = fetch(remoteUrl)
            val parsed = parse(payload)
            cacheFile.parentFile?.mkdirs()
            cacheFile.writeText(payload)
            parsed
        } catch (error: Exception) {
            Log.w(LOG_TAG, "Failed to refresh allowlist from remote. Keeping bundled/cached copy.", error)
            null
        }
    }

    fun parse(json: String): BeaconModelAllowlist {
        val models = mutableListOf<BeaconAllowedModel>()
        val root = gson.fromJson(json, RawAllowlist::class.java)
        for (item in root.models.orEmpty()) {
            val id = item.id.orEmpty().trim()
            val tier = item.tier.orEmpty().trim()
            val name = item.name.orEmpty().trim()
            val fileName = item.fileName.orEmpty().trim()
            val sizeLabel = item.sizeLabel.orEmpty().trim()
            val downloadUrl = item.downloadUrl.orEmpty().trim()
            if (id.isEmpty() || tier.isEmpty() || name.isEmpty() || fileName.isEmpty() || downloadUrl.isEmpty()) {
                continue
            }

            models += BeaconAllowedModel(
                id = id,
                tier = tier,
                name = name,
                fileName = fileName,
                sizeLabel = sizeLabel.ifEmpty { name },
                downloadUrl = downloadUrl,
                sizeInBytes = item.sizeInBytes ?: 0L,
                defaultProfileName = item.defaultProfileName?.trim()?.ifEmpty { null },
                recommendedFor = item.recommendedFor?.trim()?.ifEmpty { null },
                supportsImageInput = item.supportsImageInput == true,
                accelerators = item.accelerators.orEmpty().map { it.trim() }.filter { it.isNotEmpty() },
            )
        }

        if (models.isEmpty()) {
            throw IllegalStateException("Model allowlist parsed but contained no valid models.")
        }

        return BeaconModelAllowlist(
            schemaVersion = root.schemaVersion ?: 1,
            updatedAt = root.updatedAt?.trim()?.ifEmpty { null },
            refreshIntervalHours = root.refreshIntervalHours ?: 12,
            remoteUrl = root.remoteUrl?.trim()?.ifEmpty { null },
            models = models,
        )
    }

    internal fun choosePreferred(
        bundled: BeaconModelAllowlist,
        cached: BeaconModelAllowlist,
    ): BeaconModelAllowlist {
        return if (compareSnapshots(cached, bundled) >= 0) {
            cached
        } else {
            bundled
        }
    }

    private fun compareSnapshots(
        left: BeaconModelAllowlist,
        right: BeaconModelAllowlist,
    ): Int {
        if (left.schemaVersion != right.schemaVersion) {
            return left.schemaVersion.compareTo(right.schemaVersion)
        }

        val leftUpdatedAt = left.updatedAt.orEmpty()
        val rightUpdatedAt = right.updatedAt.orEmpty()
        if (leftUpdatedAt != rightUpdatedAt) {
            return leftUpdatedAt.compareTo(rightUpdatedAt)
        }

        return left.models.size.compareTo(right.models.size)
    }

    private fun loadBundled(context: Context): BeaconModelAllowlist {
        context.assets.open(BUNDLED_ASSET_PATH).use { input ->
            return parse(input.bufferedReader().readText())
        }
    }

    private fun loadCached(context: Context): BeaconModelAllowlist? {
        val file = cacheFile(context)
        if (!file.exists()) {
            return null
        }

        return try {
            parse(file.readText())
        } catch (error: Exception) {
            Log.w(LOG_TAG, "Cached allowlist is invalid. Falling back to bundled copy.", error)
            file.delete()
            null
        }
    }

    private fun cacheFile(context: Context): File {
        return File(context.filesDir, CACHE_FILE_NAME)
    }

    private fun fetch(url: String): String {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.instanceFollowRedirects = true
        connection.connectTimeout = 10_000
        connection.readTimeout = 10_000
        connection.setRequestProperty("Accept", "application/json")
        connection.setRequestProperty("User-Agent", "Beacon/1.0")
        connection.connect()
        if (connection.responseCode !in 200..299) {
            throw IllegalStateException("Allowlist refresh failed with HTTP ${connection.responseCode}")
        }
        connection.inputStream.use { input ->
            return input.bufferedReader().readText()
        }
    }
}
