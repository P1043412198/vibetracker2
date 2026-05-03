import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/misc.dart';
import '../state/providers.dart';
import 'link_preview_service.dart';

/// Receives Android Sharesheet (`ACTION_SEND` / `ACTION_SEND_MULTIPLE`)
/// hand-offs and stores them in the chat-style inbox.
///
/// Native side (`MainActivity`) packs a structured payload:
/// ```
/// {
///   "text": String?,
///   "media": [ {"path", "type": "image"|"video", "mime"}, ... ]
/// }
/// ```
/// We unpack here and create one [InboxItem] per media entry plus an
/// optional text-only entry, so each share lands as its own bubble in
/// the chat — matching how messengers display received attachments.
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
        await _ingest(ref, call.arguments);
      }
    });

    // Drain any cold-start payload that the activity captured before we
    // hooked up the channel.
    try {
      final pending = await _channel.invokeMethod<dynamic>('consumePending');
      if (pending != null) {
        await _ingest(ref, pending);
      }
    } catch (_) {
      // Channel might not be available outside Android — safe to ignore.
    }
  }

  /// Branch on payload shape. The new MainActivity always sends a Map; older
  /// builds (before this PR) sent a plain String, so we keep the String
  /// fallback for upgrade safety — otherwise the very first cold-start after
  /// install could lose a queued payload.
  Future<void> _ingest(WidgetRef ref, dynamic payload) async {
    if (payload is String && payload.isNotEmpty) {
      await _saveText(ref, payload);
      return;
    }
    if (payload is Map) {
      final text = payload['text'] as String?;
      final media = (payload['media'] as List?) ?? const [];
      // One inbox bubble per media item — the user gets each photo/video as
      // its own card, the same way Telegram renders forwarded media.
      for (final raw in media) {
        if (raw is! Map) continue;
        final path = raw['path'] as String?;
        if (path == null || path.isEmpty) continue;
        final type = (raw['type'] as String?) ?? 'image';
        final mime = raw['mime'] as String?;
        await _saveMedia(ref, path: path, type: type, mime: mime, caption: text);
      }
      // If there was text but no media, store it as a normal text entry.
      if (media.isEmpty && text != null && text.isNotEmpty) {
        await _saveText(ref, text);
      }
    }
  }

  Future<void> _saveText(WidgetRef ref, String content) async {
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
      // ignore: discarded_futures
      _hydrate(ref, id, parsed.url!);
    }
  }

  Future<void> _saveMedia(
    WidgetRef ref, {
    required String path,
    required String type,
    String? mime,
    String? caption,
  }) async {
    final cap = caption?.trim() ?? '';
    final tags = extractHashtags(cap);
    await ref.read(inboxProvider.notifier).add(
          InboxItem(
            id: const Uuid().v4(),
            content: cap,
            createdAt: DateTime.now().toIso8601String(),
            tags: tags.isEmpty ? null : tags,
            mediaPath: path,
            mediaType: type,
            mediaMime: mime,
          ),
        );
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
