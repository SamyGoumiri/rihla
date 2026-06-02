import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:rihla/core/constants/categories.dart';
import 'package:rihla/core/constants/category_filter.dart';
import 'package:rihla/core/theme/rihla_palette.dart';
import 'package:rihla/core/widgets/app_site_image.dart';
import 'package:rihla/core/widgets/site_rating_label.dart';
import 'package:rihla/data/models/tourist_site.dart';
import 'package:rihla/data/repositories/site_repository.dart';
import 'package:rihla/features/map/presentation/cached_network_tile_provider.dart';
import 'package:rihla/features/navigation/presentation/navigation_page.dart';
import 'package:rihla/features/sites/presentation/site_detail_page.dart';
import 'package:rihla/theme/spacing.dart';
import 'package:rihla/theme/typography.dart';
import 'package:url_launcher/url_launcher.dart';

const Color _kMarkerSelected = Color(0xFF14553F);

const Color _kLocationBlue = Color(0xFF1E7BF1);

class MapPage extends StatefulWidget {
  const MapPage({
    super.key,
    this.loadSites,
    this.isLocationServiceEnabled,
    this.checkPermission,
    this.requestPermission,
    this.getCurrentPosition,
    this.getLastKnownPosition,
    this.now,
    this.showTileLayer = true,
  });

  final Future<List<TouristSite>> Function({bool forceRefresh})? loadSites;
  final Future<bool> Function()? isLocationServiceEnabled;
  final Future<LocationPermission> Function()? checkPermission;
  final Future<LocationPermission> Function()? requestPermission;
  final Future<Position> Function()? getCurrentPosition;
  final Future<Position?> Function()? getLastKnownPosition;
  final DateTime Function()? now;
  final bool showTileLayer;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const Duration _locationPlatformTimeout = Duration(seconds: 5);
  static const Duration _locationFixTimeout = Duration(seconds: 20);
  static const Duration _lastKnownPositionTimeout = Duration(seconds: 2);
  static const Duration _cachedPositionMaxAge = Duration(minutes: 30);
  static const latlng.LatLng _initialCenter = latlng.LatLng(28.0339, 1.6596);
  static const double _initialZoom = 5.0;
  static const double _focusZoom = 12.4;
  static const double _algeriaMinLatitude = 18.0;
  static const double _algeriaMaxLatitude = 38.5;
  static const double _algeriaMinLongitude = -8.8;
  static const double _algeriaMaxLongitude = 12.5;

  final MapController _mapController = MapController();
  final CachedNetworkTileProvider _tileProvider = CachedNetworkTileProvider();
  final TextEditingController _searchController = TextEditingController();
  final latlng.Distance _distance = const latlng.Distance();
  Timer? _searchDebounce;
  String _searchQuery = '';

  List<TouristSite> _sites = <TouristSite>[];
  bool _isLoading = true;
  bool _isLocating = false;
  bool _isOutsideCoverage = false;
  Position? _userPosition;
  double? _userHeading;
  StreamSubscription<CompassEvent>? _compassSubscription;
  TouristSite? _selectedSite;
  String? _selectedFilter;

  SiteRepository get _repository => SiteRepository.instance;

  static const Map<String, IconData> _mapIcons = <String, IconData>{
    'nature': Icons.park_outlined,
    'histoire': Icons.castle_outlined,
    'culture': Icons.museum_outlined,
    'loisirs': Icons.attractions_outlined,
  };

  static final List<_MapFilter> _filters = <_MapFilter>[
    const _MapFilter(key: null, label: 'Tous', icon: Icons.grid_view_rounded),
    for (final f in CategoryFilters.map)
      _MapFilter(
        key: f.key,
        label: f.label,
        icon: _mapIcons[f.key] ?? Icons.place_outlined,
      ),
  ];

  @override
  void initState() {
    super.initState();
    _loadSites();
    _bindCompass();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _tileProvider.dispose();
    _compassSubscription?.cancel();
    super.dispose();
  }

