import 'package:shared_preferences/shared_preferences.dart';

/// Lokale (device-only) opslag van UI view-voorkeuren.
///
/// Deze waarden worden bewust NIET naar Firestore gesynchroniseerd, omdat het
/// gaat om persoonlijke weergave-instellingen per toestel.
class ViewPreferences {
  ViewPreferences._();

  // Sleutels voor SharedPreferences
  static const _kCollectionGridView = 'view.collection.isGridView';
  static const _kDiscoverGridColumns = 'view.discover.gridColumns';

  // Standaardwaarden
  static const bool defaultCollectionIsGridView = false; // lijstweergave
  static const int defaultDiscoverGridColumns = 3; // 3-koloms raster

  /// Geeft terug of de collectie in rasterweergave getoond moet worden.
  static Future<bool> getCollectionIsGridView() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kCollectionGridView) ?? defaultCollectionIsGridView;
  }

  /// Sla de voorkeur op voor raster- of lijstweergave in de collectie.
  static Future<void> setCollectionIsGridView(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCollectionGridView, value);
  }

  /// Geeft het aantal kolommen terug voor het ontdekraster (2 of 3).
  static Future<int> getDiscoverGridColumns() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_kDiscoverGridColumns);
    if (stored == 2 || stored == 3) return stored!;
    return defaultDiscoverGridColumns;
  }

  /// Sla het aantal kolommen op voor het ontdekraster; accepteert alleen 2 of 3.
  static Future<void> setDiscoverGridColumns(int value) async {
    if (value != 2 && value != 3) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kDiscoverGridColumns, value);
  }
}
