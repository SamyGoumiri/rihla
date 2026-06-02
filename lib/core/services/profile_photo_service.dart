import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePhotoResult {
  const ProfilePhotoResult.success(this.path)
    : error = null,
      isCancelled = false;
  const ProfilePhotoResult.error(this.error) : path = null, isCancelled = false;
  const ProfilePhotoResult.cancelled()
    : path = null,
      error = null,
      isCancelled = true;

  final String? path;
  final String? error;
  final bool isCancelled;
}

class ProfilePhotoService {
  ProfilePhotoService({
    ImagePicker? imagePicker,
    Future<Directory> Function()? documentsDirectoryProvider,
    SupabaseClient? supabaseClient,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
       _supabaseClient = supabaseClient;

  static const String _bucket = 'avatars';
  static const int _maxPhotoBytes = 4 * 1024 * 1024;
  static const int _maxPhotoDimension = 1280;
  static const Set<String> _allowedExtensions = <String>{
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
  };

  static String _remotePathFor(String uid, String extension) =>
      '$uid/avatar$extension';

  static const Map<String, String> _mimeTypes = <String, String>{
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.webp': 'image/webp',
  };

  final ImagePicker _imagePicker;
  final Future<Directory> Function() _documentsDirectoryProvider;
  final SupabaseClient? _supabaseClient;

  SupabaseClient get _client {
    final injected = _supabaseClient;
    if (injected != null) return injected;
    try {
      return Supabase.instance.client;
    } on Object catch (e) {
      throw StateError(
        'Supabase non configuré : photo de profil distante indisponible. '
        'Relancez avec --dart-define=SUPABASE_URL=... '
        '--dart-define=SUPABASE_ANON_KEY=... ($e)',
      );
    }
  }

  Future<ProfilePhotoResult> pickAndPersist({String? previousPhotoPath}) async {
    final XFile? photo;
    try {
      photo = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: _maxPhotoDimension.toDouble(),
        maxHeight: _maxPhotoDimension.toDouble(),
      );
    } catch (_) {
      return const ProfilePhotoResult.error('Impossible d\'ouvrir la galerie.');
    }

    if (photo == null) {
      return const ProfilePhotoResult.cancelled();
    }

    final extension = _extensionOf(photo.path);
    if (!_allowedExtensions.contains(extension)) {
      return const ProfilePhotoResult.error(
        'Format non supporté. Utilisez JPG, PNG ou WebP.',
      );
    }

    final sourceFile = File(photo.path);
    if (!sourceFile.existsSync()) {
      return const ProfilePhotoResult.error('Image introuvable.');
    }

    final size = await sourceFile.length();
    if (size > _maxPhotoBytes) {
      return const ProfilePhotoResult.error(
        'Image trop volumineuse (max 4 Mo).',
      );
    }

    final persistedPath = await _persistLocally(
      sourceFile,
      extension,
      previousPhotoPath: previousPhotoPath,
    );
    return ProfilePhotoResult.success(persistedPath);
  }

  Future<void> clearPhoto(String previousPhotoPath) async {
    if (previousPhotoPath.isEmpty) return;
    final file = File(previousPhotoPath);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  Future<String?> uploadToCloud({
    required String uid,
    required String localPath,
  }) async {
    if (uid.isEmpty || localPath.isEmpty) return null;
    final file = File(localPath);
    if (!file.existsSync()) return null;
    final ext = _extensionOf(localPath);
    if (!_allowedExtensions.contains(ext)) return null;

    try {
      final Uint8List bytes = await file.readAsBytes();
      final String path = _remotePathFor(uid, ext);
      await _client.storage
          .from(_bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: _mimeTypes[ext] ?? 'image/jpeg',
              upsert: true,
            ),
          );
      return _client.storage.from(_bucket).getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteRemote({required String uid}) async {
    if (uid.isEmpty) return;
    final paths = _allowedExtensions
        .map((ext) => _remotePathFor(uid, ext))
        .toList();
    try {
      await _client.storage.from(_bucket).remove(paths);
    } catch (_) {}
  }

  Future<String> _persistLocally(
    File sourceFile,
    String extension, {
    String? previousPhotoPath,
  }) async {
    final appDir = await _documentsDirectoryProvider();
    final profilePhotosDir = Directory(
      '${appDir.path}${Platform.pathSeparator}profile_photos',
    );
    if (!profilePhotosDir.existsSync()) {
      await profilePhotosDir.create(recursive: true);
    }

    final fileName =
        'profile_${DateTime.now().millisecondsSinceEpoch}$extension';
    final destinationPath =
        '${profilePhotosDir.path}${Platform.pathSeparator}$fileName';
    final copiedFile = await sourceFile.copy(destinationPath);

    if (previousPhotoPath != null &&
        previousPhotoPath.isNotEmpty &&
        previousPhotoPath != copiedFile.path) {
      final previous = File(previousPhotoPath);
      if (previous.existsSync()) {
        await previous.delete();
      }
    }

    return copiedFile.path;
  }

  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return '';
    return path.substring(dot).toLowerCase();
  }
}
