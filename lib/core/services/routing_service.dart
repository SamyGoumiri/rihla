import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

enum TransportProfile { driving, walking, cycling }

extension TransportProfileLabel on TransportProfile {
  String get label {
    switch (this) {
      case TransportProfile.driving:
        return 'Voiture';
      case TransportProfile.walking:
        return 'À pied';
      case TransportProfile.cycling:
        return 'Vélo';
    }
  }

  String get osrmServerSlug {
    switch (this) {
      case TransportProfile.driving:
        return 'routed-car';
      case TransportProfile.walking:
        return 'routed-foot';
      case TransportProfile.cycling:
        return 'routed-bike';
    }
  }

  String get osrmProfile {
    switch (this) {
      case TransportProfile.driving:
        return 'driving';
      case TransportProfile.walking:
        return 'foot';
      case TransportProfile.cycling:
        return 'bike';
    }
  }
}

class RouteResult {
  const RouteResult({
    required this.polyline,
    required this.distanceMeters,
    required this.duration,
    required this.profile,
  });

  final List<LatLng> polyline;
  final double distanceMeters;
  final Duration duration;
  final TransportProfile profile;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'polyline': polyline.map((p) => <double>[p.latitude, p.longitude]).toList(),
    'distanceMeters': distanceMeters,
    'durationSeconds': duration.inSeconds,
    'profile': profile.name,
  };

  static RouteResult? fromJson(Map<String, dynamic> map) {
    final raw = map['polyline'];
    if (raw is! List) return null;
    final pts = <LatLng>[];
    for (final entry in raw) {
      if (entry is List && entry.length >= 2) {
        final lat = (entry[0] as num?)?.toDouble();
        final lng = (entry[1] as num?)?.toDouble();
        if (lat != null && lng != null) {
          pts.add(LatLng(lat, lng));
        }
      }
    }
    if (pts.isEmpty) return null;
    final profileName = map['profile'] as String?;
    final profile = TransportProfile.values.firstWhere(
      (p) => p.name == profileName,
      orElse: () => TransportProfile.driving,
    );
    return RouteResult(
      polyline: pts,
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble() ?? 0,
      duration: Duration(
        seconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      ),
      profile: profile,
    );
  }
}

class RoutingException implements Exception {
  RoutingException(this.message);
  final String message;
  @override
  String toString() => 'RoutingException: $message';
}

class RoutingService {
  RoutingService({
    http.Client? httpClient,
    Future<Directory> Function()? cacheDirProvider,
    Duration cacheTtl = const Duration(days: 7),
  }) : _http = httpClient ?? http.Client(),
       _cacheDirProvider = cacheDirProvider ?? getApplicationDocumentsDirectory,
       _cacheTtl = cacheTtl;

  final http.Client _http;
  final Future<Directory> Function() _cacheDirProvider;
  final Duration _cacheTtl;

  static const String _baseHost = 'routing.openstreetmap.de';

  Future<RouteResult> getRoute({
    required LatLng origin,
    required LatLng destination,
    TransportProfile profile = TransportProfile.driving,
  }) async {
    final cacheKey = _routeCacheKey(origin, destination, profile);
    final cached = await _readCache(cacheKey);
    if (cached != null) {
      return cached;
    }

    final coords =
        '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
    final uri = Uri.https(
      _baseHost,
      '/${profile.osrmServerSlug}/route/v1/${profile.osrmProfile}/$coords',
      <String, String>{
        'overview': 'full',
        'geometries': 'geojson',
        'alternatives': 'false',
        'steps': 'false',
      },
    );

    final result = await _fetchRoute(uri, profile);
    await _writeCache(cacheKey, result);
    return result;
  }

  Future<RouteResult> _fetchRoute(Uri uri, TransportProfile profile) async {
    final response = await _http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw RoutingException(
        'Itinéraire indisponible (HTTP ${response.statusCode}).',
      );
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw RoutingException('Réponse routing invalide.');
    }
    if (body['code'] != 'Ok') {
      throw RoutingException(
        'Itinéraire indisponible (${body['code'] ?? 'erreur inconnue'}).',
      );
    }
    final routes = body['routes'] as List? ?? const <dynamic>[];
    if (routes.isEmpty) {
      throw RoutingException('Aucun itinéraire retourné par le serveur.');
    }
    final first = routes.first;
    if (first is! Map<String, dynamic>) {
      throw RoutingException('Itinéraire mal formé.');
    }
    final polyline = _readGeoJsonPolyline(first['geometry']);
    return RouteResult(
      polyline: polyline,
      distanceMeters: (first['distance'] as num?)?.toDouble() ?? 0,
      duration: Duration(
        seconds: ((first['duration'] as num?)?.toDouble() ?? 0).round(),
      ),
      profile: profile,
    );
  }

  static List<LatLng> _readGeoJsonPolyline(dynamic geometry) {
    if (geometry is! Map<String, dynamic>) {
      throw RoutingException('Géométrie d\'itinéraire absente.');
    }
    final coords = geometry['coordinates'];
    if (coords is! List) {
      throw RoutingException('Coordonnées d\'itinéraire absentes.');
    }
    final points = <LatLng>[];
    for (final entry in coords) {
      if (entry is List && entry.length >= 2) {
        final lng = (entry[0] as num?)?.toDouble();
        final lat = (entry[1] as num?)?.toDouble();
        if (lat != null && lng != null) {
          points.add(LatLng(lat, lng));
        }
      }
    }
    if (points.isEmpty) {
      throw RoutingException('Itinéraire vide.');
    }
    return points;
  }

  Future<RouteResult?> _readCache(String key) async {
    try {
      final file = await _cacheFile(key);
      if (!await file.exists()) return null;
      final stat = await file.stat();
      if (DateTime.now().difference(stat.modified) > _cacheTtl) {
        return null;
      }
      final raw = await file.readAsString();
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return RouteResult.fromJson(json);
    } catch (e, st) {
      developer.log(
        'Route cache read failed for key $key: $e',
        name: 'RoutingService',
        error: e,
        stackTrace: st,
        level: 800,
      );
      return null;
    }
  }

  Future<void> _writeCache(String key, RouteResult result) async {
    try {
      final file = await _cacheFile(key);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(result.toJson()));
    } catch (e, st) {
      developer.log(
        'Route cache write failed for key $key: $e',
        name: 'RoutingService',
        error: e,
        stackTrace: st,
        level: 800,
      );
    }
  }

  Future<File> _cacheFile(String key) async {
    final dir = await _cacheDirProvider();
    return File(
      '${dir.path}${Platform.pathSeparator}rihla_routes${Platform.pathSeparator}$key.json',
    );
  }

  String _routeCacheKey(
    LatLng origin,
    LatLng destination,
    TransportProfile profile,
  ) {
    String round(double v) => v.toStringAsFixed(5);
    return 'r_${profile.name}_${round(origin.latitude)}_${round(origin.longitude)}_${round(destination.latitude)}_${round(destination.longitude)}';
  }

  void dispose() {
    _http.close();
  }
}
