import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/scale_tap.dart';
import '../../../core/database/database_helper.dart';
import '../data/collection_notifier.dart';
import '../domain/collection_item.dart';
import 'collection_item_detail_page.dart';
import 'widgets/add_platform_sheet.dart';
import 'widgets/filter_bottom_sheet_content.dart';
import '../../discover/presentation/widgets/discover_search_bar.dart';
import '../../../core/preferences/view_preferences.dart';

/// Overzichtspagina van de gebruikerscollectie met zoekbalk, filters en raster/lijstweergave.
class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  /// Stel in op een gametitel om de zoekbalk vooraf in te vullen.
  /// De shell luistert hierop om automatisch naar de collectietab te schakelen.
  static final searchRequest = ValueNotifier<String?>(null);

  /// Stel in op een item-ID om direct naar de detailpagina van dat item te navigeren.
  static final itemDetailRequest = ValueNotifier<int?>(null);

  /// Signaal om de lijst terug naar boven te scrollen.
  static final scrollToTopRequest = ValueNotifier<int>(0);

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  // UI-state: zichtlijkheid, filters en zoektekst blijven lokaal in de widget.
  bool _isGridView = ViewPreferences.defaultCollectionIsGridView;
  Set<String> _selectedFormats = {};
  Set<String> _selectedPlatforms = {};

  /// Berekent de beschikbare platforms uit de gedeelde [CollectionNotifier].
  List<String> _availablePlatforms(List<CollectionItem> items) {
    final platforms = <String>{};
    for (final item in items) {
      for (final p in item.selectedPlatforms) {
        platforms.add(p.replaceAll(RegExp(r' \(.*\)$'), ''));
      }
    }
    final sorted = platforms.toList()..sort();
    return sorted;
  }

  @override
  void initState() {
    super.initState();
    _loadViewPreference();
    // App-state (collectielijst) wordt beheerd door CollectionNotifier via
    // de provider — geen handmatige DatabaseHelper-listener nodig.
    _searchController.addListener(_applyFilters);
    CollectionPage.searchRequest.addListener(_onSearchRequest);
    CollectionPage.itemDetailRequest.addListener(_onItemDetailRequest);
    CollectionPage.scrollToTopRequest.addListener(_onScrollToTop);
    if (CollectionPage.searchRequest.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onSearchRequest());
    }
    if (CollectionPage.itemDetailRequest.value != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _onItemDetailRequest(),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    CollectionPage.searchRequest.removeListener(_onSearchRequest);
    CollectionPage.itemDetailRequest.removeListener(_onItemDetailRequest);
    CollectionPage.scrollToTopRequest.removeListener(_onScrollToTop);
    super.dispose();
  }

  /// Scrollt de lijst naar boven na een tab-tik op het collectie-icoon.
  void _onScrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Verwerkt een extern zoekverzoek: navigeert naar boven en vult de zoekbalk in.
  void _onSearchRequest() {
    final query = CollectionPage.searchRequest.value;
    if (query == null) return;
    CollectionPage.searchRequest.value = null;
    // Pop alle open detail-/instellingen-/notities-pagina's op dit tabblad.
    Navigator.of(context).popUntil((route) => route.isFirst);
    _selectedFormats = {};
    _selectedPlatforms = {};
    _searchController.removeListener(_applyFilters);
    _searchController.text = query;
    _searchController.addListener(_applyFilters);
    _applyFilters();
  }

  /// Verwerkt een extern itemdetailverzoek: opent de detailpagina na het sluiten van andere routes.
  void _onItemDetailRequest() {
    final itemId = CollectionPage.itemDetailRequest.value;
    if (itemId == null || !mounted) return;
    CollectionPage.itemDetailRequest.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CollectionItemDetailPage(itemId: itemId),
        ),
      );
    });
  }

  /// Laadt de weergavevoorkeur (raster of lijst) uit SharedPreferences.
  Future<void> _loadViewPreference() async {
    final value = await ViewPreferences.getCollectionIsGridView();
    if (!mounted) return;
    if (value != _isGridView) {
      setState(() => _isGridView = value);
    }
  }

  /// Signaleert een rebuild zodat de gefilterde lijst opnieuw berekend wordt.
  /// De daadwerkelijke filtering vindt plaats in [_computeFiltered] (pure functie).
  void _applyFilters() {
    if (mounted) setState(() {});
  }

  /// Berekent de gefilterde itemlijst op basis van [allItems] en de huidige
  /// UI-staat (zoekterm, geselecteerde platforms en formaten).
  List<CollectionItem> _computeFiltered(List<CollectionItem> allItems) {
    final query = _searchController.text.toLowerCase();
    return allItems.where((item) {
      final matchesQuery = item.title.toLowerCase().contains(query);
      bool matchesAnyPlatform = false;
      if (_selectedFormats.isEmpty && _selectedPlatforms.isEmpty) {
        matchesAnyPlatform = true;
      } else {
        for (final p in item.selectedPlatforms) {
          final cleanPlatform = p.replaceAll(RegExp(r' \(.*\)$'), '');
          String specificFormat = 'Fysiek & Digitaal';
          final formatMatch = RegExp(r'\((.*?)\)$').firstMatch(p);
          if (formatMatch != null) {
            specificFormat = formatMatch.group(1) ?? 'Fysiek & Digitaal';
          }
          if (specificFormat == 'Allebei') specificFormat = 'Fysiek & Digitaal';
          final pMatchesFormat =
              _selectedFormats.isEmpty ||
              _selectedFormats.contains(specificFormat);
          final pMatchesPlatform =
              _selectedPlatforms.isEmpty ||
              _selectedPlatforms.contains(cleanPlatform);
          if (pMatchesFormat && pMatchesPlatform) {
            matchesAnyPlatform = true;
            break;
          }
        }
      }
      return matchesQuery && matchesAnyPlatform;
    }).toList();
  }

  void _showFilterBottomSheet() {
    // App-state lezen zonder te luisteren (geen rebuild nodig hier).
    final allItems = context.read<CollectionNotifier>().items;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FilterBottomSheetContent(
        availablePlatforms: _availablePlatforms(allItems),
        initialFormats: Set.from(_selectedFormats),
        initialPlatforms: Set.from(_selectedPlatforms),
        hasActiveFilters:
            _selectedFormats.isNotEmpty || _selectedPlatforms.isNotEmpty,
        onClearFilters: () => setState(() {
          _selectedFormats.clear();
          _selectedPlatforms.clear();
        }),
        onApply: (formats, platforms) => setState(() {
          _selectedFormats = formats;
          _selectedPlatforms = platforms;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // App-state: luisteren op CollectionNotifier triggert een rebuild wanneer
    // de collectie in de database wijzigt. Filtering (UI-state) wordt daarna
    // puur berekend zonder extra setState-aanroepen.
    final collection = context.watch<CollectionNotifier>();
    final allItems = collection.items;
    final isLoading = collection.isLoading;
    final filteredItems = _computeFiltered(allItems);

    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Glass effect search bar area
            if (isLoading || allItems.isNotEmpty)
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: AppTheme.white,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DiscoverSearchBar(
                                controller: _searchController,
                                onChanged: (val) => _applyFilters(),
                                onSubmitted: (_) {},
                                onClearPressed: () {
                                  _searchController.clear();
                                  FocusScope.of(context).unfocus();
                                },
                                showCameraButton: false,
                                onCameraPressed: () {},
                                isCameraBusy: false,
                                isCameraDisabled: false,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                _isGridView
                                    ? LucideIcons.layoutList
                                    : LucideIcons.layoutGrid,
                                color: AppTheme.orange500,
                              ),
                              onPressed: () {
                                setState(() => _isGridView = !_isGridView);
                                ViewPreferences.setCollectionIsGridView(
                                  _isGridView,
                                );
                              },
                            ),
                            IconButton(
                              icon: Stack(
                                children: [
                                  const Icon(
                                    LucideIcons.listFilter,
                                    color: AppTheme.orange500,
                                  ),
                                  if (_selectedFormats.isNotEmpty ||
                                      _selectedPlatforms.isNotEmpty)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: AppTheme.orange500,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppTheme.white,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              onPressed: _showFilterBottomSheet,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            // Content
            Expanded(child: _buildBody(allItems, isLoading, filteredItems)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    List<CollectionItem> allItems,
    bool isLoading,
    List<CollectionItem> filteredItems,
  ) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.orange500),
      );
    }

    if (allItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              LucideIcons.library,
              size: 64,
              color: AppTheme.orange500,
            ),
            const SizedBox(height: 16),
            Text(
              'Je collectie is nog leeg.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppTheme.gray700),
            ),
            const SizedBox(height: 8),
            Text(
              'Voeg games toe via de Ontdekken pagina',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.gray500),
            ),
          ],
        ),
      );
    }

    Map<String, List<CollectionItem>> groupedItems = {};
    for (final item in filteredItems) {
      for (final platformWithFormat in item.selectedPlatforms) {
        final platformNameMatch = RegExp(
          r"^(.*?)(?:\s*\([^)]*\))?$",
        ).firstMatch(platformWithFormat);
        final platform =
            platformNameMatch?.group(1)?.trim() ?? "Onbekend Platform";

        String specificFormat = "Fysiek & Digitaal";
        final formatMatch = RegExp(
          r"\((.*?)\)$",
        ).firstMatch(platformWithFormat);
        if (formatMatch != null) {
          specificFormat = formatMatch.group(1) ?? "Fysiek & Digitaal";
        }
        if (specificFormat == 'Allebei') {
          specificFormat = 'Fysiek & Digitaal';
        }

        // Apply filters to this specific platform occurrence
        if (_selectedPlatforms.isNotEmpty &&
            !_selectedPlatforms.contains(platform)) {
          continue;
        }

        if (_selectedFormats.isNotEmpty) {
          if (!_selectedFormats.contains(specificFormat)) {
            continue; // Exclude this platform instance since it doesn't match the selected format
          }
        }

        if (!groupedItems.containsKey(platform)) {
          groupedItems[platform] = [];
        }
        if (!groupedItems[platform]!.contains(item)) {
          groupedItems[platform]!.add(item);
        }
      }
    }

    if (groupedItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              LucideIcons.searchX,
              size: 64,
              color: AppTheme.orange500,
            ),
            const SizedBox(height: 16),
            Text(
              'Geen resultaten voor deze filters.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppTheme.gray700),
            ),
          ],
        ),
      );
    }

    final sortedPlatforms = groupedItems.keys.toList()..sort();

    if (_isGridView) {
      // Group filtered items by apiId so games with multiple platforms
      // become ONE card that cycles through its platforms (same as overview).
      final passingItems = <CollectionItem>{};
      for (final platform in sortedPlatforms) {
        passingItems.addAll(groupedItems[platform]!);
      }
      final seenApiIds = <int>{};
      final groups = <List<CollectionItem>>[];
      for (final item in filteredItems) {
        if (!passingItems.contains(item)) continue;
        if (seenApiIds.add(item.apiId)) {
          final allForGame = filteredItems
              .where((e) => e.apiId == item.apiId && passingItems.contains(e))
              .toList(growable: false);
          groups.add(allForGame);
        }
      }
      return GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 2 / 3,
        ),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          return _GridCoverCard(
            group: group,
            onTap: (item) {
              if (item.id != null) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CollectionItemDetailPage(itemId: item.id!),
                  ),
                );
              }
            },
            onLongPress: (item) async {
              final platformWithFormat = item.selectedPlatforms.isNotEmpty
                  ? item.selectedPlatforms.first
                  : '';
              final platform = platformWithFormat
                  .replaceAll(RegExp(r'\s*\([^)]*\)$'), '')
                  .trim();
              await _showItemOptions(
                item,
                specificPlatform: platform,
                specificPlatformWithFormat: platformWithFormat,
              );
            },
          );
        },
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(left: 16, right: 16, top: 0, bottom: 90),
      itemCount: sortedPlatforms.length,
      itemBuilder: (context, index) {
        final platform = sortedPlatforms[index];
        final items = groupedItems[platform]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 16.0, bottom: 8.0),
              child: Text(
                platform,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.gray500,
                  fontFamily: 'Manrope',
                ),
              ),
            ),
            ...items.map((item) {
              final platformString = item.selectedPlatforms.firstWhere(
                (p) => p.startsWith(platform),
                orElse: () => "$platform (Fysiek & Digitaal)",
              );

              String specificFormat = "Fysiek & Digitaal";
              final formatMatch = RegExp(
                r"\((.*?)\)$",
              ).firstMatch(platformString);
              if (formatMatch != null) {
                specificFormat = formatMatch.group(1) ?? "Fysiek & Digitaal";
              }
              if (specificFormat == 'Allebei') {
                specificFormat = 'Fysiek & Digitaal';
              }

              IconData formatIcon;
              if (specificFormat == 'Fysiek') {
                formatIcon = LucideIcons.disc;
              } else if (specificFormat == 'Digitaal') {
                formatIcon = LucideIcons.download;
              } else {
                formatIcon = LucideIcons.layers;
              }

              return _buildCollectionCard(
                context: context,
                item: item,
                specificFormat: specificFormat,
                formatIcon: formatIcon,
                platform: platform,
                platformString: platformString,
              );
            }),
          ],
        );
      },
    );
  }

  /// Bouwt een collectiekaart met omslagafbeelding, metagegevens en voortgangsbalk.
  Widget _buildCollectionCard({
    required BuildContext context,
    required CollectionItem item,
    required String specificFormat,
    required IconData formatIcon,
    required String platform,
    required String platformString,
  }) {
    return _CollectionListCard(
      item: item,
      specificFormat: specificFormat,
      formatIcon: formatIcon,
      onLongPress: item.id == null
          ? null
          : () => _showItemOptions(
              item,
              specificPlatform: platform,
              specificPlatformWithFormat: platformString,
            ),
      onOptionsPressed: () => _showItemOptions(
        item,
        specificPlatform: platform,
        specificPlatformWithFormat: platformString,
      ),
    );
  }

  Future<void> _showItemOptions(
    CollectionItem item, {
    required String specificPlatform,
    required String specificPlatformWithFormat,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final sameGameCount = await DatabaseHelper.instance
        .countCollectionItemsByApiId(item.apiId);
    if (!mounted) {
      return;
    }

    final hasMultipleGameEntries = sameGameCount > 1;

    // Determine unowned platforms
    final allItems = await DatabaseHelper.instance.getCollectionItemsByApiId(
      item.apiId,
    );
    final usedNames = <String>{};
    for (final it in allItems) {
      for (final p in it.selectedPlatforms) {
        final name = p.replaceAll(RegExp(r' \(.*\)$'), '');
        if (name.isNotEmpty) usedNames.add(name);
      }
    }
    final unownedPlatforms = item.availablePlatforms
        .where((p) => !usedNames.contains(p))
        .toList();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (unownedPlatforms.isNotEmpty)
                  ListTile(
                    leading: const Icon(
                      LucideIcons.circlePlus,
                      color: AppTheme.orange500,
                    ),
                    title: Text(
                      'Toevoegen aan ander platform',
                      style: const TextStyle(color: AppTheme.orange500),
                    ),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await AddPlatformSheet.show(
                        context,
                        item: item,
                        unownedPlatforms: unownedPlatforms,
                        onAdded: () {
                          // CollectionNotifier herlaadt automatisch via
                          // DatabaseHelper.notifyListeners().
                        },
                      );
                    },
                  ),
                ListTile(
                  leading: Icon(
                    hasMultipleGameEntries
                        ? LucideIcons.minus
                        : LucideIcons.trash2,
                    color: Colors.red,
                  ),
                  title: Text(
                    'Verwijder "${item.title}" van $specificPlatform',
                    style: const TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _showDeleteConfirmSheet(
                      title: '${item.title} verwijderen?',
                      description: hasMultipleGameEntries
                          ? 'De game wordt verwijderd van $specificPlatform. Al je voortgang, speelduur en instellingen voor dit platform gaan permanent verloren.'
                          : 'De game wordt volledig verwijderd uit je collectie. Al je voortgang, speelduur, achievements en instellingen gaan permanent verloren.',
                      buttonLabel: 'Verwijderen',
                      onConfirm: () async {
                        if (item.id != null) {
                          final updatedPlatforms = List<String>.from(
                            item.selectedPlatforms,
                          )..remove(specificPlatformWithFormat);

                          if (updatedPlatforms.isEmpty) {
                            await DatabaseHelper.instance.deleteCollectionItem(
                              item.id!,
                            );
                          } else {
                            await DatabaseHelper.instance.updateCollectionItem(
                              item.copyWith(
                                selectedPlatforms: updatedPlatforms,
                              ),
                            );
                          }

                          // CollectionNotifier herlaadt automatisch via
                          // DatabaseHelper.notifyListeners().
                          if (mounted) {
                            messenger
                              ..removeCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '"${item.title}" verwijderd van $specificPlatform.',
                                  ),
                                ),
                              );
                          }
                        }
                      },
                    );
                  },
                ),
                if (hasMultipleGameEntries)
                  ListTile(
                    leading: const Icon(LucideIcons.trash2, color: Colors.red),
                    title: Text(
                      'Verwijder "${item.title}" van elk platform',
                      style: const TextStyle(color: Colors.red),
                    ),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await _showDeleteConfirmSheet(
                        title: '${item.title} volledig verwijderen?',
                        description:
                            'De game wordt van elk platform verwijderd. Al je voortgang, speelduur, achievements en instellingen gaan permanent verloren.',
                        buttonLabel: 'Volledig verwijderen',
                        onConfirm: () async {
                          await DatabaseHelper.instance
                              .deleteCollectionItemsByApiId(item.apiId);
                          // CollectionNotifier herlaadt automatisch via
                          // DatabaseHelper.notifyListeners().
                          if (mounted) {
                            messenger
                              ..removeCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '"${item.title}" volledig verwijderd uit je collectie.',
                                  ),
                                ),
                              );
                          }
                        },
                      );
                    },
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDeleteConfirmSheet({
    required String title,
    required String description,
    required String buttonLabel,
    required Future<void> Function() onConfirm,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(sheetContext).viewInsets.bottom + 40,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.black,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: Icon(LucideIcons.x, color: AppTheme.black),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                  color: AppTheme.gray700,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  await onConfirm();
                },
                icon: const Icon(LucideIcons.trash2, size: 18),
                label: Text(
                  buttonLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.orange500,
                  side: const BorderSide(color: AppTheme.orange500),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Grid cover card with platform cycling ─────────────────────────────────────

class _GridCoverCard extends StatefulWidget {
  const _GridCoverCard({
    required this.group,
    required this.onTap,
    required this.onLongPress,
  });

  final List<CollectionItem> group;
  final void Function(CollectionItem item) onTap;
  final Future<void> Function(CollectionItem item) onLongPress;

  @override
  State<_GridCoverCard> createState() => _GridCoverCardState();
}

class _GridCoverCardState extends State<_GridCoverCard> {
  int _selectedIndex = 0;
  bool _forward = true;
  Timer? _cycleTimer;

  @override
  void initState() {
    super.initState();
    _startCycleIfNeeded();
  }

  @override
  void didUpdateWidget(_GridCoverCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.length != widget.group.length) {
      _selectedIndex = _selectedIndex.clamp(0, widget.group.length - 1);
      _startCycleIfNeeded();
    }
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    super.dispose();
  }

  void _startCycleIfNeeded() {
    _cycleTimer?.cancel();
    if (widget.group.length <= 1) return;
    _cycleTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() {
        _forward = true;
        _selectedIndex = (_selectedIndex + 1) % widget.group.length;
      });
    });
  }

  CollectionItem get _current {
    final idx = _selectedIndex.clamp(0, widget.group.length - 1);
    return widget.group[idx];
  }

  String _cleanPlatformName(String raw) {
    return raw.replaceAll(RegExp(r'\s*\([^)]*\)$'), '').trim();
  }

  Widget _coverWidget(CollectionItem item) {
    if (item.customCoverPath != null) {
      return SizedBox.expand(
        child: Image.file(
          File(item.customCoverPath!),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _placeholder(),
        ),
      );
    }
    if (item.coverUrl != null) {
      return SizedBox.expand(
        child: Image.network(
          item.coverUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: AppTheme.orange50,
      child: Center(
        child: Icon(LucideIcons.gamepad2, color: AppTheme.gray300, size: 28),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasMultiple = widget.group.length > 1;
    final current = _current;
    final platformName = current.selectedPlatforms.isNotEmpty
        ? _cleanPlatformName(current.selectedPlatforms.first)
        : null;
    final bool isCompleted = widget.group.every(
      (e) => e.isManuallyCompleted || e.progressRatio >= 1.0,
    );

    return ScaleTap(
      onTap: () => widget.onTap(current),
      onLongPress: () => widget.onLongPress(current),
      child: GestureDetector(
        onTap: () => widget.onTap(current),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Cover image with swipe animation on platform switch
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  transitionBuilder: (child, animation) {
                    final dir = _forward ? 1.0 : -1.0;
                    final isIncoming = child.key == ValueKey(_selectedIndex);
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOut,
                    );
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: isIncoming
                            ? Offset(dir, 0.0)
                            : Offset(-dir, 0.0),
                        end: Offset.zero,
                      ).animate(curved),
                      child: child,
                    );
                  },
                  child: Container(
                    key: ValueKey(_selectedIndex),
                    color: AppTheme.orange50,
                    child: _coverWidget(current),
                  ),
                ),
              ),

              // Top-left platform badge (same style as overview _CoverBadge)
              if (platformName != null)
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.orange50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.gamepad2,
                                size: 11,
                                color: AppTheme.orange500,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  platformName.isNotEmpty ? platformName : '?',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.orange700,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Trophy badge — top-right bij 100% voltooiing
              if (isCompleted)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppTheme.orange500,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      LucideIcons.trophy,
                      size: 11,
                      color: AppTheme.trueWhite,
                    ),
                  ),
                ),

              // Bottom gradient + game title + dot indicators
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 28, 8, 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.blackTransparent0,
                        AppTheme.blackTransparent80,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        current.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppTheme.trueWhite,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      if (hasMultiple) ...[
                        const SizedBox(height: 6),
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(widget.group.length, (i) {
                              final isActive = i == _selectedIndex;
                              return GestureDetector(
                                onTap: () {
                                  _cycleTimer?.cancel();
                                  setState(() {
                                    _forward = i > _selectedIndex;
                                    _selectedIndex = i;
                                  });
                                  Future.delayed(
                                    const Duration(seconds: 4),
                                    () {
                                      if (mounted) _startCycleIfNeeded();
                                    },
                                  );
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: isActive ? 16 : 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? AppTheme.orange500
                                          : AppTheme.orange200,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Collectielijstkaart
// ─────────────────────────────────────────────────────────────────────────────

/// Kaartwidget voor een enkel collectie-item in de lijstweergave.
///
/// Toont cover, titel, formaat, uitgever, voortgangsbalk en tags.
/// Navigatie en optiemenu-logica worden via callbacks doorgegeven vanuit
/// [_CollectionPageState], wat zorgt voor strikte scheiding van UI en logica.
class _CollectionListCard extends StatelessWidget {
  const _CollectionListCard({
    required this.item,
    required this.specificFormat,
    required this.formatIcon,
    required this.onLongPress,
    required this.onOptionsPressed,
  });

  final CollectionItem item;
  final String specificFormat;
  final IconData formatIcon;
  final Future<void> Function()? onLongPress;
  final VoidCallback onOptionsPressed;

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: item.id == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CollectionItemDetailPage(itemId: item.id!),
              ),
            ),
      onLongPress: onLongPress,
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        color: AppTheme.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.gray100),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: item.id == null
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CollectionItemDetailPage(itemId: item.id!),
                  ),
                ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cover afbeelding vult kaardhoogte
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                  child: SizedBox(
                    width: 100,
                    child: item.customCoverPath != null
                        ? Image.file(
                            File(item.customCoverPath!),
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (_, _, _) => _CoverPlaceholder(),
                          )
                        : (item.coverUrl != null
                              ? Image.network(
                                  item.coverUrl!,
                                  fit: BoxFit.cover,
                                  semanticLabel:
                                      'Omslagafbeelding van ${item.title}',
                                  errorBuilder: (_, _, _) =>
                                      _CoverPlaceholder(),
                                )
                              : _CoverPlaceholder()),
                  ),
                ),
                // Metadata kolom
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.black,
                                height: 1.2,
                              ),
                        ),
                        const SizedBox(height: 8),
                        // Formaat badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.orange50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                formatIcon,
                                size: 12,
                                color: AppTheme.orange500,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                specificFormat,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: AppTheme.orange700,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (item.publisher != null &&
                            item.publisher!.isNotEmpty)
                          Row(
                            children: [
                              Icon(
                                LucideIcons.building,
                                size: 14,
                                color: AppTheme.gray500,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  item.publisher!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppTheme.gray500,
                                        fontSize: 12,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 8),
                        // Voortgangsbalk
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Semantics(
                                label: 'Voortgang van ${item.title}',
                                value: '${(item.progressRatio * 100).round()}%',
                                child: LinearProgressIndicator(
                                  value: item.progressRatio,
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(999),
                                  backgroundColor: AppTheme.progressTrack,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        AppTheme.orange500,
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(item.progressRatio * 100).round()}%',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                                color: (item.isManuallyCompleted ||
                                        item.progressRatio >= 1.0)
                                    ? AppTheme.orange500
                                    : AppTheme.gray500,
                              ),
                            ),
                            if (item.isManuallyCompleted ||
                                item.progressRatio >= 1.0) ...[                              
                              const SizedBox(width: 4),
                              const Icon(
                                LucideIcons.trophy,
                                size: 13,
                                color: AppTheme.orange500,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        _CardTagsRow(item: item),
                      ],
                    ),
                  ),
                ),
                // Optiemenu
                IconButton(
                  icon: Icon(
                    LucideIcons.ellipsisVertical,
                    size: 20,
                    color: AppTheme.gray500,
                  ),
                  onPressed: onOptionsPressed,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Placeholder widget voor ontbrekende of mislukte cover-afbeeldingen.
class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.orange50,
      child: Center(
        child: Icon(LucideIcons.gamepad2, color: AppTheme.gray300, size: 34),
      ),
    );
  }
}

/// Rij met tagchips voor een collectie-item. Toont maximaal drie tags en
/// een "+N meer" indicator. Als er geen tags zijn, toont het een knop om tags
/// toe te voegen.
class _CardTagsRow extends StatelessWidget {
  const _CardTagsRow({required this.item});

  final CollectionItem item;

  @override
  Widget build(BuildContext context) {
    final previewTags = item.activeTags.take(3).toList(growable: false);
    final remainingCount = item.activeTags.length - previewTags.length;

    if (previewTags.isEmpty) {
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: item.id == null
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CollectionItemDetailPage(
                    itemId: item.id!,
                    openTagsOnStart: true,
                  ),
                ),
              ),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.plus, size: 14, color: AppTheme.orange500),
              SizedBox(width: 4),
              Text(
                'Tags toevoegen',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  color: AppTheme.orange500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 24,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...previewTags.map(
              (tag) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.orange100),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      color: AppTheme.black,
                    ),
                  ),
                ),
              ),
            ),
            if (remainingCount > 0)
              Text(
                '+$remainingCount meer',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  color: AppTheme.orange700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
