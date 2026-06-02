import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:rihla/core/services/connectivity_service.dart';
import 'package:rihla/core/services/routing_service.dart';
import 'package:rihla/core/theme/rihla_palette.dart';
import 'package:rihla/core/utils/duration_format.dart';
import 'package:rihla/data/models/tourist_site.dart';
import 'package:rihla/features/map/presentation/cached_network_tile_provider.dart';
import 'package:rihla/theme/spacing.dart';
import 'package:rihla/theme/typography.dart';

class NavigationPage extends StatefulWidget {
  const NavigationPage({
    super.key,
    required this.destination,
    RoutingService? routingService,
    ConnectivityService? connectivity,
    this.showTileLayer = true,
    this.isLocationServiceEnabled,
    this.checkPermission,
    this.requestPermission,
    this.getCurrentPosition,
    this.getLastKnownPosition,
    this.positionStreamFactory,
    this.headingStreamFactory,
  }) : _routingService = routingService,
       _connectivity = connectivity;

  final TouristSite destination;
  final RoutingService? _routingService;
  final ConnectivityService? _connectivity;
  final bool showTileLayer;
  final Future<bool> Function()? isLocationServiceEnabled;
  final Future<LocationPermission> Function()? checkPermission;
  final Future<LocationPermission> Function()? requestPermission;
  final Future<Position> Function()? getCurrentPosition;
  final Future<Position?> Function()? getLastKnownPosition;
  final Stream<Position> Function()? positionStreamFactory;
  final Stream<double?> Function()? headingStreamFactory;

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  static const Duration _locationPlatformTimeout = Duration(seconds: 5);
  static const Duration _locationFixTimeout = Duration(seconds: 20);
  static const Duration _lastKnownPositionTimeout = Duration(seconds: 2);
  static const Duration _cachedPositionMaxAge = Duration(minutes: 30);

  final MapController _mapController = MapController();
  final CachedNetworkTileProvider _tileProvider = CachedNetworkTileProvider();
  final latlng.Distance _distance = const latlng.Distance();

  late final RoutingService _routingService =
      widget._routingService ?? RoutingService();
  late final bool _ownsRoutingService = widget._routingService == null;
  late final ConnectivityService _connectivity =
      widget._connectivity ?? ConnectivityService();

  TransportProfile _profile = TransportProfile.driving;
  RouteResult? _route;
  String? _routeError;
  bool _isLoadingRoute = false;
  bool _isLocating = false;

  Position? _userPosition;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<double?>? _headingSubscription;
  Timer? _etaTicker;

  bool _isInTripMode = false;
  bool _isFollowingUser = true;

  double? _heading;

  int _closestRouteIndex = 0;

  double _offRouteMeters = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _headingSubscription?.cancel();
    _etaTicker?.cancel();
    _tileProvider.dispose();
    if (_ownsRoutingService) {
      _routingService.dispose();
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (!await _isOnlineNow()) {
      if (!mounted) return;
      setState(() {
        _routeError =
            'Itinéraire indisponible hors ligne. Reconnectez-vous '
            'pour calculer un trajet.';
      });
      return;
    }
    await _resolveStartingPosition();
    if (!mounted || _userPosition == null) return;
    await _computeRoute();
  }

  Future<bool> _isOnlineNow() async {
    try {
      return await _connectivity.isOnlineNow().timeout(
        const Duration(seconds: 3),
      );
    } on Object {
      return true;
    }
  }

