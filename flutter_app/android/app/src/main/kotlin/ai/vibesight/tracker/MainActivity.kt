package ai.vibesight.tracker

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts a `MethodChannel` (Phase 10) so that Android Sharesheet (`ACTION_SEND`,
 * `text/plain`) handoffs are forwarded into Flutter and saved into the
 * "Заметки" sphere. This mirrors the React PWA's `share_target` manifest
 * entry that funnelled shares into `/share-target`.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "ai.vibesight.tracker/share"
    private var pendingShare: String? = null
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
        if (intent.action != Intent.ACTION_SEND) return
        if (intent.type != "text/plain") return
        val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return
        val title = intent.getStringExtra(Intent.EXTRA_SUBJECT)
        val payload = buildString {
            if (!title.isNullOrBlank()) {
                append("**$title**\n\n")
            }
            append(text)
        }
        if (fromCold) {
            pendingShare = payload
        } else {
            channel?.invokeMethod("onShare", payload)
        }
    }
}
