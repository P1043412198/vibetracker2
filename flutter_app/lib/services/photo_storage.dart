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

  /// Absolute path of the app documents directory, cached at startup so it can
  /// be joined with stored **relative** paths synchronously (e.g. in
  /// `Image.file`). The container path can change across app updates on iOS,
  /// which is why we persist relative paths and re-root them at read time.
  String? _docsPath;

  /// Must be called once during app startup (after the binding is ready).
  Future<void> init() async {
    _docsPath = (await getApplicationDocumentsDirectory()).path;
  }

  String? get docsPath => _docsPath;

  /// Resolve a stored photo reference to an absolute path usable by
  /// `File`/`Image.file`. Accepts both new relative paths
  /// (`bucket/entity/ts.jpg`) and legacy absolute paths; legacy paths whose
  /// container moved are re-rooted under the current documents directory.
  String resolve(String stored) {
    if (stored.isEmpty) return stored;
    final docs = _docsPath;
    // Relative path → join with the documents directory.
    if (!p.isAbsolute(stored)) {
      return docs == null ? stored : p.join(docs, stored);
    }
    // Absolute path that still exists → use as-is.
    if (File(stored).existsSync()) return stored;
    // Absolute path whose container moved: re-root the tail under docs.
    if (docs != null) {
      final rel = _relativeTail(stored);
      if (rel != null) {
        final candidate = p.join(docs, rel);
        if (File(candidate).existsSync()) return candidate;
      }
    }
    return stored;
  }

  /// Extract the `bucket/entity/file` tail from a legacy absolute path by
  /// looking for a known bucket segment.
  String? _relativeTail(String absolute) {
    final parts = p.split(absolute);
    for (var i = 0; i < parts.length; i++) {
      if (_knownBuckets.contains(parts[i])) {
        return p.joinAll(parts.sublist(i));
      }
    }
    return null;
  }

  static const _knownBuckets = {
    'body_photos',
    'sphere_photos',
    'goal_photos',
  };

  /// Pick a single image (gallery), copy it into our app documents and
  /// return a path relative to the documents directory. Returns `null` if the
  /// user cancels.
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
    _docsPath ??= docs.path;
    final dir = Directory(p.join(docs.path, bucket, entityId));
    await dir.create(recursive: true);
    final ext = p.extension(picked.path).isEmpty
        ? '.jpg'
        : p.extension(picked.path);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final dst = p.join(dir.path, '$ts$ext');
    await File(picked.path).copy(dst);
    // Store relative to the documents directory so the reference survives
    // container-path changes across app updates (esp. iOS).
    return p.join(bucket, entityId, '$ts$ext');
  }

  /// Best-effort delete; missing files are ignored. Accepts relative or
  /// legacy absolute references.
  Future<void> delete(String path) async {
    try {
      final f = File(resolve(path));
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
