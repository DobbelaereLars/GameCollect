import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/database/database_helper.dart';
import '../domain/collection_item.dart';
import 'collection_item_detail_page.dart';
import '../../discover/presentation/widgets/discover_search_bar.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  final TextEditingController _searchController = TextEditingController();
  List<CollectionItem> _allItems = [];
  List<CollectionItem> _filteredItems = [];
  bool _isLoading = true;

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
  }

  @override
  void dispose() {
    _searchController.dispose();
    DatabaseHelper.instance.removeListener(_loadCollection);
    super.dispose();
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
                            const SizedBox(width: 12),
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
                  child: item.coverUrl != null
                      ? Image.network(
                          item.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
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
                      LinearProgressIndicator(
                        value: item.progressRatio,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(999),
                        backgroundColor: AppTheme.orange100,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.orange500,
                        ),
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

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                    Navigator.of(context).pop();
                    if (item.id != null) {
                      final updatedPlatforms = List<String>.from(
                        item.selectedPlatforms,
                      )..remove(specificPlatformWithFormat);

                      if (updatedPlatforms.isEmpty) {
                        await DatabaseHelper.instance.deleteCollectionItem(
                          item.id!,
                        );
                      } else {
                        // Create updated item with the platform removed
                        final updatedItem = item.copyWith(
                          selectedPlatforms: updatedPlatforms,
                        );
                        await DatabaseHelper.instance.updateCollectionItem(
                          updatedItem,
                        );
                      }

                      _loadCollection();
                      if (mounted) {
                        messenger
                          ..removeCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(
                                'Verwijderd van $specificPlatform.',
                              ),
                            ),
                          );
                      }
                    }
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
                      Navigator.of(context).pop();
                      await DatabaseHelper.instance
                          .deleteCollectionItemsByApiId(item.apiId);
                      _loadCollection();
                      if (mounted) {
                        messenger
                          ..removeCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Game volledig verwijderd uit collectie.',
                              ),
                            ),
                          );
                      }
                    },
                  ),
                // Padding reduced to match other panels
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
