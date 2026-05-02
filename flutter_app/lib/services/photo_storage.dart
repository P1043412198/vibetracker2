import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Owns the on-disk layout of user-attached photos at
/// `app_docs/{bucket}/{entityId}/{timestamp}.jpg`. Photos are kept inside
/// the app's documents directory so they survive app updates and aren't
/// subject to OS clean-up of cache/temp files.
class PhotoStorage {
  PhotoStorage._();
  static final PhotoStorage instance = PhotoStorage._();

  final ImagePicker _picker = ImagePicker();

  /// Pick a single image (gallery), copy it into our app documents and
  /// return the absolute on-disk path. Returns `null` if the user cancels.
  Future<String?> pickAndStore({
    required String bucket,
    required String entityId,
    int imageQuality = 85,
    int maxWidth = 2400,
  }) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: imageQuality,
      maxWidth: maxWidth.toDouble(),
    );
    if (picked == null) return null;
    return _copyInto(picked, bucket: bucket, entityId: entityId);
  }

  /// Variant that opens the camera directly. Same return semantics.
  Future<String?> captureAndStore({
    required String bucket,
    required String entityId,
    int imageQuality = 85,
    int maxWidth = 2400,
  }) async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: imageQuality,
      maxWidth: maxWidth.toDouble(),
    );
    if (picked == null) return null;
    return _copyInto(picked, bucket: bucket, entityId: entityId);
  }

  Future<String> _copyInto(
    XFile picked, {
    required String bucket,
    required String entityId,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, bucket, entityId));
    await dir.create(recursive: true);
    final ext = p.extension(picked.path).isEmpty
        ? '.jpg'
        : p.extension(picked.path);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final dst = p.join(dir.path, '$ts$ext');
    await File(picked.path).copy(dst);
    return dst;
  }

  /// Best-effort delete; missing files are ignored.
  Future<void> delete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
