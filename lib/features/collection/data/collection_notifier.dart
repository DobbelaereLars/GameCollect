import 'package:flutter/foundation.dart';

import '../../../core/database/database_helper.dart';
import '../domain/collection_item.dart';

/// Beheert de gedeelde collectiestaat (loading / error / data) als ChangeNotifier.
///
/// Dit is de enige source-of-truth voor de lijst van [CollectionItem]s in de
/// hele app. Luistert automatisch op [DatabaseHelper] voor database-wijzigingen
/// en herlaadt de data zonder dat UI-widgets handmatige `addListener`-aanroepen
/// nodig hebben.
class CollectionNotifier extends ChangeNotifier {
  CollectionNotifier() {
    DatabaseHelper.instance.addListener(_onDatabaseChanged);
    _load();
  }

  List<CollectionItem> _items = [];
  bool _isLoading = true;
  String? _error;

  /// Alle collectie-items uit de lokale database.
  List<CollectionItem> get items => _items;

  /// True terwijl de data voor het eerst (of na een fout) opnieuw geladen wordt.
  bool get isLoading => _isLoading;

  /// Foutmelding als het laden mislukt is; anders null.
  String? get error => _error;

  /// Dwingt een herlading af (bijv. na een cloud-sync).
  Future<void> reload() => _load();

  Future<void> _load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await DatabaseHelper.instance.getCollectionItems();
      _isLoading = false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
    }
    notifyListeners();
  }

  void _onDatabaseChanged() => _load();

  @override
  void dispose() {
    DatabaseHelper.instance.removeListener(_onDatabaseChanged);
    super.dispose();
  }
}