  void _bindCompass() {
    final stream = FlutterCompass.events;
    if (stream == null) return;
    _compassSubscription = stream.listen((event) {
      final heading = event.heading;
      if (heading == null || !mounted) return;

      if (_userHeading != null && (_userHeading! - heading).abs() < 2.0) {
        return;
      }
      setState(() {
        _userHeading = heading;
      });
    });
  }

  Future<void> _loadSites({bool forceRefresh = false}) async {
    final Future<List<TouristSite>> Function({bool forceRefresh}) loader =
        widget.loadSites ??
        ({bool forceRefresh = false}) =>
            _repository.getSites(forceRefresh: forceRefresh);

    final List<TouristSite> sites = await loader(forceRefresh: forceRefresh);

    if (!mounted) {
      return;
    }

    setState(() {
      _sites = sites;
      _isLoading = false;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
    });
    await _loadSites(forceRefresh: true);
  }

  List<TouristSite> _filteredSites() {
    final String query = _searchQuery;
    final String? filterKey = _selectedFilter;

    return _sites.where((TouristSite site) {
      final bool matchesText =
          query.isEmpty ||
          site.name.toLowerCase().contains(query) ||
          site.city.toLowerCase().contains(query) ||
          site.address.toLowerCase().contains(query);

      return matchesText && CategoryFilters.matchesKey(site, filterKey);
    }).toList();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) {
        return;
      }

      final String nextQuery = value.trim().toLowerCase();
      if (nextQuery == _searchQuery) {
        return;
      }

