import 'package:flutter_test/flutter_test.dart';
import 'package:vibesight_tracker/models/misc.dart';

void main() {
  group('InboxItem media JSON roundtrip', () {
    test('image entry survives toJson/fromJson', () {
      final src = InboxItem(
        id: 'a1',
        content: 'Из инстаграма',
        createdAt: '2026-05-03T12:00:00.000Z',
        mediaPath: '/data/user/0/app/files/inbox_media/image_1.jpg',
        mediaType: 'image',
        mediaMime: 'image/jpeg',
      );
      final round = InboxItem.fromJson(src.toJson());
      expect(round.hasMedia, isTrue);
      expect(round.isImage, isTrue);
      expect(round.isVideo, isFalse);
      expect(round.mediaPath, src.mediaPath);
      expect(round.mediaMime, 'image/jpeg');
    });

    test('video entry preserves type', () {
      final src = InboxItem(
        id: 'a2',
        content: '',
        createdAt: '2026-05-03T12:00:00.000Z',
        mediaPath: '/data/user/0/app/files/inbox_media/video_1.mp4',
        mediaType: 'video',
        mediaMime: 'video/mp4',
      );
      final round = InboxItem.fromJson(src.toJson());
      expect(round.isVideo, isTrue);
      expect(round.mediaType, 'video');
    });

    test('plain text entry has no media flags', () {
      final src = InboxItem(
        id: 'a3',
        content: 'просто заметка',
        createdAt: '2026-05-03T12:00:00.000Z',
      );
      final round = InboxItem.fromJson(src.toJson());
      expect(round.hasMedia, isFalse);
      expect(round.isImage, isFalse);
      expect(round.isVideo, isFalse);
      expect(round.mediaPath, isNull);
    });

    test('copyWith keeps media when not overridden', () {
      final src = InboxItem(
        id: 'a4',
        content: '',
        createdAt: '2026-05-03T12:00:00.000Z',
        mediaPath: '/x.jpg',
        mediaType: 'image',
      );
      final updated = src.copyWith(pinned: true);
      expect(updated.mediaPath, '/x.jpg');
      expect(updated.pinned, isTrue);
    });
  });
}
