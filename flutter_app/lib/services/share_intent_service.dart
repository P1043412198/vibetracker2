import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/misc.dart';
import '../state/providers.dart';
import 'link_preview_service.dart';

/// Receives Android Sharesheet (`ACTION_SEND`, `text/plain`) handoffs and
/// stores them in the chat-style inbox. The pre-existing native side
/// (`MainActivity` + `ai.vibesight.tracker/share` channel) is unchanged —
/// only the Dart-side sink moved from the "Заметки" sphere to the inbox
/// so shared links land in the same place the user reads them.
class ShareIntentService {
  ShareIntentService._();
  static final ShareIntentService instance = ShareIntentService._();

  static const _channel = MethodChannel('ai.vibesight.tracker/share');
  bool _attached = false;

  Future<void> attach(WidgetRef ref) async {
    if (_attached) return;
    _attached = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShare') {
        final payload = call.arguments;
        if (payload is String && payload.isNotEmpty) {
          await _saveToInbox(ref, payload);
        }
      }
    });

    // Drain any cold-start payload that the activity captured before we
    // hooked up the channel.
    try {
      final pending = await _channel.invokeMethod<String?>('consumePending');
      if (pending != null && pending.isNotEmpty) {
        await _saveToInbox(ref, pending);
      }
    } catch (_) {
      // Channel might not be available outside Android — safe to ignore.
    }
  }

  Future<void> _saveToInbox(WidgetRef ref, String content) async {
    final parsed = parseFirstUrl(content);
    final tags = extractHashtags(content);
    final id = const Uuid().v4();
    final item = InboxItem(
      id: id,
      content: content,
      createdAt: DateTime.now().toIso8601String(),
      url: parsed.url,
      linkDomain: parsed.domain,
      platform: parsed.platform,
      tags: tags.isEmpty ? null : tags,
    );
    await ref.read(inboxProvider.notifier).add(item);

    if (parsed.isNotEmpty) {
      // Hydrate preview metadata in the background. Failures are silent —
      // the entry still shows the bare URL with a platform chip.
      // ignore: discarded_futures
      _hydrate(ref, id, parsed.url!);
    }
  }

  Future<void> _hydrate(WidgetRef ref, String id, String url) async {
    final preview = await fetchLinkPreview(url);
    if (preview.isEmpty) return;
    final list = ref.read(inboxProvider);
    InboxItem? existing;
    for (final e in list) {
      if (e.id == id) {
        existing = e;
        break;
      }
    }
    if (existing == null) return;
    await ref.read(inboxProvider.notifier).upsert(
          existing.copyWith(
            linkTitle: preview.title,
            linkImage: preview.imageUrl,
          ),
        );
  }
}