      setState(() {
        _searchQuery = nextQuery;
      });
    });
  }

  bool _isWithinAlgeriaCoverage(Position position) {
    return position.latitude >= _algeriaMinLatitude &&
        position.latitude <= _algeriaMaxLatitude &&
        position.longitude >= _algeriaMinLongitude &&
        position.longitude <= _algeriaMaxLongitude;
  }

  Future<bool> _isLocationServiceEnabled() {
    return (widget.isLocationServiceEnabled?.call() ??
            Geolocator.isLocationServiceEnabled())
        .timeout(_locationPlatformTimeout, onTimeout: () => false);
  }

  Future<LocationPermission> _checkLocationPermission() {
    return (widget.checkPermission?.call() ?? Geolocator.checkPermission())
        .timeout(
          _locationPlatformTimeout,
          onTimeout: () => LocationPermission.denied,
        );
  }

  Future<LocationPermission> _requestLocationPermission() {
    return (widget.requestPermission?.call() ?? Geolocator.requestPermission())
        .timeout(
          _locationPlatformTimeout,
          onTimeout: () => LocationPermission.denied,
        );
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
    final age = (widget.now?.call() ?? DateTime.now()).difference(
      position.timestamp,
    );
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

  void _returnToAlgeria() {
    setState(() {
      _isOutsideCoverage = false;
      _selectedSite = null;
    });
    _mapController.move(_initialCenter, _initialZoom);
  }

  void _focusNearestAlgerianSite() {
    if (_userPosition == null || _sites.isEmpty) {
      _returnToAlgeria();
      return;
    }

    TouristSite? nearestSite;
    double nearestDistance = double.infinity;

    final latlng.LatLng userLatLng = latlng.LatLng(
      _userPosition!.latitude,
      _userPosition!.longitude,
    );

    for (final TouristSite site in _sites) {
      final double siteDistance = _distance(
        userLatLng,
        latlng.LatLng(site.latitude, site.longitude),
      );
      if (siteDistance < nearestDistance) {
        nearestDistance = siteDistance;
        nearestSite = site;
      }
    }

    if (nearestSite == null) {
      _returnToAlgeria();
      return;
    }

    setState(() {
      _selectedSite = nearestSite;
      _isOutsideCoverage = false;
    });

    _mapController.move(
      latlng.LatLng(nearestSite.latitude, nearestSite.longitude),
      _focusZoom,
    );
  }

  Future<void> _goToUserLocation() async {
    setState(() {
      _isLocating = true;
    });

    try {
      final bool serviceEnabled = await _isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showLocationMessage(
            'Activez la localisation pour centrer la carte.',
          );
        }
        return;
      }

      LocationPermission permission = await _checkLocationPermission();
      if (permission == LocationPermission.denied) {
        permission = await _requestLocationPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showLocationMessage(
            'Autorisez la localisation dans les réglages pour utiliser cette option.',
          );
        }
        return;
      }

      final Position? position = await _resolvePositionFix();
      if (!mounted) {
        return;
      }
      if (position == null) {
        _showLocationMessage(
          'Position indisponible. Patientez quelques secondes dehors ou près d\'une fenêtre, puis réessayez.',
        );
        return;
      }

      final bool isWithinCoverage = _isWithinAlgeriaCoverage(position);
      setState(() {
        _userPosition = position;
        _isOutsideCoverage = !isWithinCoverage;
      });

      if (isWithinCoverage) {
        _mapController.move(
          latlng.LatLng(position.latitude, position.longitude),
          _focusZoom,
        );
      } else {
        _showLocationMessage(
          'Votre position est hors de la zone couverte. La carte reste centrée sur l’Algérie.',
        );
      }
    } on TimeoutException {
      if (mounted) {
        _showLocationMessage(
          'Position indisponible. Le téléphone n\'a pas fourni de position GPS assez vite ; réessayez dans quelques secondes.',
        );
      }
    } catch (_) {
      if (mounted) {
        _showLocationMessage(
          'Position indisponible. Activez la localisation puis réessayez.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  void _showLocationMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  List<Marker> _buildMarkers(List<TouristSite> sites) {
    final palette = RihlaPalette.of(context);
    final List<Marker> markers = sites.map((TouristSite site) {
      final bool isSelected = _selectedSite?.id == site.id;
      return Marker(
        point: latlng.LatLng(site.latitude, site.longitude),
        width: isSelected ? 54 : 44,
        height: isSelected ? 54 : 44,
        child: Semantics(
          button: true,
          selected: isSelected,
          label: 'Ouvrir ${site.name} sur la carte',
          child: Tooltip(
            message: site.name,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                setState(() {
                  _selectedSite = site;
                });
                _mapController.move(
                  latlng.LatLng(site.latitude, site.longitude),
                  _focusZoom,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: isSelected ? _kMarkerSelected : palette.brandPrimary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: isSelected ? 2.5 : 2,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isSelected ? 0.28 : 0.2,
                      ),
                      blurRadius: isSelected ? 12 : 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  site.category.icon,
                  size: isSelected ? 23 : 19,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();

    if (_userPosition != null) {
      markers.add(
        Marker(
          point: latlng.LatLng(
            _userPosition!.latitude,
            _userPosition!.longitude,
          ),
          width: 46,
          height: 46,
          child: Semantics(
            label: 'Votre position',
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                if (_userHeading != null)
                  Transform.rotate(
                    angle: _userHeading! * math.pi / 180,
                    child: const _MapHeadingArrow(),
                  ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _kLocationBlue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: _kLocationBlue.withValues(alpha: 0.35),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return markers;
  }

  void _openDirections(TouristSite site) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NavigationPage(destination: site),
      ),
    );
  }

  void _openSiteDetail(TouristSite site) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => SiteDetailPage(site: site)));
  }

  Widget _buildFilterBar() {
    return _MapFilterChips(
      filters: _filters,
      selectedKey: _selectedFilter,
      onSelect: (String? nextKey) {
        setState(() {
          _selectedFilter = _selectedFilter == nextKey ? null : nextKey;
        });
      },
    );
  }

  Widget _buildFallbackBanner() {
    final palette = RihlaPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.x2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: palette.warningBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.warningBorder),
      ),
      child: Text(
        SiteRepository.dataSourceStatus.value == SiteDataSourceStatus.empty
            ? 'Catalogue vide'
            : 'Connexion indisponible : catalogue non chargé',
        style: AppTypography.caption.copyWith(
          color: palette.warningForeground,
          fontSize: 12.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);
    final List<TouristSite> filteredSites = _filteredSites();
    final bool hasCatalogIssue =
        SiteRepository.dataSourceStatus.value != SiteDataSourceStatus.cloud;

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      body: Stack(
        children: <Widget>[
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _initialCenter,
              initialZoom: _initialZoom,
            ),
            children: <Widget>[
              if (widget.showTileLayer)
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.rihla.app',
                  tileProvider: _tileProvider,
                ),
              MarkerLayer(markers: _buildMarkers(filteredSites)),
            ],
          ),
          if (_isLoading)
            const ColoredBox(
              color: Color(0x33000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: <Widget>[
                  _FloatingSearchBar(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onLocate: _goToUserLocation,
                    isLocating: _isLocating,
                    onRefresh: _refresh,
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  _buildFilterBar(),
                  if (hasCatalogIssue) _buildFallbackBanner(),
                  const Spacer(),
                  if (widget.showTileLayer) ...<Widget>[
                    const _OsmAttribution(),
                    const SizedBox(height: AppSpacing.x2),
                  ],
                  _MapSelectionPanel(
                    selectedSite: _selectedSite,
                    visibleCount: filteredSites.length,
                    showOutsideCoverageActions: _isOutsideCoverage,
                    onOpenDetails: _selectedSite == null
                        ? null
                        : () => _openSiteDetail(_selectedSite!),
                    onDirections: _selectedSite == null
                        ? null
                        : () => _openDirections(_selectedSite!),
                    onClearSelection: _selectedSite == null
                        ? null
                        : () {
                            setState(() {
                              _selectedSite = null;
                            });
                          },
                    onReturnToAlgeria: _returnToAlgeria,
                    onShowNearestSites: _focusNearestAlgerianSite,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapHeadingArrow extends StatelessWidget {
  const _MapHeadingArrow();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(46, 46), painter: _MapHeadingPainter());
  }
}

class _MapHeadingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const Color brand = _kLocationBlue;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: size.width / 2);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          brand.withValues(alpha: 0.5),
          brand.withValues(alpha: 0),
        ],
        stops: const <double>[0.0, 1.0],
      ).createShader(rect);
    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(center.dx - size.width * 0.34, 0)
      ..lineTo(center.dx + size.width * 0.34, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FloatingSearchBar extends StatelessWidget {
  const _FloatingSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onLocate,
    required this.isLocating,
    required this.onRefresh,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onLocate;
  final bool isLocating;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: palette.cardSurface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(14),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.09),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: AppTypography.body.copyWith(
                fontSize: 14.2,
                color: palette.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Rechercher sur la carte',
                hintStyle: AppTypography.caption.copyWith(
                  fontSize: 12.6,
                  color: palette.textSecondary,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: palette.brandPrimary,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _CircleActionButton(
          icon: Icons.refresh_rounded,
          onTap: onRefresh,
          tooltip: 'Actualiser la carte',
        ),
        const SizedBox(width: 8),
        _CircleActionButton(
          icon: Icons.my_location_rounded,
          onTap: onLocate,
          isLoading: isLocating,
          tooltip: 'Afficher ma position',
        ),
      ],
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.icon,
    required this.onTap,
    this.isLoading = false,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isLoading;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: isLoading ? null : onTap,
            child: Ink(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: palette.brandPrimary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(11),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(icon, color: palette.brandPrimaryContrast),
            ),
          ),
        ),
      ),
    );
  }
}

class _OsmAttribution extends StatelessWidget {
  const _OsmAttribution();

  static final Uri _copyrightUri = Uri.parse(
    'https://www.openstreetmap.org/copyright',
  );

  Future<void> _openCopyright() async {
    await launchUrl(_copyrightUri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        label: 'Attribution OpenStreetMap',
        link: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _openCopyright,
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: palette.cardSurface.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(12),
              ),
              child: RichText(
                text: TextSpan(
                  text: 'Cartes © OpenStreetMap contributors',
                  style: AppTypography.caption.copyWith(
                    fontSize: 11.6,
                    color: palette.brandPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapSelectionPanel extends StatelessWidget {
  const _MapSelectionPanel({
    required this.selectedSite,
    required this.visibleCount,
    required this.showOutsideCoverageActions,
    this.onOpenDetails,
    this.onDirections,
    this.onClearSelection,
    this.onReturnToAlgeria,
    this.onShowNearestSites,
  });

  final TouristSite? selectedSite;
  final int visibleCount;
  final bool showOutsideCoverageActions;
  final VoidCallback? onOpenDetails;
  final VoidCallback? onDirections;
  final VoidCallback? onClearSelection;
  final VoidCallback? onReturnToAlgeria;
  final VoidCallback? onShowNearestSites;

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);
    if (selectedSite == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: palette.cardSurface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              showOutsideCoverageActions
                  ? 'Position hors couverture Algérie. La carte reste sur le catalogue local.'
                  : '$visibleCount lieux visibles. Touchez un marqueur pour les détails.',
              style: AppTypography.caption.copyWith(
                fontSize: 12.8,
                color: palette.textSecondary,
              ),
            ),
            if (showOutsideCoverageActions) ...<Widget>[
              const SizedBox(height: AppSpacing.x2),
              Wrap(
                spacing: AppSpacing.x2,
                runSpacing: AppSpacing.x2,
                children: <Widget>[
                  OutlinedButton(
                    onPressed: onReturnToAlgeria,
                    child: const Text('Retour Algérie'),
                  ),
                  FilledButton(
                    onPressed: onShowNearestSites,
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.brandPrimary,
                      foregroundColor: palette.brandPrimaryContrast,
                    ),
                    child: const Text('Sites proches'),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    final TouristSite site = selectedSite!;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: palette.cardSurface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AppSiteImage(
              imagePath: site.imageUrl,
              width: 62,
              height: 62,
              fit: BoxFit.cover,
              fallback: Container(
                width: 62,
                height: 62,
                color: palette.softSurface,
                alignment: Alignment.center,
                child: const Icon(Icons.image_not_supported_outlined),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        site.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong.copyWith(
                          fontSize: 15,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SiteRatingLabel(rating: site.averageRating),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        site.city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          fontSize: 12.2,
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '  ·  ',
                      style: AppTypography.caption.copyWith(
                        fontSize: 12.2,
                        color: palette.textSecondary,
                      ),
                    ),
                    Text(
                      site.category.label,
                      style: AppTypography.caption.copyWith(
                        fontSize: 12.2,
                        fontWeight: FontWeight.w700,
                        color: palette.brandPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x2),
                Row(
                  children: <Widget>[
                    TextButton(
                      onPressed: onOpenDetails,
                      style: TextButton.styleFrom(
                        foregroundColor: palette.brandPrimary,
                        minimumSize: const Size(10, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('Détails'),
                    ),
                    const SizedBox(width: AppSpacing.x1),
                    FilledButton(
                      onPressed: onDirections,
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.brandPrimary,
                        foregroundColor: palette.brandPrimaryContrast,
                        minimumSize: const Size(10, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        textStyle: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.3,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Itinéraire'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClearSelection,
            tooltip: 'Désélectionner',
            icon: Icon(Icons.close_rounded, color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _MapFilter {
  const _MapFilter({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String? key;
  final String label;
  final IconData icon;
}

class _MapFilterChips extends StatelessWidget {
  const _MapFilterChips({
    required this.filters,
    required this.selectedKey,
    required this.onSelect,
  });

  final List<_MapFilter> filters;
  final String? selectedKey;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final _MapFilter filter = filters[index];
          final bool selected = selectedKey == filter.key;
          return Semantics(
            button: true,
            selected: selected,
            label: 'Filtrer par ${filter.label}',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onSelect(filter.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? palette.brandPrimary.withValues(alpha: 0.9)
                        : palette.cardSurface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected ? palette.brandPrimary : palette.divider,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        filter.icon,
                        size: 15,
                        color: selected
                            ? palette.brandPrimaryContrast
                            : palette.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        filter.label,
                        style: AppTypography.caption.copyWith(
                          fontSize: 12.3,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? palette.brandPrimaryContrast
                              : palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
