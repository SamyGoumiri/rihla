import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService({
    Connectivity? connectivity,
    Stream<dynamic>? connectivityChanges,
    Future<dynamic> Function()? checkConnectivity,
  }) : _connectivity = connectivity ?? Connectivity(),
       _connectivityChanges = connectivityChanges,
       _checkConnectivity = checkConnectivity;

  final Connectivity _connectivity;
  final Stream<dynamic>? _connectivityChanges;
  final Future<dynamic> Function()? _checkConnectivity;

  Stream<bool> get isOnlineStream =>
      (_connectivityChanges ?? _connectivity.onConnectivityChanged)
          .map(_isConnectedFromEvent)
          .distinct();

  Future<bool> isOnlineNow() async {
    final status = _checkConnectivity == null
        ? await _connectivity.checkConnectivity()
        : await _checkConnectivity();
    return _isConnectedFromEvent(status);
  }

  bool _isConnectedFromEvent(dynamic event) {
    if (event is ConnectivityResult) {
      return event != ConnectivityResult.none;
    }

    if (event is List<ConnectivityResult>) {
      return event.any((result) => result != ConnectivityResult.none);
    }

    return true;
  }
}
