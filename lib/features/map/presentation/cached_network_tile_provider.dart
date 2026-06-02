import 'dart:async';
import 'dart:convert' show base64Url, utf8;
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path_provider/path_provider.dart';

class CachedNetworkTileProvider extends TileProvider {
  CachedNetworkTileProvider({
    super.headers,
    HttpClient? httpClient,
    this.maxCacheAge = const Duration(days: 7),
  }) : _httpClient =
           httpClient ??
           (HttpClient()..connectionTimeout = _tileRequestTimeout);

  static const Duration _tileRequestTimeout = Duration(seconds: 12);

  final HttpClient _httpClient;
  final Duration maxCacheAge;
  final Map<String, Future<File>> _pendingDownloads = <String, Future<File>>{};
  Future<Directory>? _cacheDirectory;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final String url = getTileUrl(coordinates, options);
    return _CachedTileImageProvider(
      url: url,
      resolveTileFile: () => _resolveTileFile(url),
    );
  }

  Future<File> _resolveTileFile(String url) async {
    final Uri uri = Uri.parse(url);
    final Directory directory = await _resolveCacheDirectory();
    final String fileName = _cacheFileName(uri);
    final File file = File(
      '${directory.path}${Platform.pathSeparator}$fileName',
    );

    if (await _isFresh(file)) {
      return file;
    }

    return _pendingDownloads.putIfAbsent(file.path, () async {
      try {
        if (await _isFresh(file)) {
          return file;
        }

        await file.parent.create(recursive: true);
        final bool hasStaleFile = await file.exists();

        try {
          await _downloadTile(url, file);
        } catch (error, stackTrace) {
          developer.log(
            'Failed to download tile $url, attempting stale fallback: $error',
            name: 'CachedNetworkTileProvider',
            error: error,
            stackTrace: stackTrace,
            level: 1000,
          );
          if (hasStaleFile) {
            return file;
          }
          rethrow;
        }

        return file;
      } finally {
        _pendingDownloads.remove(file.path);
      }
    });
  }

  Future<void> _downloadTile(String url, File file) async {
    final Uri uri = Uri.parse(url);
    final HttpClientRequest request = await _httpClient
        .getUrl(uri)
        .timeout(_tileRequestTimeout);
    headers.forEach(request.headers.set);

    final HttpClientResponse response = await request.close().timeout(
      _tileRequestTimeout,
    );
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Tile request failed with status ${response.statusCode}',
        uri: uri,
      );
    }

    final List<int> bytes = await consolidateHttpClientResponseBytes(
      response,
    ).timeout(_tileRequestTimeout);
    await file.writeAsBytes(bytes, flush: true);
  }

  Future<Directory> _resolveCacheDirectory() {
    return _cacheDirectory ??= () async {
      final Directory baseDirectory = await getTemporaryDirectory();
      final Directory tileDirectory = Directory(
        '${baseDirectory.path}${Platform.pathSeparator}rihla_map_tiles',
      );
      await tileDirectory.create(recursive: true);
      return tileDirectory;
    }();
  }

  Future<bool> _isFresh(File file) async {
    if (!await file.exists()) {
      return false;
    }

    final FileStat stat = await file.stat();
    if (stat.size <= 0) {
      return false;
    }

    return DateTime.now().difference(stat.modified) <= maxCacheAge;
  }

  String _cacheFileName(Uri uri) {
    final String encodedPath = base64Url.encode(utf8.encode(uri.path));
    return '${uri.host}_$encodedPath.tile';
  }

  @override
  void dispose() {
    _httpClient.close(force: true);
    super.dispose();
  }
}

@immutable
class _CachedTileImageProvider extends ImageProvider<_CachedTileImageProvider> {
  const _CachedTileImageProvider({
    required this.url,
    required this.resolveTileFile,
  });

  final String url;
  final Future<File> Function() resolveTileFile;

  @override
  Future<_CachedTileImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_CachedTileImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _CachedTileImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode),
      scale: 1,
      debugLabel: url,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<String>('URL', url),
        DiagnosticsProperty<_CachedTileImageProvider>('Provider', key),
      ],
    );
  }

  Future<Codec> _load(
    _CachedTileImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    try {
      final File tileFile = await resolveTileFile();
      final Uint8List bytes = await tileFile.readAsBytes();
      final ImmutableBuffer buffer = await ImmutableBuffer.fromUint8List(bytes);
      return decode(buffer);
    } catch (error) {
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is _CachedTileImageProvider && other.url == url);
  }

  @override
  int get hashCode => url.hashCode;
}
