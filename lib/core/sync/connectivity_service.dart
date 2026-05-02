import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Meldt of het toestel momenteel een werkende internetverbinding heeft.
///
/// Gebruikt `connectivity_plus` voor transportgebeurtenissen en een lichte
/// `InternetAddress.lookup` om daadwerkelijke bereikbaarheid te bevestigen.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService._();

  /// Singleton-instantie, globaal toegankelijk.
  static final ConnectivityService instance = ConnectivityService._();

  // Onderliggende connectivity-plugin.
  final Connectivity _connectivity = Connectivity();

  // Actief luisterabonnement op connectiviteitswijzigingen.
  StreamSubscription<List<ConnectivityResult>>? _sub;

  // Huidige online-status.
  bool _isOnline = false;

  // Voorkomt dubbele initialisatie.
  bool _initialized = false;

  /// True als het toestel momenteel online is.
  bool get isOnline => _isOnline;

  /// Initialiseert de service en start het luisteren op verbindingswijzigingen.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _refresh();
    _sub = _connectivity.onConnectivityChanged.listen((_) => _refresh());
  }

  /// Controleert opnieuw de connectiviteitstatus en werkt [isOnline] bij.
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

  /// Publieke hook om de verbinding opnieuw te controleren (bijv. na handmatige sync).
  Future<bool> recheck() async {
    await _refresh();
    return _isOnline;
  }

  /// Test daadwerkelijke internetbereikbaarheid via een DNS-lookup.
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

  /// Annuleert het connectiviteitsabonnement bij dispose.
  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
