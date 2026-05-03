import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'storage.dart';

/// Full backup of every Hive entry **plus** all referenced media files
/// (inbox attachments, goal photos, scanned receipts).
///
/// Two file formats are supported on import:
/// * **ZIP** (current) — `data.json` at root + `inbox_media/`, `photos/`,
///   `receipts/` directories with binary blobs. This is what
///   [exportToFile] produces.
/// * **JSON** (legacy v1) — a single JSON object with `data` field. We
///   keep this branch so old backups don't suddenly break after the
///   user upgrades.
class BackupService {
  BackupService._();

  static const _kVersion = 2;

  /// Hive key used to remember when the user last exported. Drives the
  /// backup-reminder banner in Settings.
  static const _kLastExportKey = '_meta_lastBackupAt';

  /// Subdirectories inside `getApplicationDocumentsDirectory()` that
  /// should be slurped into the ZIP. Order matches the layout the
  /// import code looks for.
  static const _bundledDirs = <String>[
    'inbox_media',
    'photos',
    'receipts',
  ];

  /// Read the ISO-8601 timestamp of the last successful export, or
  /// `null` if the user has never backed up.
  static DateTime? lastExportAt() {
    final raw = AppStorage.readString(_kLastExportKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  /// Produce a backup ZIP, hand it to the system "Share" sheet so the
  /// user can stash it in Telegram saved-messages / Drive / email, and
  /// return the local path.
  ///
  /// The ZIP layout:
  /// ```
  /// data.json                 # whole Hive snapshot + meta
  /// inbox_media/<file>        # attachments referenced by InboxItem
  /// photos/<file>             # goal/sphere photos
  /// receipts/<file>           # OCR-scanned receipts
  /// ```
  static Future<String> exportToFile() async {
    final docs = await getApplicationDocumentsDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final out = File(p.join(docs.path, 'vibesight_backup_$stamp.zip'));

    final encoder = ZipFileEncoder();
    encoder.create(out.path);
    try {
      // 1. Hive snapshot.
      final snapshot = AppStorage.dumpAll();
      final payload = <String, dynamic>{
        'app': 'vibesight_tracker',
        'version': _kVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'data': snapshot,
      };
      final jsonBytes = utf8.encode(json.encode(payload));
      encoder.addArchiveFile(
        ArchiveFile('data.json', jsonBytes.length, jsonBytes),
      );

      // 2. Bundle every media-bearing subdir if it exists.
      for (final sub in _bundledDirs) {
        final dir = Directory(p.join(docs.path, sub));
        if (!await dir.exists()) continue;
        final entries = dir.listSync(recursive: true, followLinks: false);
        for (final entry in entries) {
          if (entry is! File) continue;
          final relative = p.join(sub, p.relative(entry.path, from: dir.path));
          encoder.addFile(entry, relative);
        }
      }
    } finally {
      encoder.close();
    }

    await AppStorage.writeString(
      _kLastExportKey,
      DateTime.now().toIso8601String(),
    );

    await Share.shareXFiles(
      [XFile(out.path)],
      subject: 'Vibesight backup $stamp',
      text: 'Резервная копия Vibesight Tracker',
    );
    return out.path;
  }

  /// Let the user pick a backup file (ZIP **or** legacy JSON) and
  /// restore everything. Returns the number of Hive sections imported,
  /// or `null` if the user cancelled. Throws [FormatException] when the
  /// file is malformed.
  static Future<int?> importFromFile({bool replace = true}) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'json'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return null;
    final f = res.files.first;
    final ext = p.extension(f.name).toLowerCase();
    final bytes = f.bytes ?? await File(f.path!).readAsBytes();

    if (ext == '.zip') {
      return _importZip(bytes, replace: replace);
    }
    return _importJson(utf8.decode(bytes), replace: replace);
  }

  static Future<int> _importZip(
    List<int> bytes, {
    required bool replace,
  }) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? dataFile;
    for (final entry in archive) {
      if (entry.isFile && entry.name == 'data.json') {
        dataFile = entry;
        break;
      }
    }
    if (dataFile == null) {
      throw const FormatException(
          'В ZIP-архиве нет data.json — это не наш бэкап');
    }
    final imported = await _importJson(
      utf8.decode(dataFile.content as List<int>),
      replace: replace,
    );

    // Restore media subdirs alongside Hive content. We preserve the
    // original relative paths so InboxItem.mediaPath, goal photos,
    // receipts etc. point to the same on-disk locations after import.
    final docs = await getApplicationDocumentsDirectory();
    for (final entry in archive) {
      if (!entry.isFile) continue;
      if (entry.name == 'data.json') continue;
      // Ignore files outside the known bundle dirs to avoid path
      // traversal via crafted ZIPs.
      final firstSeg =
          entry.name.split(RegExp(r'[/\\]')).where((s) => s.isNotEmpty).firstOrNull;
      if (firstSeg == null || !_bundledDirs.contains(firstSeg)) continue;
      final dst = File(p.join(docs.path, entry.name));
      await dst.parent.create(recursive: true);
      await dst.writeAsBytes(entry.content as List<int>);
    }
    return imported;
  }

  static Future<int> _importJson(
    String raw, {
    required bool replace,
  }) async {
    final decoded = json.decode(raw);
    if (decoded is! Map) {
      throw const FormatException('Файл не содержит JSON-объекта');
    }
    final data = decoded['data'];
    if (data is! Map) {
      throw const FormatException('В файле нет поля «data»');
    }
    final typed = data.map((k, v) => MapEntry(k.toString(), v));
    await AppStorage.restoreAll(typed, replace: replace);
    return typed.length;
  }
}

