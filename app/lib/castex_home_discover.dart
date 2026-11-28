import 'dart:async';
import 'package:flutter/material.dart';

import 'castex_core.dart';
import 'castex_player.dart';

// ============================================================================
// CASTEX SIGNATURE STAGE HOME (DISTINCT FROM NUVIO)
// ============================================================================
class CastexStageHomeTab extends StatefulWidget {
  final CastexController controller;
  final void Function(double offset) onScroll;
  final void Function(Color aura) onAuraChanged;
  final VoidCallback onOpenDiscover;

  const CastexStageHomeTab({
    super.key,
    required this.controller,
    required this.onScroll,
    required this.onAuraChanged,
    required this.onOpenDiscover,
  });

  @override
  State<CastexStageHomeTab> createState() => _CastexStageHomeTabState();
}

class _CastexStageHomeTabState extends State<CastexStageHomeTab> {
  List<MediaItem> _items = CastexAddonEngine.starterShowcase;
  String _selectedFilter = 'All';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() => _loading = true);
    final list = await CastexAddonEngine.fetchCatalogAndSearch(
      enabledAddons: widget.controller.addons,
      genreFilter: _selectedFilter,
    );
    if (mounted) {
      setState(() {
        _items = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.controller.appearance;
    final continuing = _items
        .where((m) => (widget.controller.watchProgress[m.id] ?? 0) > 0)
        .toList();

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollUpdateNotification) widget.onScroll(n.metrics.pixels);
        return false;
      },
      child: RefreshIndicator(
        onRefresh: _loadFeed,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 105),
          children: [
            // Castex Kinetic Stage Carousel (Horizontal Card Deck)
            SizedBox(
              height: 225,
              child: PageView.builder(
                controller: PageController(viewportFraction: 0.94),
                itemCount: _items.take(5).length,
                onPageChanged: (idx) =>
                    widget.onAuraChanged(_items[idx].auraColor),
                itemBuilder: (context, idx) {
                  final item = _items[idx];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MediaDetailScreen(
                          controller: widget.controller,
                          item: item,
                        ),
                      ),
                    ),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: app.cardColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 144,
                              height: double.infinity,
                              child: Image.network(
                                item.posterUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.white10,
                                  child: const Icon(Icons.movie_rounded,
                                      size: 40),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: app.accentColor
                                                    .withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                              child: Text(
                                                'KOTOSUB • ${app.defaultSubLang.toUpperCase()}',
                                                style: TextStyle(
                                                  color: app.accentColor,
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 16.5,
                                            fontWeight: FontWeight.w800,
                                            height: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          '★ ${item.rating} • ${item.year} • ${item.type.toUpperCase()}',
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    MediaDetailScreen(
                                                  controller: widget.controller,
                                                  item: item,
                                                ),
                                              ),
                                            ),
                                            icon: const Icon(
                                                Icons.play_arrow_rounded,
                                                size: 18),
                                            label: const Text('Stream',
                                                style: TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: app.accentColor,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        IconButton(
                                          icon: Icon(
                                            widget.controller.watchlistIds
                                                    .contains(item.id)
                                                ? Icons.bookmark_rounded
                                                : Icons.bookmark_border_rounded,
                                          ),
                                          onPressed: () {
                                            widget.controller
                                                .toggleWatchlist(item.id);
                                            setState(() {});
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Interactive Genre & Hub Filter Bar (Actually filters live feed!)
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: ['All', 'Action', 'Anime', 'Sci-Fi', 'Adventure', 'Drama']
                    .map((filter) {
                  final active = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter, style: const TextStyle(fontSize: 12)),
                      selected: active,
                      selectedColor: app.accentColor,
                      onSelected: (_) {
                        setState(() => _selectedFilter = filter);
                        _loadFeed();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: LinearProgressIndicator(minHeight: 2),
              ),

            if (continuing.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Continue Watching',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ...continuing.take(2).map((item) {
                final pct = widget.controller.watchProgress[item.id] ?? 0.0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    tileColor: app.cardColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.posterUrl,
                        width: 42,
                        height: 58,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.movie_rounded),
                      ),
                    ),
                    title: Text(item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: LinearProgressIndicator(
                      value: pct,
                      minHeight: 3,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation(app.accentColor),
                    ),
                    trailing: Icon(Icons.play_circle_fill_rounded,
                        color: app.accentColor),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MediaDetailScreen(
                          controller: widget.controller,
                          item: item,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedFilter == 'All'
                      ? 'Addon Catalog Feed'
                      : '$_selectedFilter Catalog',
                  style: const TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w800),
                ),
                TextButton(
                  onPressed: widget.onOpenDiscover,
                  child: const Text('Search All →',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.67,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, idx) {
                final item = _items[idx];
                return RepaintBoundary(
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MediaDetailScreen(
                          controller: widget.controller,
                          item: item,
                        ),
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: app.cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(14)),
                              child: Image.network(
                                item.posterUrl,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.white10,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.movie_filter_rounded,
                                      size: 36),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '★ ${item.rating} • ${item.year}',
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 10.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// LIVE ADDON SEARCH TAB (SEARCHES CINEMETA + ALL INSTALLED STREMIO ADDONS)
// ============================================================================
class LiveSearchTab extends StatefulWidget {
  final CastexController controller;
  const LiveSearchTab({super.key, required this.controller});

  @override
  State<LiveSearchTab> createState() => _LiveSearchTabState();
}

class _LiveSearchTabState extends State<LiveSearchTab> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _typeFilter = 'all';
  bool _searching = false;
  List<MediaItem> _results = CastexAddonEngine.starterShowcase;

  @override
  void initState() {
    super.initState();
    _runSearch('');
  }

  void _onQueryChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _runSearch(val);
    });
  }

  Future<void> _runSearch(String query) async {
    setState(() => _searching = true);
    final items = await CastexAddonEngine.fetchCatalogAndSearch(
      enabledAddons: widget.controller.addons,
      query: query,
      typeFilter: _typeFilter,
    );
    if (mounted) {
      setState(() {
        _results = items;
        _searching = false;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.controller.appearance;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 105),
      children: [
        TextField(
          controller: _searchCtrl,
          onChanged: _onQueryChanged,
          onSubmitted: _runSearch,
          decoration: InputDecoration(
            hintText: 'Search Spider-Man, anime, movies across addons...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchCtrl.clear();
                      _runSearch('');
                    },
                  )
                : null,
            filled: true,
            fillColor: app.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _typeChip('all', 'All', app),
            const SizedBox(width: 8),
            _typeChip('movie', 'Movies', app),
            const SizedBox(width: 8),
            _typeChip('series', 'Series & Anime', app),
          ],
        ),
        const SizedBox(height: 10),
        if (_searching) const LinearProgressIndicator(minHeight: 2),
        const SizedBox(height: 8),
        if (_results.isEmpty && !_searching)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No titles matched. Try another keyword or check Addons in Me tab.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
          )
        else
          ..._results.map(
            (item) => ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 5),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item.posterUrl,
                  width: 48,
                  height: 68,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.movie_rounded, size: 34),
                ),
              ),
              title: Text(item.title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                '${item.type.toUpperCase()} • ${item.year} • ★ ${item.rating}',
                style: const TextStyle(color: Colors.white54, fontSize: 11.5),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MediaDetailScreen(
                    controller: widget.controller,
                    item: item,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _typeChip(String value, String label, CastexAppearance app) {
    final active = _typeFilter == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: active,
      selectedColor: app.accentColor,
      onSelected: (_) {
        setState(() => _typeFilter = value);
        _runSearch(_searchCtrl.text);
      },
    );
  }
}

// ============================================================================
// MEDIA DETAIL SCREEN (LIVE EPISODE & STREAM RESOLVER)
// ============================================================================
class MediaDetailScreen extends StatefulWidget {
  final CastexController controller;
  final MediaItem item;

  const MediaDetailScreen({
    super.key,
    required this.controller,
    required this.item,
  });

  @override
  State<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends State<MediaDetailScreen> {
  late MediaItem _fullItem;
  bool _loadingMeta = true;
  String _dubFilter = 'All';

  @override
  void initState() {
    super.initState();
    _fullItem = widget.item;
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    final updated = await CastexAddonEngine.fetchFullMeta(
      enabledAddons: widget.controller.addons,
      item: widget.item,
    );
    if (mounted) {
      setState(() {
        _fullItem = updated;
        _loadingMeta = false;
      });
    }
  }

  void _openCustomUrlDialog(EpisodeItem ep) {
    final urlCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Direct Stream / M3U8 / MP4 URL'),
        content: TextField(
          controller: urlCtrl,
          decoration: const InputDecoration(
            hintText: 'https://... (.mp4, .m3u8, direct stream)',
            filled: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final raw = urlCtrl.text.trim();
              if (!raw.startsWith('http')) return;
              Navigator.pop(ctx);
              final customStream = StreamSource(
                id: 'custom_url',
                title: 'Custom Direct Stream',
                quality: 'HD',
                dubLayer: 'Original Audio',
                language: 'Direct + KotoSub',
                provider: 'Custom URL',
                url: raw,
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CastexCinemaPlayerScreen(
                    controller: widget.controller,
                    item: _fullItem,
                    episode: ep,
                    stream: customStream,
                    playlist: [customStream],
                  ),
                ),
              );
            },
            child: const Text('Play Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _openStreamPicker(EpisodeItem ep) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final streams = await CastexAddonEngine.resolveAddonStreams(
      enabledAddons: widget.controller.addons,
      item: _fullItem,
      episode: ep,
    );

    if (!mounted) return;
    Navigator.pop(context); // Close loader

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1016),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final list = streams.where((s) {
            return _dubFilter == 'All' || s.dubLayer == _dubFilter;
          }).toList();

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Streams • ${ep.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openCustomUrlDialog(ep);
                      },
                      icon: const Icon(Icons.link_rounded, size: 16),
                      label: const Text('Paste URL',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    'All',
                    'Original Audio',
                    'Official Dub',
                    'Community Fandub',
                  ].map((layer) {
                    return ChoiceChip(
                      label: Text(layer, style: const TextStyle(fontSize: 11)),
                      selected: _dubFilter == layer,
                      onSelected: (_) => setModal(() => _dubFilter = layer),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: list.length,
                    itemBuilder: (_, idx) {
                      final s = list[idx];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: widget
                              .controller.appearance.accentColor
                              .withOpacity(0.2),
                          child: Text(
                            s.quality,
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(s.title,
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${s.dubLayer} • ${s.language} • ${s.provider}',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        trailing: Icon(
                          s.isDirectPlayable
                              ? Icons.play_circle_fill_rounded
                              : Icons.open_in_new_rounded,
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CastexCinemaPlayerScreen(
                                controller: widget.controller,
                                item: _fullItem,
                                episode: ep,
                                stream: s,
                                playlist: list
                                    .where((x) => x.isDirectPlayable)
                                    .toList(),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.controller.appearance;
    final item = _fullItem;
    final pct = widget.controller.watchProgress[item.id] ?? 0.0;

    return Scaffold(
      backgroundColor: app.bgColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 230,
            pinned: true,
            backgroundColor: app.bgColor,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.bold)),
              background: Image.network(
                item.backdropUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: const Color(0xFF141822)),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    Chip(label: Text('★ ${item.rating}')),
                    const SizedBox(width: 8),
                    Chip(label: Text(item.year)),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        widget.controller.watchlistIds.contains(item.id)
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: app.accentColor,
                      ),
                      onPressed: () {
                        widget.controller.toggleWatchlist(item.id);
                        setState(() {});
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        widget.controller.offlinePocketIds.contains(item.id)
                            ? Icons.offline_pin_rounded
                            : Icons.download_for_offline_outlined,
                        color: Colors.amberAccent,
                      ),
                      onPressed: () {
                        widget.controller.toggleOfflinePocket(item.id);
                        setState(() {});
                      },
                    ),
                  ],
                ),
                if (_loadingMeta)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                const SizedBox(height: 8),
                Text(item.overview,
                    style: const TextStyle(color: Colors.white70, height: 1.4)),
                if (widget.controller.effectiveFanMode) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: app.cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('KotoSub AI Context',
                            style: TextStyle(
                                color: app.accentColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(item.aiRecap,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text('Episodes & Streams',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                ...item.episodes.map((ep) {
                  final hideSpoiler =
                      app.spoilerShield && ep.number > 1 && pct < 0.80;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: app.cardColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          ep.thumbnailUrl,
                          width: 72,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.play_arrow_rounded),
                        ),
                      ),
                      title: Text(
                        hideSpoiler
                            ? 'Episode ${ep.number} (Spoiler Shielded)'
                            : 'S${ep.season}:E${ep.number} • ${ep.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text(
                        hideSpoiler ? 'Hidden until watched' : ep.synopsis,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      trailing: Icon(Icons.play_circle_fill_rounded,
                          color: app.accentColor, size: 30),
                      onTap: () => _openStreamPicker(ep),
                    ),
                  );
                }),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
