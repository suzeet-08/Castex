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
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF7C4DFF),
          surface: Color(0xFF0C0C0E),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF000000),
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
        : 'Castex Updates';
    final msgText = (ann is Map && ann['message'] != null)
        ? ann['message'].toString()
        : 'No new announcements right now. Enjoy ad-free streaming!';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF101014),
        title: Text(
          titleText,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          msgText,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _openDetailSheet(Map item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A0A0D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF00E5FF), width: 1),
              ),
              child: const Text(
                'CASTEX',
                style: TextStyle(
                  color: Color(0xFF00E5FF),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _fanMode ? 'FAN' : 'SIMPLE',
              style: TextStyle(
                fontSize: 11,
                color: _fanMode ? const Color(0xFF7C4DFF) : Colors.white54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              const Text('Fan', style: TextStyle(fontSize: 12, color: Colors.white70)),
              Switch(
                value: _fanMode,
                onChanged: _toggleMode,
                activeColor: const Color(0xFF00E5FF),
              ),
            ],
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: _showNotificationDialog,
              ),
              if (_hasUnreadNotice)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00E5FF),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
            )
          : IndexedStack(
              index: _tabIndex,
              children: [
                _buildHomeTab(),
                _buildPluginsTab(),
                _buildCommunityTab(),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF070709),
        indicatorColor: const Color(0xFF00E5FF).withOpacity(0.18),
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle_fill, color: Color(0xFF00E5FF)),
            label: 'Stream',
          ),
          NavigationDestination(
            icon: Icon(Icons.extension_outlined),
            selectedIcon: Icon(Icons.extension, color: Color(0xFF00E5FF)),
            label: 'Plugins',
          ),
          NavigationDestination(
            icon: Icon(Icons.hub_outlined),
            selectedIcon: Icon(Icons.hub, color: Color(0xFF00E5FF)),
            label: 'HQ & Sync',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    final q = _searchQuery.toLowerCase();
    final filteredMovies = q.isEmpty
        ? _movies
        : _movies
            .where((m) => (m is Map ? (m['name'] ?? '') : '').toString().toLowerCase().contains(q))
            .toList();
    final filteredSeries = q.isEmpty
        ? _series
        : _series
            .where((s) => (s is Map ? (s['name'] ?? '') : '').toString().toLowerCase().contains(q))
            .toList();

    return RefreshIndicator(
      color: const Color(0xFF00E5FF),
      onRefresh: _initCastex,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search movies, series or anime...',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF0E0E12),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (_fanMode && _fandubRoutes.isNotEmpty) ...[
            const Text(
              'Verified Community Fandubs',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 92,
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
                      width: 220,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF101016),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF7C4DFF).withOpacity(0.45),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            (r['title'] ?? 'Fandub').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${r['dub_language']} • by ${r['creator_name']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF00E5FF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
          ],
          _buildPosterSection('Popular Movies', filteredMovies),
          const SizedBox(height: 20),
          _buildPosterSection('Top Series & Anime', filteredSeries),
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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          const Text(
            'No items found. Pull down to refresh.',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          )
        else
          SizedBox(
            height: 205,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final rawItem = items[i];
                final item = rawItem is Map ? rawItem : {};
                final poster = (item['poster'] ?? '').toString();
                return GestureDetector(
                  onTap: () => _openDetailSheet(item),
                  child: Container(
                    width: 122,
                    margin: const EdgeInsets.only(right: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              color: const Color(0xFF121216),
                              width: double.infinity,
                              child: poster.isNotEmpty
                                  ? Image.network(
                                      poster,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.movie_outlined,
                                        color: Colors.white24,
                                      ),
                                    )
                                  : const Icon(Icons.movie_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          (item['name'] ?? 'Untitled').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildPluginsTab() {
    final controller = TextEditingController();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'URL / JSON Plugin Manager',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Paste any Stremio Addon URL (manifest.json) or Castex JSON catalog pack.',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'https://.../manifest.json',
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF0E0E12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              ),
              onPressed: () {
                _addPluginUrl(controller.text);
                controller.clear();
              },
              child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Installed Plugins (${_pluginUrls.length})',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 10),
        ..._pluginUrls.map((rawU) {
          final u = rawU.toString();
          final match = _loadedPlugins.where((p) => p is Map && p['url'] == u).toList();
          String name = 'Remote JSON / Addon';
          if (match.isNotEmpty) {
            final d = (match.first as Map)['data'];
            if (d is Map && d['name'] != null) {
              name = d['name'].toString();
            }
          }
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D11),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF00E5FF), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        u,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Colors.white38),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _removePluginUrl(u),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCommunityTab() {
    final rawLinks = _remoteConfig['community_links'];
    final links = rawLinks is Map ? rawLinks : {};
    final kotoCtrl = TextEditingController(text: _kotosubUrl);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'KotoSub AI Server URL',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Enter your Render KotoSub URL for 0.000s Hinglish & Bangla subtitles.',
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
                  fillColor: const Color(0xFF0E0E12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C4DFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              ),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('kotosub_url', kotoCtrl.text.trim());
                setState(() => _kotosubUrl = kotoCtrl.text.trim());
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('KotoSub server saved!')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Castex Official Channels',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        _linkTile('GitHub Repository (GPLv3)', (links['github'] ?? '').toString()),
        _linkTile('Discord Dev & Beta HQ', (links['discord'] ?? '').toString()),
        _linkTile('Public Instagram Updates', (links['instagram'] ?? '').toString()),
        _linkTile('Companion Website', (links['website'] ?? '').toString()),
        const SizedBox(height: 20),
        const Text(
          'Castex v1.0.0 • Open-Source & Ad-Free\nCastex does not host any media files.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white30, fontSize: 11.5),
        ),
      ],
    );
  }

  Widget _linkTile(String label, String url) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D11),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        title: Text(label, style: const TextStyle(fontSize: 14)),
        trailing: const Icon(Icons.open_in_new, size: 18, color: Color(0xFF00E5FF)),
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
  String _selectedSubLang = 'Hinglish (KotoSub AI)';
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
    final dubOptions = [
      'Original Audio',
      'Official Dub',
      if (widget.fanMode) 'Community Fandub',
    ];
    final subOptions = [
      'Off',
      'Hinglish (KotoSub AI)',
      'Bangla (KotoSub AI)',
      'Banglish (KotoSub AI)',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              desc,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text(
              'Hybrid Dub Router',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: dubOptions
                  .map(
                    (d) => ChoiceChip(
                      label: Text(d, style: const TextStyle(fontSize: 12)),
                      selected: _selectedDubLayer == d,
                      selectedColor: const Color(0xFF7C4DFF),
                      onSelected: (_) => setState(() => _selectedDubLayer = d),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
            const Text(
              'KotoSub AI Subtitles',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: subOptions
                  .map(
                    (s) => ChoiceChip(
                      label: Text(s, style: const TextStyle(fontSize: 12)),
                      selected: _selectedSubLang == s,
                      selectedColor: const Color(0xFF00E5FF).withOpacity(0.3),
                      onSelected: (_) => setState(() => _selectedSubLang = s),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 18),
            const Text(
              'Available Addon Streams',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            if (_fetchingStreams)
              const LinearProgressIndicator(color: Color(0xFF00E5FF))
            else if (_streams.isEmpty)
              const Text(
                'Add a Stremio stream addon in the Plugins tab to load direct streams.',
                style: TextStyle(color: Colors.white54, fontSize: 12.5),
              )
            else
              ..._streams.map((rawSt) {
                final st = rawSt is Map ? rawSt : {};
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121218),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    title: Text(
                      (st['title'] ?? st['name'] ?? 'Stream').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: const Icon(Icons.play_arrow_rounded, color: Color(0xFF00E5FF)),
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
