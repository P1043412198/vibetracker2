import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Stores receipt photos for transactions inside the app's documents
/// directory. Paths returned by [persist] are *relative* (e.g.
/// `receipts/2026-05/abc.jpg`) so that the JSON dump stays portable across
/// devices — call [resolve] before opening the file.
class ReceiptService {
  ReceiptService._();
  static final ReceiptService instance = ReceiptService._();

  static const _root = 'receipts';
  Directory? _docsDir;

  Future<Directory> _docs() async {
    return _docsDir ??= await getApplicationDocumentsDirectory();
  }

  /// Copy [source] into the receipts folder for [bucket] (typically the
  /// transaction's `yyyy-MM` month) and return the relative path.
  Future<String> persist(File source, {String? bucket}) async {
    final docs = await _docs();
    final folder = bucket ?? _monthBucket(DateTime.now());
    final dir = Directory(p.join(docs.path, _root, folder));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final ext = p.extension(source.path).isEmpty
        ? '.jpg'
        : p.extension(source.path);
    final name = '${const Uuid().v4()}$ext';
    final dest = File(p.join(dir.path, name));
    await source.copy(dest.path);
    return p.join(_root, folder, name);
  }

  /// Resolve a relative path returned by [persist] to an absolute [File].
  Future<File> resolve(String relativePath) async {
    final docs = await _docs();
    return File(p.join(docs.path, relativePath));
  }

  /// Best-effort delete; missing files are ignored.
  Future<void> remove(String relativePath) async {
    try {
      final file = await resolve(relativePath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  static String _monthBucket(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
}
