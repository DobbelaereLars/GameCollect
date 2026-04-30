import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/database/database_helper.dart';
import '../domain/collection_item.dart';
import 'collection_item_detail_page.dart';
import 'widgets/add_platform_sheet.dart';
import '../../discover/presentation/widgets/discover_search_bar.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  /// Set this to a game title to pre-fill the search bar and clear filters.
  /// The shell observes this to switch to the collection tab automatically.
  static final searchRequest = ValueNotifier<String?>(null);

  /// Set this to an item ID to open that item's detail page within the Collectie tab.
  /// The shell observes this to switch to tab 1; CollectionPage handles the push.
  static final itemDetailRequest = ValueNotifier<int?>(null);

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  final TextEditingController _searchController = TextEditingController();
  List<CollectionItem> _allItems = [];
  List<CollectionItem> _filteredItems = [];
  bool _isLoading = true;
  bool _isGridView = false;

  // Filters
  Set<String> _selectedFormats = {};
  Set<String> _selectedPlatforms = {};

  // Temporary filters for the filter sheet
  late Set<String> _tempFormats = {};
  late Set<String> _tempPlatforms = {};

  List<String> get _availablePlatforms {
    final platforms = <String>{};
    for (final item in _allItems) {
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
    _loadCollection();
    _searchController.addListener(_applyFilters);
    DatabaseHelper.instance.addListener(_loadCollection);
    CollectionPage.searchRequest.addListener(_onSearchRequest);
    CollectionPage.itemDetailRequest.addListener(_onItemDetailRequest);
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
    DatabaseHelper.instance.removeListener(_loadCollection);
    CollectionPage.searchRequest.removeListener(_onSearchRequest);
    CollectionPage.itemDetailRequest.removeListener(_onItemDetailRequest);
    super.dispose();
  }

  void _onSearchRequest() {
    final query = CollectionPage.searchRequest.value;
    if (query == null) return;
    CollectionPage.searchRequest.value = null;
    // Pop any detail/settings/notes pages open on this tab's navigator
    Navigator.of(context).popUntil((route) => route.isFirst);
    _selectedFormats = {};
    _selectedPlatforms = {};
    _searchController.removeListener(_applyFilters);
    _searchController.text = query;
    _searchController.addListener(_applyFilters);
    _applyFilters();
  }

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

  Future<void> _loadCollection() async {
    setState(() {
      _isLoading = true;
    });

    final items = await DatabaseHelper.instance.getCollectionItems();

    setState(() {
      _allItems = items;
      _isLoading = false;
      _applyFilters();
    });
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredItems = _allItems.where((item) {
        // Text search
        final matchesQuery = item.title.toLowerCase().contains(query);

        // Check if at least one platform matches both filters
        bool matchesAnyPlatform = false;

        if (_selectedFormats.isEmpty && _selectedPlatforms.isEmpty) {
          matchesAnyPlatform = true;
        } else {
          for (final p in item.selectedPlatforms) {
            final cleanPlatform = p.replaceAll(RegExp(r' \(.*\)$'), '');

            String specificFormat = "Fysiek & Digitaal";
            final formatMatch = RegExp(r"\((.*?)\)$").firstMatch(p);
            if (formatMatch != null) {
              specificFormat = formatMatch.group(1) ?? "Fysiek & Digitaal";
            }
            if (specificFormat == 'Allebei') {
              specificFormat = 'Fysiek & Digitaal';
            }

            bool pMatchesFormat = true;
            if (_selectedFormats.isNotEmpty) {
              pMatchesFormat = _selectedFormats.contains(specificFormat);
            }

            bool pMatchesPlatform = true;
            if (_selectedPlatforms.isNotEmpty) {
              pMatchesPlatform = _selectedPlatforms.contains(cleanPlatform);
            }

            if (pMatchesFormat && pMatchesPlatform) {
              matchesAnyPlatform = true;
              break;
            }
          }
        }

        return matchesQuery && matchesAnyPlatform;
      }).toList();
    });
  }

  void _showFilterBottomSheet() {
    // Initialize temp filters with current values
    _tempFormats = Set.from(_selectedFormats);
    _tempPlatforms = Set.from(_selectedPlatforms);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final textTheme = Theme.of(context).textTheme;
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filters',
                          style: textTheme.titleLarge?.copyWith(
                            color: AppTheme.black,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_selectedFormats.isNotEmpty ||
                                _selectedPlatforms.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedFormats.clear();
                                    _selectedPlatforms.clear();
                                  });
                                  _applyFilters();
                                  Navigator.of(context).pop();
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.orange500,
                                ),
                                child: const Text('Filters wissen'),
                              ),
                            IconButton(
                              icon: const Icon(
                                LucideIcons.x,
                                color: AppTheme.black,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Formaat',
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 0,
                      children: ['Fysiek', 'Digitaal', 'Fysiek & Digitaal'].map(
                        (format) {
                          final isSelected = _tempFormats.contains(format);
                          return FilterChip(
                            showCheckmark: false,
                            label: Text(format),
                            selected: isSelected,
                            onSelected: (selected) {
                              setSheetState(() {
                                if (selected) {
                                  _tempFormats.add(format);
                                } else {
                                  _tempFormats.remove(format);
                                }
                              });
                            },
                            selectedColor: AppTheme.orange500,
                            checkmarkColor: AppTheme.white,
                            labelStyle: textTheme.bodySmall?.copyWith(
                              color: isSelected
                                  ? AppTheme.white
                                  : AppTheme.black,
                              fontWeight: FontWeight.w600,
                            ),
                            backgroundColor: AppTheme.white,
                            shape: StadiumBorder(
                              side: BorderSide(
                                color: isSelected
                                    ? AppTheme.orange500
                                    : AppTheme.orange100,
                              ),
                            ),
                          );
                        },
                      ).toList(),
                    ),

                    const SizedBox(height: 24),
                    Text(
                      'Platform(s)',
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_availablePlatforms.isEmpty)
                      Text(
                        'Geen platformen gevonden.',
                        style: textTheme.bodySmall,
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 0,
                        children: _availablePlatforms.map((platform) {
                          final isSelected = _tempPlatforms.contains(platform);
                          return FilterChip(
                            showCheckmark: false,
                            label: Text(platform),
                            selected: isSelected,
                            onSelected: (selected) {
                              setSheetState(() {
                                if (selected) {
                                  _tempPlatforms.add(platform);
                                } else {
                                  _tempPlatforms.remove(platform);
                                }
                              });
                            },
                            selectedColor: AppTheme.orange500,
                            checkmarkColor: AppTheme.white,
                            labelStyle: textTheme.bodySmall?.copyWith(
                              color: isSelected
                                  ? AppTheme.white
                                  : AppTheme.black,
                              fontWeight: FontWeight.w600,
                            ),
                            backgroundColor: AppTheme.white,
                            shape: StadiumBorder(
                              side: BorderSide(
                                color: isSelected
                                    ? AppTheme.orange500
                                    : AppTheme.orange100,
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedFormats = _tempFormats;
                            _selectedPlatforms = _tempPlatforms;
                          });
                          _applyFilters();
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.orange500,
                          foregroundColor: AppTheme.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Toepassen',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Glass effect search bar area
            if (_isLoading || _allItems.isNotEmpty)
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: AppTheme.glassLight,
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
                              onPressed: () =>
                                  setState(() => _isGridView = !_isGridView),
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
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.orange500),
      );
    }

    if (_allItems.isEmpty) {
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
    for (final item in _filteredItems) {
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
      for (final item in _filteredItems) {
        if (!passingItems.contains(item)) continue;
        if (seenApiIds.add(item.apiId)) {
          final allForGame = _filteredItems
              .where((e) => e.apiId == item.apiId && passingItems.contains(e))
              .toList(growable: false);
          groups.add(allForGame);
        }
      }
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
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
          );
        },
      );
    }

    return ListView.builder(
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

  Widget _buildCollectionCard({
    required BuildContext context,
    required CollectionItem item,
    required String specificFormat,
    required IconData formatIcon,
    required String platform,
    required String platformString,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppTheme.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.gray100),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: item.id == null
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CollectionItemDetailPage(itemId: item.id!),
                  ),
                );
              },
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover image fills card height
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
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        )
                      : (item.coverUrl != null
                            ? Image.network(
                                item.coverUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildPlaceholder(),
                              )
                            : _buildPlaceholder()),
                ),
              ),
              // Meta data
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
                      if (item.publisher != null && item.publisher!.isNotEmpty)
                        Row(
                          children: [
                            const Icon(
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: item.progressRatio,
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(999),
                              backgroundColor: AppTheme.orange100,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppTheme.orange500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(item.progressRatio * 100).round()}%',
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                              color: AppTheme.gray500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildCardTagsRow(item),
                    ],
                  ),
                ),
              ),
              // Action menu
              IconButton(
                icon: const Icon(
                  LucideIcons.ellipsisVertical,
                  size: 20,
                  color: AppTheme.gray500,
                ),
                onPressed: () => _showItemOptions(
                  item,
                  specificPlatform: platform,
                  specificPlatformWithFormat: platformString,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppTheme.orange50,
      child: const Center(
        child: Icon(LucideIcons.gamepad2, color: AppTheme.black, size: 34),
      ),
    );
  }

  Widget _buildCardTagsRow(CollectionItem item) {
    final previewTags = item.activeTags.take(3).toList(growable: false);
    final remainingCount = item.activeTags.length - previewTags.length;

    if (previewTags.isEmpty) {
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: item.id == null
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CollectionItemDetailPage(
                      itemId: item.id!,
                      openTagsOnStart: true,
                    ),
                  ),
                );
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
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
            ...previewTags.map((tag) {
              return Padding(
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
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      color: AppTheme.black,
                    ),
                  ),
                ),
              );
            }),
            if (remainingCount > 0)
              Text(
                '+$remainingCount meer',
                style: const TextStyle(
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
                        onAdded: _loadCollection,
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

                          _loadCollection();
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
                          _loadCollection();
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
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.black,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(LucideIcons.x, color: AppTheme.black),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
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
  const _GridCoverCard({required this.group, required this.onTap});

  final List<CollectionItem> group;
  final void Function(CollectionItem item) onTap;

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
      child: const Center(
        child: Icon(LucideIcons.gamepad2, color: AppTheme.black, size: 28),
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

    return GestureDetector(
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
                      begin: isIncoming ? Offset(dir, 0.0) : Offset(-dir, 0.0),
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
                      Text(
                        platformName.isNotEmpty ? platformName : '?',
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.orange700,
                          height: 1.4,
                        ),
                      ),
                    ],
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
                        color: AppTheme.white,
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
                                Future.delayed(const Duration(seconds: 4), () {
                                  if (mounted) _startCycleIfNeeded();
                                });
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
    );
  }
}
