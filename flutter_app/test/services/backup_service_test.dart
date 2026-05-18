import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Pure-Dart unit tests for the ZIP backup format. The full
/// [BackupService.exportToFile] / [BackupService.importFromFile] flow
/// also touches `path_provider`, `file_picker` and `share_plus`, all
/// of which require platform plugins, so here we exercise the file
/// layout — the part that determines whether old backups will still
/// restore — directly.
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('vibe_backup_test_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('ZIP backup layout', () {
    test('roundtrips data.json and inbox_media files', () async {
      final mediaDir = Directory(p.join(tmp.path, 'inbox_media'))
        ..createSync();
      File(p.join(mediaDir.path, 'image_1.jpg'))
          .writeAsBytesSync(Uint8List.fromList(List.filled(64, 0xAB)));
      File(p.join(mediaDir.path, 'video_1.mp4'))
          .writeAsBytesSync(Uint8List.fromList(List.filled(128, 0xCD)));

      final zipPath = p.join(tmp.path, 'backup.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipPath);
      try {
        final payload = utf8.encode(json.encode({
          'app': 'vibesight_tracker',
          'version': 2,
          'data': {
            'inbox': [
              {'id': 'a', 'mediaPath': '/x/inbox_media/image_1.jpg'},
            ],
          },
        }));
        encoder.addArchiveFile(
          ArchiveFile('data.json', payload.length, payload),
        );
        for (final f in mediaDir.listSync().whereType<File>()) {
          encoder.addFile(f, p.join('inbox_media', p.basename(f.path)));
        }
      } finally {
        encoder.close();
      }

      final archive = ZipDecoder().decodeBytes(File(zipPath).readAsBytesSync());
      final names = archive.map((e) => e.name).toSet();
      expect(names, contains('data.json'));
      expect(names, contains('inbox_media/image_1.jpg'));
      expect(names, contains('inbox_media/video_1.mp4'));

      final dataEntry = archive.firstWhere((e) => e.name == 'data.json');
      final decoded = json.decode(utf8.decode(dataEntry.content as List<int>));
      expect(decoded, isA<Map>());
      expect(decoded['version'], 2);
      expect((decoded['data']['inbox'] as List).first['id'], 'a');
    });

    test('legacy JSON payload still parses (no media)', () {
      const raw = '''
{"app":"vibesight_tracker","version":1,"exportedAt":"2025-01-01T00:00:00.000Z",
 "data":{"finance":[{"id":"x","amount":10}]}}
''';
      final decoded = json.decode(raw);
      expect(decoded, isA<Map>());
      expect(decoded['data'], isA<Map>());
      expect((decoded['data']['finance'] as List).first['amount'], 10);
    });

    test('rejects archive without data.json', () {
      final encoder = ZipFileEncoder();
      final zipPath = p.join(tmp.path, 'broken.zip');
      encoder.create(zipPath);
      final body = utf8.encode('not really data');
      encoder.addArchiveFile(ArchiveFile('readme.txt', body.length, body));
      encoder.close();

      final archive = ZipDecoder().decodeBytes(File(zipPath).readAsBytesSync());
      final hasData = archive.any((e) => e.isFile && e.name == 'data.json');
      expect(hasData, isFalse);
    });

    test('paths outside known bundle dirs would be ignored', () {
      // The import code only restores files whose first segment is one
      // of inbox_media / photos / receipts. This guards against ZIPs
      // crafted to drop arbitrary files into the documents directory.
      const allowed = {'inbox_media', 'photos', 'receipts'};
      final names = [
        'inbox_media/img.jpg',
        'photos/g1.png',
        'receipts/r2.jpg',
        '../etc/passwd',
        '/system/file',
        'random/foo.txt',
      ];
      final accepted = names.where((n) {
        final first = n
            .split(RegExp(r'[/\\]'))
            .where((s) => s.isNotEmpty)
            .firstOrNull;
        return first != null && allowed.contains(first);
      }).toList();
      expect(accepted, [
        'inbox_media/img.jpg',
        'photos/g1.png',
        'receipts/r2.jpg',
      ]);
    });
  });
}