  Future<bool> _ensureLocationPermission() async {
    LocationPermission permission =
        await (widget.checkPermission?.call() ?? Geolocator.checkPermission())
            .timeout(
              _locationPlatformTimeout,
              onTimeout: () => LocationPermission.denied,
            );
    if (permission == LocationPermission.denied) {
      permission =
          await (widget.requestPermission?.call() ??
                  Geolocator.requestPermission())
              .timeout(
                _locationPlatformTimeout,
                onTimeout: () => LocationPermission.denied,
              );
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<bool> _isLocationServiceEnabled() {
    return (widget.isLocationServiceEnabled?.call() ??
            Geolocator.isLocationServiceEnabled())
        .timeout(_locationPlatformTimeout, onTimeout: () => false);
  }

  Future<Position> _getCurrentPosition() {
    final injectedGetter = widget.getCurrentPosition;
    if (injectedGetter != null) {
      return injectedGetter().timeout(_locationFixTimeout);
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: _locationFixTimeout,
      ),
    ).timeout(_locationFixTimeout + const Duration(seconds: 2));
  }

  Future<Position?> _getLastKnownPosition() {
    return (widget.getLastKnownPosition?.call() ??
            Geolocator.getLastKnownPosition())
        .timeout(_lastKnownPositionTimeout, onTimeout: () => null);
  }

  bool _isRecentEnough(Position position) {
    final age = DateTime.now().difference(position.timestamp);
    return !age.isNegative && age <= _cachedPositionMaxAge;
  }

  bool _isAccurateEnough(Position position) {
    return position.accuracy <= 5000;
  }

  Future<Position?> _resolvePositionFix() async {
    Position? cachedPosition;
    try {
      cachedPosition = await _getLastKnownPosition();
    } catch (_) {
      cachedPosition = null;
    }
    try {
      return await _getCurrentPosition();
    } on TimeoutException {
      if (cachedPosition != null &&
          _isRecentEnough(cachedPosition) &&
          _isAccurateEnough(cachedPosition)) {
        return cachedPosition;
      }
      rethrow;
    }
  }

  Future<void> _resolveStartingPosition() async {
    setState(() {
      _isLocating = true;
      _routeError = null;
    });
    try {
      final serviceEnabled = await _isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _routeError =
              'Position indisponible. Activez la localisation du téléphone puis réessayez.';
        });
        return;
      }
      final granted = await _ensureLocationPermission();
      if (!granted) {
        if (!mounted) return;
        setState(() {
          _routeError =
              'Position indisponible. Autorisez la localisation pour Rihla puis réessayez.';
        });
        return;
      }
      final position = await _resolvePositionFix();
      if (position == null) {
        if (!mounted) return;
        setState(() {
          _routeError =
              'Position indisponible. Patientez quelques secondes dehors ou près d’une fenêtre, puis réessayez.';
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _userPosition = position;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _routeError =
            'Position indisponible. Le téléphone n’a pas fourni de position GPS assez vite ; réessayez dans quelques secondes.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _routeError =
            'Position indisponible. Activez la localisation puis réessayez.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  Future<void> _computeRoute() async {
    final origin = _userPosition;
    if (origin == null) return;

    if (!await _isOnlineNow()) {
      if (!mounted) return;
      setState(() {
        _route = null;
        _isLoadingRoute = false;
        _routeError =
            'Itinéraire indisponible hors ligne. Reconnectez-vous '
            'pour calculer un trajet.';
      });
      return;
    }

    setState(() {
      _isLoadingRoute = true;
      _routeError = null;
    });

    try {
      final route = await _routingService.getRoute(
        origin: latlng.LatLng(origin.latitude, origin.longitude),
        destination: latlng.LatLng(
          widget.destination.latitude,
          widget.destination.longitude,
        ),
        profile: _profile,
      );
      if (!mounted) return;
      setState(() {
        _route = route;
        _isLoadingRoute = false;
        _closestRouteIndex = 0;
        _offRouteMeters = 0;
      });
      _recomputeProgress();
      if (!_isInTripMode) {
        _frameRouteOnMap(route);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _route = null;
        _isLoadingRoute = false;
        _routeError = e is RoutingException
            ? e.message
            : 'Impossible de calculer l\'itinéraire.';
      });
    }
  }

  void _frameRouteOnMap(RouteResult route) {
    if (route.polyline.isEmpty) return;
    double minLat = route.polyline.first.latitude;
    double maxLat = minLat;
    double minLng = route.polyline.first.longitude;
    double maxLng = minLng;
    for (final point in route.polyline) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    final bounds = LatLngBounds(
      latlng.LatLng(minLat, minLng),
      latlng.LatLng(maxLat, maxLng),
    );
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(48, 80, 48, 220),
      ),
    );
  }

  Stream<Position> _buildPositionStream() {
    return widget.positionStreamFactory?.call() ??
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 1,
          ),
        );
  }

  Stream<double?> _buildHeadingStream() {
    if (widget.headingStreamFactory != null) {
      return widget.headingStreamFactory!.call();
    }
    return FlutterCompass.events?.map((event) => event.heading) ??
        const Stream<double?>.empty();
  }

  Future<void> _startTrip() async {
    if (_route == null) return;
    final granted = await _ensureLocationPermission();
    if (!granted) return;

    _positionSubscription?.cancel();
    _positionSubscription = _buildPositionStream().listen(_onPositionUpdate);

    _headingSubscription?.cancel();
    _headingSubscription = _buildHeadingStream().listen(_onHeadingUpdate);

    _etaTicker?.cancel();
    _etaTicker = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() {});
    });

    setState(() {
      _isInTripMode = true;
      _isFollowingUser = true;
    });

    final pos = _userPosition;
    if (pos != null) {
      _mapController.move(latlng.LatLng(pos.latitude, pos.longitude), 17.5);
    }
    final heading = _heading;
    if (heading != null) {
      _mapController.rotate(-heading);
    }
  }

  Future<void> _stopTrip() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    await _headingSubscription?.cancel();
    _headingSubscription = null;
    _etaTicker?.cancel();
    _etaTicker = null;
    _mapController.rotate(0);

    if (!mounted) return;
    setState(() {
      _isInTripMode = false;
      _isFollowingUser = true;
      _heading = null;
    });

    final r = _route;
    if (r != null) {
      _frameRouteOnMap(r);
    }
  }

  void _onPositionUpdate(Position position) {
    if (!mounted) return;
    setState(() {
      _userPosition = position;
    });
    _recomputeProgress();
    if (_isInTripMode && _isFollowingUser) {
      _mapController.move(
        latlng.LatLng(position.latitude, position.longitude),
        _mapController.camera.zoom,
      );
    }
  }

  void _recenterOnUser() {
    final pos = _userPosition;
    if (pos == null) return;
    setState(() {
      _isFollowingUser = true;
    });
    _mapController.move(
      latlng.LatLng(pos.latitude, pos.longitude),
      math.max(_mapController.camera.zoom, 16),
    );
    final heading = _heading;
    if (heading != null) {
      _mapController.rotate(-heading);
    }
  }

  void _orientNorth() {
    if (_isInTripMode && _isFollowingUser) {
      setState(() {
        _isFollowingUser = false;
      });
    }
    _mapController.rotate(0);
  }

  void _onHeadingUpdate(double? heading) {
    if (heading == null || !mounted) return;
    setState(() {
      _heading = heading;
    });
    if (_isInTripMode && _isFollowingUser) {
      _mapController.rotate(-heading);
    }
  }

  void _recomputeProgress() {
    final pos = _userPosition;
    final route = _route;
    if (pos == null || route == null || route.polyline.isEmpty) return;

    final user = latlng.LatLng(pos.latitude, pos.longitude);
    int closestIndex = 0;
    double closestDist = double.infinity;
    for (var i = 0; i < route.polyline.length; i++) {
      final d = _distance(user, route.polyline[i]);
      if (d < closestDist) {
        closestDist = d;
        closestIndex = i;
      }
    }
    if (closestIndex != _closestRouteIndex || closestDist != _offRouteMeters) {
      _closestRouteIndex = closestIndex;
      _offRouteMeters = closestDist;
    }
  }

  void _selectProfile(TransportProfile profile) {
    if (profile == _profile) return;
    setState(() {
      _profile = profile;
    });
    _computeRoute();
  }

  Future<void> _retryRoute() async {
    if (_userPosition == null) {
      await _bootstrap();
      return;
    }
    if (!mounted) return;
    await _computeRoute();
  }

  double get _remainingMeters {
    final route = _route;
    if (route == null || route.polyline.isEmpty) return 0;
    double remaining = _offRouteMeters;
    for (var i = _closestRouteIndex; i < route.polyline.length - 1; i++) {
      remaining += _distance(route.polyline[i], route.polyline[i + 1]);
    }
    return remaining;
  }

  Duration get _remainingDuration {
    final route = _route;
    if (route == null || route.distanceMeters <= 0) return Duration.zero;
    final remainingFraction = (_remainingMeters / route.distanceMeters).clamp(
      0.0,
      1.0,
    );
    return Duration(
      seconds: (route.duration.inSeconds * remainingFraction).round(),
    );
  }

  List<latlng.LatLng> get _passedPolyline {
    final route = _route;
    if (route == null || route.polyline.isEmpty) return const <latlng.LatLng>[];
    if (_closestRouteIndex <= 0) return const <latlng.LatLng>[];
    return route.polyline.sublist(0, _closestRouteIndex + 1);
  }

  List<latlng.LatLng> get _remainingPolyline {
    final route = _route;
    if (route == null || route.polyline.isEmpty) return const <latlng.LatLng>[];
    if (_closestRouteIndex >= route.polyline.length - 1) {
      return <latlng.LatLng>[route.polyline.last];
    }
    return route.polyline.sublist(_closestRouteIndex);
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(meters >= 10000 ? 0 : 1)} km';
    }
    return '${meters.round()} m';
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  String _formatEta(Duration remaining) {
    final now = DateTime.now();
    final eta = now.add(remaining);
    final time = '${_twoDigits(eta.hour)}:${_twoDigits(eta.minute)}';
    final today = DateTime(now.year, now.month, now.day);
    final etaDay = DateTime(eta.year, eta.month, eta.day);
    final dayDelta = etaDay.difference(today).inDays;
    if (dayDelta <= 0) return time;

    final date = '${_twoDigits(eta.day)}/${_twoDigits(eta.month)}';
    if (dayDelta == 1) return 'Demain\n$time';
    return 'J+$dayDelta\n$date $time';
  }

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);
    final destination = latlng.LatLng(
      widget.destination.latitude,
      widget.destination.longitude,
    );
    final user = _userPosition == null
        ? null
        : latlng.LatLng(_userPosition!.latitude, _userPosition!.longitude);

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      appBar: _isInTripMode
          ? null
          : AppBar(
              title: const Text('Itinéraire'),
              backgroundColor: Colors.transparent,
              foregroundColor: palette.brandPrimary,
              elevation: 0,
            ),
      body: Stack(
        children: <Widget>[
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: user ?? destination,
              initialZoom: 13,
              onPositionChanged: (_, hasGesture) {
                if (hasGesture && _isInTripMode && _isFollowingUser) {
                  setState(() {
                    _isFollowingUser = false;
                  });
                }
              },
              interactionOptions: InteractionOptions(
                flags: _isInTripMode
                    ? InteractiveFlag.drag |
                          InteractiveFlag.rotate |
                          InteractiveFlag.pinchZoom |
                          InteractiveFlag.doubleTapZoom |
                          InteractiveFlag.flingAnimation
                    : InteractiveFlag.all,
              ),
            ),
            children: <Widget>[
              if (widget.showTileLayer)
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.rihla.app',
                  tileProvider: _tileProvider,
                ),
              if (_passedPolyline.length >= 2)
                PolylineLayer(
                  polylines: <Polyline>[
                    Polyline(
                      points: _passedPolyline,
                      strokeWidth: 4,
                      color: palette.textSecondary.withValues(alpha: 0.45),
                      borderColor: Colors.white.withValues(alpha: 0.0),
                      borderStrokeWidth: 0,
                    ),
                  ],
                ),
              if (_remainingPolyline.length >= 2)
                PolylineLayer(
                  polylines: <Polyline>[
                    Polyline(
                      points: _remainingPolyline,
                      strokeWidth: 5.5,
                      color: palette.brandPrimary,
                      borderColor: Colors.white,
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: <Marker>[
                  Marker(
                    point: destination,
                    width: 48,
                    height: 48,
                    child: const _DestinationPin(),
                  ),
                  if (user != null)
                    Marker(
                      point: user,
                      width: 56,
                      height: 56,

                      rotate: true,
                      child: _UserPuck(
                        profile: _profile,
                        isInTripMode: _isInTripMode,
                        heading: _heading,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (_isLoadingRoute || _isLocating)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x20000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          if (_routeError != null && !_isInTripMode)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: _NavigationErrorBanner(message: _routeError!),
                ),
              ),
            ),
          if (_isInTripMode)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: _TripTopBar(
                  destinationName: widget.destination.name,
                  remainingDuration: _remainingDuration,
                  onExit: _stopTrip,
                ),
              ),
            ),
          if (_isInTripMode)
            Positioned(
              top: 84,
              right: 16,
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    FloatingActionButton.small(
                      heroTag: 'trip-recenter',
                      onPressed: _userPosition == null ? null : _recenterOnUser,
                      tooltip: 'Recentrer sur ma position',
                      backgroundColor: _isFollowingUser
                          ? palette.brandPrimary
                          : palette.cardSurface,
                      foregroundColor: _isFollowingUser
                          ? Colors.white
                          : palette.brandPrimary,
                      child: const Icon(Icons.my_location_rounded),
                    ),
                    const SizedBox(width: 10),
                    FloatingActionButton.small(
                      heroTag: 'trip-north',
                      onPressed: _orientNorth,
                      tooltip: 'Orienter la carte au nord',
                      backgroundColor: palette.cardSurface,
                      foregroundColor: palette.brandPrimary,
                      child: const Icon(Icons.explore_outlined),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: _isInTripMode
                  ? _TripBottomBar(
                      remainingDistance: _remainingMeters,
                      remainingDuration: _remainingDuration,
                      profile: _profile,
                      formatDistance: _formatDistance,
                      formatEta: _formatEta,
                    )
                  : _OverviewPanel(
                      destinationName: widget.destination.name,
                      destinationCity: widget.destination.city,
                      profile: _profile,
                      onSelectProfile: _selectProfile,
                      route: _route,
                      remainingDistanceMeters: _remainingMeters,
                      remainingDuration: _remainingDuration,
                      onStartTrip: _startTrip,
                      error: _routeError,
                      onRetry: _retryRoute,
                      formatDistance: _formatDistance,
                      formatEta: _formatEta,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationErrorBanner extends StatelessWidget {
  const _NavigationErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xEEFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF9A9A)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.cloud_off_rounded,
            color: Color(0xFFC62828),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Itinéraire indisponible : $message',
              style: AppTypography.caption.copyWith(
                color: const Color(0xFFC62828),
                fontSize: 12.6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationPin extends StatelessWidget {
  const _DestinationPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFD7263D),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(Icons.flag_rounded, color: Colors.white, size: 22),
    );
  }
}

class _UserPuck extends StatelessWidget {
  const _UserPuck({
    required this.profile,
    required this.isInTripMode,
    required this.heading,
  });

  final TransportProfile profile;
  final bool isInTripMode;
  final double? heading;

  IconData get _icon {
    switch (profile) {
      case TransportProfile.driving:
        return Icons.directions_car_rounded;
      case TransportProfile.walking:
        return Icons.directions_walk_rounded;
      case TransportProfile.cycling:
        return Icons.directions_bike_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color brand = Color(0xFF1E7BF1);
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (heading != null)
            Transform.rotate(
              angle: heading! * math.pi / 180,
              alignment: Alignment.center,
              child: const _HeadingCone(color: brand),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: brand,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: isInTripMode ? 3 : 2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: brand.withValues(alpha: isInTripMode ? 0.45 : 0.0),
                  blurRadius: isInTripMode ? 14 : 0,
                  spreadRadius: isInTripMode ? 3 : 0,
                ),
              ],
            ),
            child: Icon(_icon, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }
}

class _HeadingCone extends StatelessWidget {
  const _HeadingCone({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(56, 56),
      painter: _HeadingConePainter(color: color),
    );
  }
}

class _HeadingConePainter extends CustomPainter {
  _HeadingConePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: size.width / 2);
    final shader = RadialGradient(
      colors: <Color>[
        color.withValues(alpha: 0.55),
        color.withValues(alpha: 0),
      ],
      stops: const <double>[0.0, 1.0],
    ).createShader(rect);
    final paint = Paint()..shader = shader;

    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(center.dx - size.width * 0.36, 0)
      ..lineTo(center.dx + size.width * 0.36, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HeadingConePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _TripTopBar extends StatelessWidget {
  const _TripTopBar({
    required this.destinationName,
    required this.remainingDuration,
    required this.onExit,
  });

  final String destinationName;
  final Duration remainingDuration;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: palette.cardSurface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.navigation_rounded,
              color: palette.brandPrimary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    destinationName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyStrong.copyWith(
                      fontSize: 15,
                      color: palette.textPrimary,
                    ),
                  ),
                  Text(
                    formatTripDuration(remainingDuration),
                    style: AppTypography.caption.copyWith(
                      fontSize: 12.6,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Quitter la navigation',
              onPressed: onExit,
              icon: const Icon(Icons.close_rounded),
              color: palette.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _TripBottomBar extends StatelessWidget {
  const _TripBottomBar({
    required this.remainingDistance,
    required this.remainingDuration,
    required this.profile,
    required this.formatDistance,
    required this.formatEta,
  });

  final double remainingDistance;
  final Duration remainingDuration;
  final TransportProfile profile;
  final String Function(double) formatDistance;
  final String Function(Duration) formatEta;

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: palette.cardSurface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _LiveStat(
                value: formatTripDuration(remainingDuration),
                label: 'Restant',
                color: palette.brandPrimary,
                emphasized: true,
              ),
            ),
            Container(width: 1, height: 36, color: palette.divider),
            Expanded(
              child: _LiveStat(
                value: formatDistance(remainingDistance),
                label: 'Distance',
                color: palette.textPrimary,
              ),
            ),
            Container(width: 1, height: 36, color: palette.divider),
            Expanded(
              child: _LiveStat(
                value: formatEta(remainingDuration),
                label: 'Arrivée',
                color: palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveStat extends StatelessWidget {
  const _LiveStat({
    required this.value,
    required this.label,
    required this.color,
    this.emphasized = false,
  });

  final String value;
  final String label;
  final Color color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.title3.copyWith(
            fontSize: value.contains('\n') ? 14.2 : (emphasized ? 20 : 16),
            height: value.contains('\n') ? 1.05 : null,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontSize: 11.4,
            color: palette.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _OverviewPanel extends StatelessWidget {
  const _OverviewPanel({
    required this.destinationName,
    required this.destinationCity,
    required this.profile,
    required this.onSelectProfile,
    required this.route,
    required this.remainingDistanceMeters,
    required this.remainingDuration,
    required this.onStartTrip,
    required this.error,
    required this.onRetry,
    required this.formatDistance,
    required this.formatEta,
  });

  final String destinationName;
  final String destinationCity;
  final TransportProfile profile;
  final ValueChanged<TransportProfile> onSelectProfile;
  final RouteResult? route;
  final double remainingDistanceMeters;
  final Duration remainingDuration;
  final VoidCallback onStartTrip;
  final String? error;
  final VoidCallback onRetry;
  final String Function(double) formatDistance;
  final String Function(Duration) formatEta;

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.flag_rounded,
                color: Color(0xFFD7263D),
                size: 20,
              ),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      destinationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyStrong.copyWith(
                        fontSize: 15,
                        color: palette.textPrimary,
                      ),
                    ),
                    Text(
                      destinationCity,
                      style: AppTypography.caption.copyWith(
                        fontSize: 12.4,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          _ProfileChips(profile: profile, onSelect: onSelectProfile),
          const SizedBox(height: AppSpacing.x3),
          if (error != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEF9A9A)),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xFFC62828),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      error!,
                      style: AppTypography.caption.copyWith(
                        fontSize: 12.4,
                        color: const Color(0xFFC62828),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFC62828),
                      minimumSize: const Size(10, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            )
          else if (route != null)
            _RouteSummary(
              route: route!,
              remainingDistanceMeters: remainingDistanceMeters,
              remainingDuration: remainingDuration,
              profile: profile,
              formatDistance: formatDistance,
              formatEta: formatEta,
            )
          else
            Text(
              'Recherche d\'itinéraire en cours…',
              style: AppTypography.caption.copyWith(
                fontSize: 12.6,
                color: palette.textSecondary,
              ),
            ),
          const SizedBox(height: AppSpacing.x3),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: route == null ? null : onStartTrip,
              icon: const Icon(Icons.navigation_rounded),
              label: const Text('Démarrer la navigation'),
              style: FilledButton.styleFrom(
                backgroundColor: palette.brandPrimary,
                foregroundColor: palette.brandPrimaryContrast,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileChips extends StatelessWidget {
  const _ProfileChips({required this.profile, required this.onSelect});
  final TransportProfile profile;
  final ValueChanged<TransportProfile> onSelect;

  @override
  Widget build(BuildContext context) {
    final entries = <(TransportProfile, IconData)>[
      (TransportProfile.driving, Icons.directions_car_rounded),
      (TransportProfile.walking, Icons.directions_walk_rounded),
      (TransportProfile.cycling, Icons.directions_bike_rounded),
    ];
    return Row(
      children: <Widget>[
        for (final entry in entries) ...<Widget>[
          Expanded(
            child: _ProfileChip(
              icon: entry.$2,
              label: entry.$1.label,
              selected: profile == entry.$1,
              onTap: () => onSelect(entry.$1),
            ),
          ),
          if (entry != entries.last) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? palette.brandPrimary : palette.softSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 20,
                color: selected
                    ? palette.brandPrimaryContrast
                    : palette.brandPrimaryOnSoft,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  fontSize: 11.6,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? palette.brandPrimaryContrast
                      : palette.brandPrimaryOnSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({
    required this.route,
    required this.remainingDistanceMeters,
    required this.remainingDuration,
    required this.profile,
    required this.formatDistance,
    required this.formatEta,
  });

  final RouteResult route;
  final double remainingDistanceMeters;
  final Duration remainingDuration;
  final TransportProfile profile;
  final String Function(double) formatDistance;
  final String Function(Duration) formatEta;

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);
    final distance = remainingDistanceMeters > 0
        ? remainingDistanceMeters
        : route.distanceMeters;
    final duration = remainingDuration > Duration.zero
        ? remainingDuration
        : route.duration;

    return Row(
      children: <Widget>[
        Expanded(
          child: _SummaryTile(
            label: 'Distance',
            value: formatDistance(distance),
          ),
        ),
        Container(width: 1, height: 30, color: palette.divider),
        Expanded(
          child: _SummaryTile(
            label: profile == TransportProfile.driving
                ? 'Durée (sans trafic)'
                : 'Durée',
            value: formatTripDuration(duration),
          ),
        ),
        Container(width: 1, height: 30, color: palette.divider),
        Expanded(
          child: _SummaryTile(
            label: 'Arrivée estimée',
            value: formatEta(duration),
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);
    return Column(
      children: <Widget>[
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodyStrong.copyWith(
            fontSize: value.contains('\n') ? 12.6 : 14.5,
            height: value.contains('\n') ? 1.08 : null,
            color: palette.brandPrimary,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontSize: 11.5,
            color: palette.textSecondary,
          ),
        ),
      ],
    );
  }
}
