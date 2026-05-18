package ai.vibesight.tracker

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Hosts a `MethodChannel` (Phase 10 + chat-inbox) so that Android Sharesheet
 * (`ACTION_SEND` / `ACTION_SEND_MULTIPLE`) handoffs are forwarded into Flutter
 * and saved into the chat inbox.
 *
 * Supported MIME types: text/plain, any image, any video. Media files are
 * copied into the app's private `filesDir/inbox_media/` so the source URI's
 * grant lifecycle doesn't matter — Flutter then renders them straight from
 * disk via `Image.file` / system video viewer.
 *
 * The payload sent to Dart is a `Map<String, Any?>`:
 * ```
 * {
 *   "text": String?,            // EXTRA_TEXT (+ EXTRA_SUBJECT if present)
 *   "media": [                  // empty when only text was shared
 *     { "path": String, "type": "image"|"video", "mime": String }, ...
 *   ]
 * }
 * ```
 */
// local_auth requires the host to extend FlutterFragmentActivity (not the
// default FlutterActivity) so it can show its own BiometricPrompt fragment.
class MainActivity : FlutterFragmentActivity() {
    private val channelName = "ai.vibesight.tracker/share"
    private var pendingShare: Map<String, Any?>? = null
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "consumePending" -> {
                    val pending = pendingShare
                    pendingShare = null
                    result.success(pending)
                }
                else -> result.notImplemented()
            }
        }
        intent?.let { handleIntent(it, fromCold = true) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent, fromCold = false)
    }

    private fun handleIntent(intent: Intent, fromCold: Boolean) {
        val payload = when (intent.action) {
            Intent.ACTION_SEND -> buildSinglePayload(intent)
            Intent.ACTION_SEND_MULTIPLE -> buildMultiPayload(intent)
            else -> null
        } ?: return
        if (fromCold) {
            pendingShare = payload
        } else {
            channel?.invokeMethod("onShare", payload)
        }
    }

    private fun buildSinglePayload(intent: Intent): Map<String, Any?>? {
        val text = combine(
            intent.getStringExtra(Intent.EXTRA_SUBJECT),
            intent.getStringExtra(Intent.EXTRA_TEXT),
        )
        val type = intent.type ?: ""
        val media = mutableListOf<Map<String, Any?>>()
        @Suppress("DEPRECATION")
        val streamUri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
        if (streamUri != null) {
            saveUri(streamUri, type)?.let { media.add(it) }
        }
        if (text == null && media.isEmpty()) return null
        return mapOf("text" to text, "media" to media)
    }

    private fun buildMultiPayload(intent: Intent): Map<String, Any?>? {
        val text = combine(
            intent.getStringExtra(Intent.EXTRA_SUBJECT),
            intent.getStringExtra(Intent.EXTRA_TEXT),
        )
        val type = intent.type ?: ""
        val media = mutableListOf<Map<String, Any?>>()
        @Suppress("DEPRECATION")
        val uris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
        if (uris != null) {
            for (uri in uris) {
                saveUri(uri, type)?.let { media.add(it) }
            }
        }
        if (text == null && media.isEmpty()) return null
        return mapOf("text" to text, "media" to media)
    }

    private fun combine(title: String?, text: String?): String? {
        val cleanText = text?.takeIf { it.isNotBlank() }
        if (title.isNullOrBlank() && cleanText == null) return null
        if (title.isNullOrBlank()) return cleanText
        if (cleanText == null) return title
        return "**$title**\n\n$cleanText"
    }

    /**
     * Copy a content:// URI shared by another app into our private files
     * directory, returning its persistent absolute path together with the
     * coarse "image"/"video" kind and the original mime. We always copy —
     * the source URI's grant evaporates as soon as the activity is gone.
     */
    private fun saveUri(uri: Uri, fallbackMime: String): Map<String, Any?>? {
        return try {
            val resolver = contentResolver
            val mime = resolver.getType(uri) ?: fallbackMime
            val kind = when {
                mime.startsWith("image/") -> "image"
                mime.startsWith("video/") -> "video"
                else -> return null
            }
            val ext = extensionFor(mime, kind)
            val dir = File(filesDir, "inbox_media")
            if (!dir.exists()) dir.mkdirs()
            val ts = SimpleDateFormat("yyyyMMdd_HHmmss_SSS", Locale.US).format(Date())
            val out = File(dir, "${kind}_$ts.$ext")
            resolver.openInputStream(uri)?.use { input ->
                out.outputStream().use { output ->
                    input.copyTo(output)
                }
            } ?: return null
            mapOf(
                "path" to out.absolutePath,
                "type" to kind,
                "mime" to mime,
            )
        } catch (e: Exception) {
            null
        }
    }

    private fun extensionFor(mime: String, kind: String): String = when {
        mime.contains("jpeg") -> "jpg"
        mime.contains("png") -> "png"
        mime.contains("gif") -> "gif"
        mime.contains("webp") -> "webp"
        mime.contains("heic") -> "heic"
        mime.contains("mp4") -> "mp4"
        mime.contains("quicktime") -> "mov"
        mime.contains("3gpp") -> "3gp"
        mime.contains("webm") -> "webm"
        mime.contains("matroska") -> "mkv"
        else -> if (kind == "image") "jpg" else "mp4"
    }
}
