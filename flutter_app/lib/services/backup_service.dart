import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'storage.dart';

/// Full JSON export / import of every Hive entry.
class BackupService {
  BackupService._();

  static const _kVersion = 1;

  /// Writes the snapshot to a file in the app's documents directory and
  /// shows the system "Share" sheet so the user can save / send it.
  /// Returns the path of the file written.
  static Future<String> exportToFile() async {
    final snapshot = AppStorage.dumpAll();
    final payload = <String, dynamic>{
      'app': 'vibesight_tracker',
      'version': _kVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': snapshot,
    };
    final docs = await getApplicationDocumentsDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File(p.join(docs.path, 'vibesight_backup_$stamp.json'));
    await file.writeAsString(json.encode(payload));
    await Share.shareXFiles([XFile(file.path)],
        subject: 'Vibesight backup $stamp',
        text: 'Резервная копия данных Vibesight Tracker');
    return file.path;
  }

  /// Lets the user pick a backup file and restores it. Throws if the
  /// payload is malformed. Returns the number of keys imported, or null
  /// if the user cancelled.
  static Future<int?> importFromFile({bool replace = true}) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return null;
    final f = res.files.first;
    final bytes = f.bytes;
    final path = f.path;
    String raw;
    if (bytes != null) {
      raw = utf8.decode(bytes);
    } else if (path != null) {
      raw = await File(path).readAsString();
    } else {
      throw const FormatException('Не удалось прочитать файл');
    }
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
