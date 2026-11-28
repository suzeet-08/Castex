import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const String kRemoteConfigUrl =
    'https://raw.githubusercontent.com/suzeet-08/Castex/refs/heads/main/config/remote.json';

void main() {
  runApp(const CastexApp());
}

class CastexApp extends StatelessWidget {
  const CastexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Castex',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
        canvasColor: const Color(0xFF000000),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFFFFF),
          secondary: Color(0xFFE50914),
          surface: Color(0xFF0E0E11),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const CastexHomeShell(),
    );
  }
}

class CastexHomeShell extends StatefulWidget {
  const CastexHomeShell({super.key});

  @override
  State createState() => _CastexHomeShellState();
}

class _CastexHomeShellState extends State<CastexHomeShell> {
  int _tabIndex = 0;
  int _heroPage = 0;
  bool _fanMode = true;
  bool _loading = true;
  bool _hasUnreadNotice = true;

  Map _remoteConfig = {};
  List _pluginUrls = [];
  List _loadedPlugins = [];
  List _fandubRoutes = [];
  List _movies = [];
  List _series = [];
  String _kotosubUrl = '';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initCastex();
  }

  Future _initCastex() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    _fanMode = prefs.getBool('fan_mode') ?? true;
    _kotosubUrl = prefs.getString('kotosub_url') ?? '';
    _pluginUrls = List.from(prefs.getStringList('plugin_urls') ?? []);

    await _fetchRemoteConfig(prefs);
    await _loadAllPlugins();
    await _fetchDefaultCatalogs();

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future _fetchRemoteConfig(SharedPreferences prefs) async {
    try {
      final res = await http
          .get(Uri.parse(kRemoteConfigUrl))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map) {
          _remoteConfig = data;
          final rawDefaults = data['default_catalogs'];
          if (rawDefaults is List) {
            for (final item in rawDefaults) {
              final url = item.toString();
              if (url.isNotEmpty && !_pluginUrls.contains(url)) {
                _pluginUrls.add(url);
              }
            }
          }
          await prefs.setStringList(
            'plugin_urls',
            _pluginUrls.map((e) => e.toString()).toList(),
          );

          final ann = data['announcement'];
          if (ann is Map) {
            final annId = (ann['id'] ?? '').toString();
            final seenId = prefs.getString('seen_ann_id') ?? '';
            _hasUnreadNotice = annId.isNotEmpty && annId != seenId;
          }
        }
      }
    } catch (_) {}
  }

  Future _loadAllPlugins() async {
    final loaded = [];
    final routes = [];

    for (final rawUrl in _pluginUrls) {
      final url = rawUrl.toString();
      try {
        final res = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final parsed = jsonDecode(res.body);
          if (parsed is Map) {
            loaded.add({'url': url, 'data': parsed});
            final rawRoutes = parsed['hybrid_dub_routes'];
            if (rawRoutes is List) {
              for (final item in rawRoutes) {
                if (item is Map) {
                  routes.add(item);
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    _loadedPlugins = loaded;
    _fandubRoutes = routes;
  }

  Future _fetchDefaultCatalogs() async {
    try {
      final mRes = await http
          .get(Uri.parse('https://v3-cinemeta.strem.io/catalog/movie/top.json'))
          .timeout(const Duration(seconds: 8));
      if (mRes.statusCode == 200) {
        final body = jsonDecode(mRes.body);
        if (body is Map && body['metas'] is List) {
          _movies = (body['metas'] as List).take(24).toList();
        }
      }
    } catch (_) {}

    try {
      final sRes = await http
          .get(Uri.parse('https://v3-cinemeta.strem.io/catalog/series/top.json'))
          .timeout(const Duration(seconds: 8));
      if (sRes.statusCode == 200) {
        final body = jsonDecode(sRes.body);
        if (body is Map && body['metas'] is List) {
          _series = (body['metas'] as List).take(24).toList();
        }
      }
    } catch (_) {}
  }

  Future _toggleMode(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fan_mode', val);
    setState(() => _fanMode = val);
  }

  Future _addPluginUrl(String rawUrl) async {
    final clean = rawUrl.trim();
    if (!clean.startsWith('http')) return;
    if (!_pluginUrls.contains(clean)) {
      final prefs = await SharedPreferences.getInstance();
      _pluginUrls.add(clean);
      await prefs.setStringList(
        'plugin_urls',
        _pluginUrls.map((e) => e.toString()).toList(),
      );
      await _loadAllPlugins();
      if (mounted) setState(() {});
    }
  }

  Future _removePluginUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    _pluginUrls.remove(url);
    await prefs.setStringList(
      'plugin_urls',
      _pluginUrls.map((e) => e.toString()).toList(),
    );
    await _loadAllPlugins();
    if (mounted) setState(() {});
  }

  void _showNotificationDialog() async {
    final ann = _remoteConfig['announcement'];
    final prefs = await SharedPreferences.getInstance();
    if (ann is Map && ann['id'] != null) {
      await prefs.setString('seen_ann_id', ann['id'].toString());
    }
    if (!mounted) return;
    setState(() => _hasUnreadNotice = false);

    final titleText = (ann is Map && ann['title'] != null)
        ? ann['title'].toString()
        : 'What\'s New in Castex';
    final msgText = (ann is Map && ann['message'] != null)
        ? ann['message'].toString()
        : 'No new updates right now.';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121216),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Colors.white12),
        ),
        title: Text(
          titleText,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: Text(
          msgText,
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Got it',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _openDetailSheet(Map item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B0B0E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MediaDetailSheet(
        item: item,
        fanMode: _fanMode,
        fandubRoutes: _fandubRoutes,
        pluginUrls: _pluginUrls,
        kotosubUrl: _kotosubUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: _tabIndex == 0,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xCC000000),
                Color(0x00000000),
              ],
            ),
          ),
        ),
        title: Row(
          children: [
            const Text(
              'Castex',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFFE50914),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () => _toggleMode(!_fanMode),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Icon(
                    _fanMode ? Icons.auto_awesome_rounded : Icons.tv_rounded,
                    size: 13,
                    color: _fanMode ? const Color(0xFFF5C518) : Colors.white70,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _fanMode ? 'Fan Mode' : 'Simple',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.search_rounded, size: 22),
            onPressed: () => setState(() => _tabIndex = 1),
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, size: 22),
                onPressed: _showNotificationDialog,
              ),
              if (_hasUnreadNotice)
                Positioned(
                  right: 11,
                  top: 11,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE50914),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.2,
              ),
            )
          : IndexedStack(
              index: _tabIndex,
              children: [
                _buildHomeTab(),
                _buildSearchTab(),
                _buildPluginsTab(),
                _buildProfileTab(),
              ],
            ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF050507),
          border: Border(top: BorderSide(color: Colors.white10, width: 0.6)),
        ),
        child: BottomNavigationBar(
          currentIndex: _tabIndex,
          onTap: (i) => setState(() => _tabIndex = i),
          backgroundColor: const Color(0xFF050507),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white38,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_rounded),
              activeIcon: Icon(Icons.search_rounded),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.extension_outlined),
              activeIcon: Icon(Icons.extension_rounded),
              label: 'Addons',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    final heroItems = _movies.take(5).toList();
    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: const Color(0xFF141418),
      onRefresh: _initCastex,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (heroItems.isNotEmpty) _buildHeroSpotlight(heroItems),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_fanMode && _fandubRoutes.isNotEmpty) ...[
                  const Text(
                    'Community Fandubs',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 82,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _fandubRoutes.length,
                      itemBuilder: (ctx, i) {
                        final rawR = _fandubRoutes[i];
                        final r = rawR is Map ? rawR : {};
                        return GestureDetector(
                          onTap: () async {
                            final u = Uri.tryParse((r['external_url'] ?? '').toString());
                            if (u != null) {
                              await launchUrl(u, mode: LaunchMode.externalApplication);
                            }
                          },
                          child: Container(
                            width: 230,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111115),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  (r['title'] ?? 'Fandub').toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${r['dub_language']} • ${r['creator_name']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white60,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
                _buildPosterSection('Trending Movies', _movies),
                const SizedBox(height: 24),
                _buildPosterSection('Top Series & Anime', _series),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSpotlight(List heroItems) {
    return SizedBox(
      height: 430,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: heroItems.length,
            onPageChanged: (idx) => setState(() => _heroPage = idx),
            itemBuilder: (ctx, idx) {
              final raw = heroItems[idx];
              final item = raw is Map ? raw : {};
              final id = (item['id'] ?? '').toString();
              final poster = (item['poster'] ?? '').toString();
              final backdrop = id.startsWith('tt')
                  ? 'https://images.metahub.space/background/medium/$id/img'
                  : poster;
              final title = (item['name'] ?? 'Featured').toString();
              final rating = (item['imdbRating'] ?? '').toString();
              final year = (item['releaseInfo'] ?? '').toString();

              return Stack(
                fit: StackFit.expand,
                children: [
                  if (backdrop.isNotEmpty)
                    Image.network(
                      backdrop,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => poster.isNotEmpty
                          ? Image.network(poster, fit: BoxFit.cover)
                          : Container(color: const Color(0xFF101014)),
                    )
                  else
                    Container(color: const Color(0xFF101014)),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 0.35, 0.78, 1.0],
                        colors: [
                          Color(0x99000000),
                          Color(0x11000000),
                          Color(0xDD000000),
                          Color(0xFF000000),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (rating.isNotEmpty) ...[
                              const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFF5C518),
                                size: 15,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                rating,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFF5C518),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            if (year.isNotEmpty)
                              Text(
                                year,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                'HD • KotoSub',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 11,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              onPressed: () => _openDetailSheet(item),
                              icon: const Icon(Icons.play_arrow_rounded, size: 22),
                              label: const Text(
                                'Watch Now',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.white10,
                                side: const BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 11,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              onPressed: () => _openDetailSheet(item),
                              icon: const Icon(Icons.info_outline_rounded, size: 19),
                              label: const Text(
                                'Details',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          Positioned(
            bottom: 6,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                heroItems.length,
                (i) => Container(
                  width: _heroPage == i ? 16 : 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: _heroPage == i ? Colors.white : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosterSection(String title, List items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const Text(
            'Pull down to load catalog.',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          )
        else
          SizedBox(
            height: 222,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final rawItem = items[i];
                final item = rawItem is Map ? rawItem : {};
                return _buildPosterCard(item);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildPosterCard(Map item, {double width = 128}) {
    final poster = (item['poster'] ?? '').toString();
    final rating = (item['imdbRating'] ?? '').toString();

    return GestureDetector(
      onTap: () => _openDetailSheet(item),
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: const Color(0xFF121216),
                      width: double.infinity,
                      height: double.infinity,
                      child: poster.isNotEmpty
                          ? Image.network(
                              poster,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.movie_outlined,
                                color: Colors.white24,
                              ),
                            )
                          : const Icon(Icons.movie_outlined, color: Colors.white24),
                    ),
                  ),
                  if (rating.isNotEmpty)
                    Positioned(
                      top: 7,
                      right: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xCC000000),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFF5C518),
                              size: 11,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              rating,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Text(
              (item['name'] ?? 'Untitled').toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTab() {
    final q = _searchQuery.toLowerCase();
    final combined = [..._movies, ..._series];
    final filtered = q.isEmpty
        ? combined
        : combined
            .where((item) =>
                (item is Map ? (item['name'] ?? '') : '')
                    .toString()
                    .toLowerCase()
                    .contains(q))
            .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Column(
          children: [
            TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search movies, shows, anime...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 14.5),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF121216),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.white10),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.white10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                itemCount: filtered.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.58,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 14,
                ),
                itemBuilder: (ctx, i) {
                  final raw = filtered[i];
                  final item = raw is Map ? raw : {};
                  return _buildPosterCard(item, width: double.infinity);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPluginsTab() {
    final controller = TextEditingController();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Addons & Extensions',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Install Stremio manifest URLs or Castex community JSON packs.',
            style: TextStyle(color: Colors.white54, fontSize: 13.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'https://.../manifest.json',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF121216),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  _addPluginUrl(controller.text);
                  controller.clear();
                },
                child: const Text('Install', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Active Addons (${_pluginUrls.length})',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 12),
          ..._pluginUrls.map((rawU) {
            final u = rawU.toString();
            final match = _loadedPlugins.where((p) => p is Map && p['url'] == u).toList();
            String name = 'Stremio / Remote JSON Addon';
            if (match.isNotEmpty) {
              final d = (match.first as Map)['data'];
              if (d is Map && d['name'] != null) {
                name = d['name'].toString();
              }
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF101014),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          u,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: Colors.white38),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.white54),
                    onPressed: () => _removePluginUrl(u),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    final rawLinks = _remoteConfig['community_links'];
    final links = rawLinks is Map ? rawLinks : {};
    final kotoCtrl = TextEditingController(text: _kotosubUrl);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Profile & Settings',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF101014),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Anime & Fan Mode',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Show community fandubs, lore & extra tools',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
              value: _fanMode,
              activeColor: Colors.white,
              onChanged: _toggleMode,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'KotoSub AI Engine',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Connect your Render KotoSub server for Hinglish & Bangla subtitles.',
            style: TextStyle(color: Colors.white54, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: kotoCtrl,
                  decoration: InputDecoration(
                    hintText: 'https://your-kotosub.onrender.com',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF121216),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('kotosub_url', kotoCtrl.text.trim());
                  setState(() => _kotosubUrl = kotoCtrl.text.trim());
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('KotoSub server saved')),
                    );
                  }
                },
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Community & Source',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _linkTile('GitHub Open-Source (GPLv3)', (links['github'] ?? '').toString()),
          _linkTile('Discord Community', (links['discord'] ?? '').toString()),
          _linkTile('Instagram Updates', (links['instagram'] ?? '').toString()),
          _linkTile('Official Website', (links['website'] ?? '').toString()),
          const SizedBox(height: 22),
          const Text(
            'Castex v1.0.0 • Ad-Free & Open-Source\nCastex does not host or distribute any media files.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white30, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _linkTile(String label, String url) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF101014),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        title: Text(label, style: const TextStyle(fontSize: 14)),
        trailing: const Icon(Icons.open_in_new_rounded, size: 18, color: Colors.white54),
        onTap: () async {
          final u = Uri.tryParse(url);
          if (u != null && url.startsWith('http')) {
            await launchUrl(u, mode: LaunchMode.externalApplication);
          }
        },
      ),
    );
  }
}

class MediaDetailSheet extends StatefulWidget {
  final Map item;
  final bool fanMode;
  final List fandubRoutes;
  final List pluginUrls;
  final String kotosubUrl;

  const MediaDetailSheet({
    super.key,
    required this.item,
    required this.fanMode,
    required this.fandubRoutes,
    required this.pluginUrls,
    required this.kotosubUrl,
  });

  @override
  State createState() => _MediaDetailSheetState();
}

class _MediaDetailSheetState extends State<MediaDetailSheet> {
  String _selectedDubLayer = 'Original Audio';
  String _selectedSubLang = 'Hinglish';
  List _streams = [];
  bool _fetchingStreams = false;

  @override
  void initState() {
    super.initState();
    _resolveAddonStreams();
  }

  Future _resolveAddonStreams() async {
    final id = (widget.item['id'] ?? '').toString();
    final type = (widget.item['type'] ?? 'movie').toString();
    if (id.isEmpty) return;

    setState(() => _fetchingStreams = true);
    final found = [];

    for (final rawUrl in widget.pluginUrls) {
      final pUrl = rawUrl.toString();
      if (pUrl.endsWith('/manifest.json')) {
        final base = pUrl.substring(0, pUrl.length - '/manifest.json'.length);
        final streamApi = type == 'movie'
            ? '$base/stream/movie/$id.json'
            : '$base/stream/series/$id:1:1.json';
        try {
          final res = await http
              .get(Uri.parse(streamApi))
              .timeout(const Duration(seconds: 7));
          if (res.statusCode == 200) {
            final decoded = jsonDecode(res.body);
            if (decoded is Map && decoded['streams'] is List) {
              for (final s in (decoded['streams'] as List).take(8)) {
                if (s is Map && s['url'] != null) {
                  found.add(s);
                }
              }
            }
          }
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() {
        _streams = found;
        _fetchingStreams = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.item['name'] ?? 'Unknown').toString();
    final desc = (widget.item['description'] ?? 'No synopsis available.').toString();
    final rating = (widget.item['imdbRating'] ?? '').toString();
    final year = (widget.item['releaseInfo'] ?? '').toString();

    final dubOptions = [
      'Original Audio',
      'Official Dub',
      if (widget.fanMode) 'Community Fandub',
    ];
    final subOptions = [
      'Off',
      'Hinglish',
      'Bangla',
      'Banglish',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (rating.isNotEmpty) ...[
                  const Icon(Icons.star_rounded, color: Color(0xFFF5C518), size: 15),
                  const SizedBox(width: 4),
                  Text(
                    rating,
                    style: const TextStyle(
                      color: Color(0xFFF5C518),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (year.isNotEmpty)
                  Text(
                    year,
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              desc,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Audio & Dub Track',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: dubOptions
                  .map(
                    (d) => ChoiceChip(
                      label: Text(
                        d,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _selectedDubLayer == d ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      selected: _selectedDubLayer == d,
                      selectedColor: Colors.white,
                      backgroundColor: const Color(0xFF141418),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: Colors.white12),
                      ),
                      onSelected: (_) => setState(() => _selectedDubLayer = d),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            const Text(
              'KotoSub AI Subtitles',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: subOptions
                  .map(
                    (s) => ChoiceChip(
                      label: Text(
                        s,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _selectedSubLang == s ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      selected: _selectedSubLang == s,
                      selectedColor: Colors.white,
                      backgroundColor: const Color(0xFF141418),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: Colors.white12),
                      ),
                      onSelected: (_) => setState(() => _selectedSubLang = s),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            const Text(
              'Streams',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            if (_fetchingStreams)
              const LinearProgressIndicator(color: Colors.white)
            else if (_streams.isEmpty)
              const Text(
                'Install a Stremio stream addon in the Addons tab to load playback links.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              )
            else
              ..._streams.map((rawSt) {
                final st = rawSt is Map ? rawSt : {};
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121216),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ListTile(
                    title: Text(
                      (st['title'] ?? st['name'] ?? 'Stream').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5),
                    ),
                    trailing: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                    onTap: () async {
                      final u = Uri.tryParse((st['url'] ?? '').toString());
                      if (u != null) {
                        await launchUrl(u, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
