import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Reports whether the device currently has a working internet connection.
///
/// Uses `connectivity_plus` for transport-level events and a lightweight
/// `InternetAddress.lookup` to confirm actual reachability.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _isOnline = false;
  bool _initialized = false;

  bool get isOnline => _isOnline;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _refresh();
    _sub = _connectivity.onConnectivityChanged.listen((_) => _refresh());
  }

  Future<void> _refresh() async {
    final results = await _connectivity.checkConnectivity();
    final hasTransport = results.any((r) => r != ConnectivityResult.none);
    bool reachable = false;
    if (hasTransport) {
      reachable = await _hasInternet();
    }
    if (reachable != _isOnline) {
      _isOnline = reachable;
      notifyListeners();
    }
  }

  /// Public hook to re-check connectivity (e.g. after a manual sync attempt).
  Future<bool> recheck() async {
    await _refresh();
    return _isOnline;
  }

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup(
        'firestore.googleapis.com',
      ).timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
