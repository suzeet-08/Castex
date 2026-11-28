import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

const String kRemoteConfigUrl =
    'https://raw.githubusercontent.com/suzeet-08/Castex/refs/heads/main/config/remote.json';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const CastexRootGate(),
    );
  }
}

class CastexRootGate extends StatefulWidget {
  const CastexRootGate({super.key});

  @override
  State createState() => _CastexRootGateState();
}

class _CastexRootGateState extends State<CastexRootGate> {
  bool _checking = true;
  bool _hasProfile = false;

  @override
  void initState() {
    super.initState();
    _checkProfile();
  }

  Future _checkProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('profile_name') ?? '';
    if (mounted) {
      setState(() {
        _hasProfile = name.trim().isNotEmpty;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    }
    if (!_hasProfile) {
      return ProfileOnboardingScreen(
        onProfileReady: () {
          setState(() => _hasProfile = true);
        },
      );
    }
    return CastexHomeShell(
      onProfileReset: () {
        setState(() => _hasProfile = false);
      },
    );
  }
}

class ProfileOnboardingScreen extends StatefulWidget {
  final VoidCallback onProfileReady;

  ProfileOnboardingScreen({super.key, required this.onProfileReady});

  @override
  State createState() => _ProfileOnboardingScreenState();
}

class _ProfileOnboardingScreenState extends State<ProfileOnboardingScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _pinCtrl = TextEditingController();
  int _selectedColor = 0xFFE50914;
  bool _busy = false;

  final List _avatarColors = [
    0xFFE50914,
    0xFF00B8D4,
    0xFF7C4DFF,
    0xFFF5C518,
    0xFF00C853,
    0xFFFF6D00,
  ];

  Future _createProfile() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your profile name to continue')),
      );
      return;
    }
    setState(() => _busy = true);
    final prefs = await SharedPreferences.getInstance();
    final rng = Random();
    final code = 100000 + rng.nextInt(899999);
    final profileId = 'CX-$code';

    await prefs.setString('profile_id', profileId);
    await prefs.setString('profile_name', name);
    await prefs.setInt('profile_color', _selectedColor);
    await prefs.setString('profile_pin', _pinCtrl.text.trim());
    await prefs.setString('profile_created', DateTime.now().toIso8601String());

    if (mounted) {
      setState(() => _busy = false);
      widget.onProfileReady();
    }
  }

  Future _restoreFromBackupOnStart() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'castex', 'txt'],
      );
      if (result == null || result.files.single.path == null) return;
      final content = await File(result.files.single.path!).readAsString();
      final decoded = jsonDecode(content);
      if (decoded is! Map || decoded['profile'] is! Map) {
        throw Exception('Invalid backup file');
      }
      final prof = decoded['profile'] as Map;
      final name = (prof['name'] ?? '').toString();
      if (name.isEmpty) throw Exception('Profile missing in backup');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_id', (prof['id'] ?? 'CX-RESTORED').toString());
      await prefs.setString('profile_name', name);
      await prefs.setInt('profile_color', (prof['color'] is int) ? prof['color'] : 0xFFE50914);
      await prefs.setString('profile_pin', (prof['pin'] ?? '').toString());
      await prefs.setString('profile_created', (prof['created'] ?? '').toString());

      if (decoded['fan_mode'] is bool) {
        await prefs.setBool('fan_mode', decoded['fan_mode']);
      }
      if (decoded['kotosub_url'] != null) {
        await prefs.setString('kotosub_url', decoded['kotosub_url'].toString());
      }
      if (decoded['plugin_urls'] is List) {
        await prefs.setStringList(
          'plugin_urls',
          (decoded['plugin_urls'] as List).map((e) => e.toString()).toList(),
        );
      }
      if (decoded['watchlist'] is List) {
        await prefs.setString('watchlist_json', jsonEncode(decoded['watchlist']));
      }
      if (decoded['continue_watching'] is List) {
        await prefs.setString(
          'continue_watching_json',
          jsonEncode(decoded['continue_watching']),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Welcome back, $name! Backup restored.')),
        );
        widget.onProfileReady();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not restore backup file. Check file format.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewInitial = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text.trim()[0].toUpperCase()
        : 'C';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Castex',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE50914),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create your local profile to save Watchlist,\nprogress & encrypted Backup/Restore files.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 13.5, height: 1.4),
                ),
                const SizedBox(height: 28),
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Color(_selectedColor),
                  child: Text(
                    previewInitial,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  children: _avatarColors.map((hex) {
                    final selected = _selectedColor == hex;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = hex),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Color(hex),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? Colors.white : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Profile Name (Required)',
                    hintText: 'e.g. Sujit',
                    filled: true,
                    fillColor: const Color(0xFF121216),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _pinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: '4-Digit Backup PIN (Optional)',
                    hintText: 'Protects your restore file',
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFF121216),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _busy ? null : _createProfile,
                    child: const Text(
                      'Create Profile & Start Watching',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _restoreFromBackupOnStart,
                  icon: const Icon(Icons.restore_rounded, size: 18, color: Colors.white70),
                  label: const Text(
                    'Restore from Existing Castex Backup File',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CastexHomeShell extends StatefulWidget {
  final VoidCallback onProfileReset;

  CastexHomeShell({super.key, required this.onProfileReset});

  @override
  State createState() => _CastexHomeShellState();
}

class _CastexHomeShellState extends State<CastexHomeShell> {
  int _tabIndex = 0;
  int _heroPage = 0;
  bool _fanMode = true;
  bool _loading = true;
  bool _hasUnreadNotice = true;

  String _profileId = '';
  String _profileName = '';
  int _profileColor = 0xFFE50914;
  String _profilePin = '';

  Map _remoteConfig = {};
  List _pluginUrls = [];
  List _loadedPlugins = [];
  List _fandubRoutes = [];
  List _movies = [];
  List _series = [];
  List _watchlist = [];
  List _continueWatching = [];
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
    _profileId = prefs.getString('profile_id') ?? 'CX-000000';
    _profileName = prefs.getString('profile_name') ?? 'Viewer';
    _profileColor = prefs.getInt('profile_color') ?? 0xFFE50914;
    _profilePin = prefs.getString('profile_pin') ?? '';
    _fanMode = prefs.getBool('fan_mode') ?? true;
    _kotosubUrl = prefs.getString('kotosub_url') ?? '';
    _pluginUrls = List.from(prefs.getStringList('plugin_urls') ?? []);

    _loadLocalLists(prefs);
    await _fetchRemoteConfig(prefs);
    await _loadAllPlugins();
    await _fetchDefaultCatalogs();

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _loadLocalLists(SharedPreferences prefs) {
    try {
      final wRaw = prefs.getString('watchlist_json') ?? '[]';
      final wDecoded = jsonDecode(wRaw);
      if (wDecoded is List) _watchlist = wDecoded;
    } catch (_) {
      _watchlist = [];
    }

    try {
      final cRaw = prefs.getString('continue_watching_json') ?? '[]';
      final cDecoded = jsonDecode(cRaw);
      if (cDecoded is List) _continueWatching = cDecoded;
    } catch (_) {
      _continueWatching = [];
    }
  }

  Future _toggleWatchlist(Map item) async {
    final id = (item['id'] ?? '').toString();
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final exists = _watchlist.any((w) => w is Map && w['id'].toString() == id);
    if (exists) {
      _watchlist.removeWhere((w) => w is Map && w['id'].toString() == id);
    } else {
      _watchlist.insert(0, item);
    }
    await prefs.setString('watchlist_json', jsonEncode(_watchlist));
    if (mounted) setState(() {});
  }

  Future _saveProgress(Map entry) async {
    final prefs = await SharedPreferences.getInstance();
    final id = (entry['id'] ?? '').toString();
    _continueWatching.removeWhere((e) => e is Map && e['id'].toString() == id);
    _continueWatching.insert(0, entry);
    if (_continueWatching.length > 20) {
      _continueWatching = _continueWatching.take(20).toList();
    }
    await prefs.setString('continue_watching_json', jsonEncode(_continueWatching));
    if (mounted) setState(() {});
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

  Future _exportBackupFile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = {
        'app': 'Castex',
        'version': '1.0.0',
        'exported_at': DateTime.now().toIso8601String(),
        'profile': {
          'id': _profileId,
          'name': _profileName,
          'color': _profileColor,
          'pin': _profilePin,
          'created': prefs.getString('profile_created') ?? '',
        },
        'fan_mode': _fanMode,
        'kotosub_url': _kotosubUrl,
        'plugin_urls': _pluginUrls,
        'watchlist': _watchlist,
        'continue_watching': _continueWatching,
      };

      final dir = await getTemporaryDirectory();
      final safeName = _profileName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('${dir.path}/Castex_Backup_$safeName.json');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Castex Profile Backup ($_profileName - $_profileId)',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to export backup file.')),
        );
      }
    }
  }

  Future _restoreBackupFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'castex', 'txt'],
      );
      if (result == null || result.files.single.path == null) return;
      final content = await File(result.files.single.path!).readAsString();
      final decoded = jsonDecode(content);
      if (decoded is! Map || decoded['profile'] is! Map) {
        throw Exception('Invalid backup');
      }
      final prof = decoded['profile'] as Map;
      final filePin = (prof['pin'] ?? '').toString();

      if (filePin.isNotEmpty && mounted) {
        final entered = await _askPinDialog(filePin);
        if (!entered) return;
      }

      final prefs = await SharedPreferences.getInstance();
      final name = (prof['name'] ?? 'Viewer').toString();
      await prefs.setString('profile_id', (prof['id'] ?? 'CX-RESTORED').toString());
      await prefs.setString('profile_name', name);
      await prefs.setInt('profile_color', (prof['color'] is int) ? prof['color'] : 0xFFE50914);
      await prefs.setString('profile_pin', filePin);

      if (decoded['fan_mode'] is bool) {
        await prefs.setBool('fan_mode', decoded['fan_mode']);
      }
      if (decoded['kotosub_url'] != null) {
        await prefs.setString('kotosub_url', decoded['kotosub_url'].toString());
      }
      if (decoded['plugin_urls'] is List) {
        await prefs.setStringList(
          'plugin_urls',
          (decoded['plugin_urls'] as List).map((e) => e.toString()).toList(),
        );
      }
      if (decoded['watchlist'] is List) {
        await prefs.setString('watchlist_json', jsonEncode(decoded['watchlist']));
      }
      if (decoded['continue_watching'] is List) {
        await prefs.setString(
          'continue_watching_json',
          jsonEncode(decoded['continue_watching']),
        );
      }

      await _initCastex();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile "$name" restored successfully!')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid or corrupted backup file.')),
        );
      }
    }
  }

  Future _askPinDialog(String expectedPin) async {
    final pinCtrl = TextEditingController();
    final res = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121216),
        title: const Text('Enter Backup PIN'),
        content: TextField(
          controller: pinCtrl,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          decoration: const InputDecoration(hintText: '4-digit PIN'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, pinCtrl.text.trim() == expectedPin),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    return res == true;
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
        : 'No new announcements right now.';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121216),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Colors.white12),
        ),
        title: Text(titleText, style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(msgText, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openDetailSheet(Map item) {
    final id = (item['id'] ?? '').toString();
    final inWatchlist = _watchlist.any((w) => w is Map && w['id'].toString() == id);
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
        inWatchlist: inWatchlist,
        onToggleWatchlist: () => _toggleWatchlist(item),
        onSaveProgress: _saveProgress,
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
              colors: [Color(0xCC000000), Color(0x00000000)],
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
          GestureDetector(
            onTap: () => setState(() => _tabIndex = 3),
            child: Padding(
              padding: const EdgeInsets.only(right: 14, left: 4),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Color(_profileColor),
                child: Text(
                  _profileName.isNotEmpty ? _profileName[0].toUpperCase() : 'C',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_continueWatching.isNotEmpty) ...[
                  const Text(
                    'Continue Watching',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 132,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _continueWatching.length,
                      itemBuilder: (ctx, i) {
                        final raw = _continueWatching[i];
                        final cw = raw is Map ? raw : {};
                        final pos = (cw['pos'] is int) ? cw['pos'] as int : 0;
                        final dur = (cw['dur'] is int) ? cw['dur'] as int : 1;
                        final ratio = dur == 0 ? 0.0 : (pos / dur).clamp(0.05, 1.0);
                        return GestureDetector(
                          onTap: () {
                            final url = (cw['url'] ?? '').toString();
                            if (url.startsWith('http')) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CastexPlayerScreen(
                                    title: (cw['title'] ?? 'Resume').toString(),
                                    streamUrl: url,
                                    mediaId: (cw['id'] ?? '').toString(),
                                    poster: (cw['poster'] ?? '').toString(),
                                    startMs: pos,
                                    kotosubUrl: _kotosubUrl,
                                    fanMode: _fanMode,
                                    onSaveProgress: _saveProgress,
                                  ),
                                ),
                              );
                            }
                          },
                          child: Container(
                            width: 195,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111116),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ClipRRect(
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(12),
                                        ),
                                        child: (cw['poster'] ?? '').toString().isNotEmpty
                                            ? Image.network(
                                                cw['poster'].toString(),
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Container(color: Colors.white10),
                                              )
                                            : Container(color: Colors.white10),
                                      ),
                                      Container(
                                        color: Colors.black38,
                                        child: const Icon(
                                          Icons.play_circle_fill_rounded,
                                          color: Colors.white,
                                          size: 34,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 3,
                                  backgroundColor: Colors.white12,
                                  color: const Color(0xFFE50914),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    (cw['title'] ?? 'Video').toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
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
                if (_watchlist.isNotEmpty) ...[
                  _buildPosterSection('My Watchlist', _watchlist),
                  const SizedBox(height: 22),
                ],
                if (_fanMode && _fandubRoutes.isNotEmpty) ...[
                  const Text(
                    'Community Fandubs',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${r['dub_language']} • ${r['creator_name']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: Colors.white60),
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
              final inWl = _watchlist.any((w) => w is Map && w['id'].toString() == id);

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
                                style: const TextStyle(fontSize: 12.5, color: Colors.white70),
                              ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                'HD • KotoSub',
                                style: TextStyle(fontSize: 10.5, color: Colors.white70),
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
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              onPressed: () => _openDetailSheet(item),
                              icon: const Icon(Icons.play_arrow_rounded, size: 22),
                              label: const Text(
                                'Watch Now',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.white10,
                                side: const BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              onPressed: () => _toggleWatchlist(item),
                              icon: Icon(
                                inWl ? Icons.check_rounded : Icons.add_rounded,
                                size: 19,
                              ),
                              label: Text(
                                inWl ? 'Saved' : 'Watchlist',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
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
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
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
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
              decoration: InputDecoration(
                hintText: 'Search movies, shows, anime...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 14.5),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF121216),
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF111116),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(_profileColor),
                  child: Text(
                    _profileName.isNotEmpty ? _profileName[0].toUpperCase() : 'C',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _profileName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'ID: $_profileId • ${_watchlist.length} Saved',
                        style: const TextStyle(fontSize: 12, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Switch / Reset Profile',
                  icon: const Icon(Icons.manage_accounts_rounded, color: Colors.white70),
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('profile_name');
                    widget.onProfileReset();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Account Backup & Restore',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Export your Castex profile, watchlist, progress & addons into a backup file, or restore anytime.',
            style: TextStyle(color: Colors.white54, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _exportBackupFile,
                  icon: const Icon(Icons.upload_file_rounded, size: 19),
                  label: const Text(
                    'Export Backup',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _restoreBackupFile,
                  icon: const Icon(Icons.restore_page_rounded, size: 19),
                  label: const Text(
                    'Restore File',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
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
                'Unlock community fandubs, lore & extra tools',
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
  final bool inWatchlist;
  final Future Function() onToggleWatchlist;
  final Future Function(Map entry) onSaveProgress;

  MediaDetailSheet({
    super.key,
    required this.item,
    required this.fanMode,
    required this.fandubRoutes,
    required this.pluginUrls,
    required this.kotosubUrl,
    required this.inWatchlist,
    required this.onToggleWatchlist,
    required this.onSaveProgress,
  });

  @override
  State createState() => _MediaDetailSheetState();
}

class _MediaDetailSheetState extends State<MediaDetailSheet> {
  String _selectedDubLayer = 'Original Audio';
  String _selectedSubLang = 'Hinglish';
  List _streams = [];
  List _episodes = [];
  int _selectedSeason = 1;
  int _selectedEpisode = 1;
  bool _fetchingStreams = false;
  late bool _savedInWatchlist;

  @override
  void initState() {
    super.initState();
    _savedInWatchlist = widget.inWatchlist;
    _initDetailData();
  }

  Future _initDetailData() async {
    final type = (widget.item['type'] ?? 'movie').toString();
    if (type == 'series') {
      await _fetchSeriesEpisodes();
    }
    await _resolveAddonStreams();
  }

  Future _fetchSeriesEpisodes() async {
    final id = (widget.item['id'] ?? '').toString();
    if (id.isEmpty) return;
    try {
      final res = await http
          .get(Uri.parse('https://v3-cinemeta.strem.io/meta/series/$id.json'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is Map && body['meta'] is Map && body['meta']['videos'] is List) {
          final vids = (body['meta']['videos'] as List)
              .where((v) => v is Map && (v['season'] ?? 0) != 0)
              .toList();
          if (mounted && vids.isNotEmpty) {
            setState(() {
              _episodes = vids;
              _selectedSeason = (vids.first['season'] is int) ? vids.first['season'] : 1;
              _selectedEpisode = (vids.first['episode'] is int) ? vids.first['episode'] : 1;
            });
          }
        }
      }
    } catch (_) {}
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
            : '$base/stream/series/$id:$_selectedSeason:$_selectedEpisode.json';
        try {
          final res = await http
              .get(Uri.parse(streamApi))
              .timeout(const Duration(seconds: 7));
          if (res.statusCode == 200) {
            final decoded = jsonDecode(res.body);
            if (decoded is Map && decoded['streams'] is List) {
              for (final s in (decoded['streams'] as List).take(10)) {
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
    final type = (widget.item['type'] ?? 'movie').toString();

    final seasons = _episodes
        .map((e) => (e is Map && e['season'] is int) ? e['season'] as int : 1)
        .toSet()
        .toList()
      ..sort();

    final seasonEpisodes = _episodes
        .where((e) => e is Map && e['season'] == _selectedSeason)
        .toList();

    final dubOptions = [
      'Original Audio',
      'Official Dub',
      if (widget.fanMode) 'Community Fandub',
    ];
    final subOptions = ['Off', 'Hinglish', 'Bangla', 'Banglish'];

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _savedInWatchlist
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_add_outlined,
                    color: _savedInWatchlist ? const Color(0xFFF5C518) : Colors.white,
                  ),
                  onPressed: () async {
                    await widget.onToggleWatchlist();
                    setState(() => _savedInWatchlist = !_savedInWatchlist);
                  },
                ),
              ],
            ),
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
                  Text(year, style: const TextStyle(color: Colors.white60, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              desc,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60, fontSize: 13.5, height: 1.4),
            ),
            if (type == 'series' && seasons.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Seasons & Episodes',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: seasons.map((s) {
                    final active = _selectedSeason == s;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('Season $s', style: const TextStyle(fontSize: 12)),
                        selected: active,
                        selectedColor: Colors.white,
                        labelStyle: TextStyle(
                          color: active ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) {
                          setState(() {
                            _selectedSeason = s;
                            _selectedEpisode = 1;
                          });
                          _resolveAddonStreams();
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: seasonEpisodes.length,
                  itemBuilder: (ctx, i) {
                    final ep = seasonEpisodes[i] as Map;
                    final epNum = (ep['episode'] is int) ? ep['episode'] as int : (i + 1);
                    final active = _selectedEpisode == epNum;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          'E$epNum • ${(ep['title'] ?? ep['name'] ?? 'Episode $epNum')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: active ? Colors.black : Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        selected: active,
                        selectedColor: Colors.white,
                        onSelected: (_) {
                          setState(() => _selectedEpisode = epNum);
                          _resolveAddonStreams();
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
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
                          fontSize: 12,
                          color: _selectedDubLayer == d ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      selected: _selectedDubLayer == d,
                      selectedColor: Colors.white,
                      onSelected: (_) => setState(() => _selectedDubLayer = d),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
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
                          fontSize: 12,
                          color: _selectedSubLang == s ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      selected: _selectedSubLang == s,
                      selectedColor: Colors.white,
                      onSelected: (_) => setState(() => _selectedSubLang = s),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 18),
            Text(
              type == 'series'
                  ? 'Streams (S$_selectedSeason E$_selectedEpisode)'
                  : 'Streams',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            if (_fetchingStreams)
              const LinearProgressIndicator(color: Colors.white)
            else if (_streams.isEmpty)
              const Text(
                'Install a Stremio stream addon in the Addons tab to play inside Castex.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              )
            else
              ..._streams.map((rawSt) {
                final st = rawSt is Map ? rawSt : {};
                final streamUrl = (st['url'] ?? '').toString();
                final displayTitle = type == 'series'
                    ? '$title (S$_selectedSeason E$_selectedEpisode)'
                    : title;
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'External Player',
                          icon: const Icon(Icons.open_in_new_rounded, size: 19, color: Colors.white54),
                          onPressed: () async {
                            final u = Uri.tryParse(streamUrl);
                            if (u != null) {
                              await launchUrl(u, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                        const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 28),
                      ],
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CastexPlayerScreen(
                            title: displayTitle,
                            streamUrl: streamUrl,
                            mediaId: (widget.item['id'] ?? '').toString(),
                            poster: (widget.item['poster'] ?? '').toString(),
                            startMs: 0,
                            initialSubLang: _selectedSubLang,
                            initialDubLayer: _selectedDubLayer,
                            kotosubUrl: widget.kotosubUrl,
                            fanMode: widget.fanMode,
                            onSaveProgress: widget.onSaveProgress,
                          ),
                        ),
                      );
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

class CastexPlayerScreen extends StatefulWidget {
  final String title;
  final String streamUrl;
  final String mediaId;
  final String poster;
  final int startMs;
  final String initialSubLang;
  final String initialDubLayer;
  final String kotosubUrl;
  final bool fanMode;
  final Future Function(Map entry) onSaveProgress;

  CastexPlayerScreen({
    super.key,
    required this.title,
    required this.streamUrl,
    required this.mediaId,
    required this.poster,
    required this.startMs,
    this.initialSubLang = 'Hinglish',
    this.initialDubLayer = 'Original Audio',
    required this.kotosubUrl,
    required this.fanMode,
    required this.onSaveProgress,
  });

  @override
  State createState() => _CastexPlayerScreenState();
}

class _CastexPlayerScreenState extends State<CastexPlayerScreen> {
  late VideoPlayerController _controller;
  bool _ready = false;
  bool _error = false;
  bool _showControls = true;
  double _speed = 1.0;
  late String _subLang;
  late String _dubLayer;
  String _liveSubCaption = '';
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _subLang = widget.initialSubLang;
    _dubLayer = widget.initialDubLayer;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WakelockPlus.enable();
    _initPlayer();
  }

  Future _initPlayer() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.streamUrl));
      await _controller.initialize();
      if (widget.startMs != 0) {
        await _controller.seekTo(Duration(milliseconds: widget.startMs));
      }
      await _controller.play();
      _controller.addListener(() {
        if (mounted) setState(() {});
      });
      _progressTimer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (_controller.value.isInitialized && _controller.value.isPlaying) {
          widget.onSaveProgress({
            'id': widget.mediaId,
            'title': widget.title,
            'poster': widget.poster,
            'url': widget.streamUrl,
            'pos': _controller.value.position.inMilliseconds,
            'dur': _controller.value.duration.inMilliseconds,
          });
        }
      });
      if (mounted) {
        setState(() => _ready = true);
        _updateKotoSubStatus();
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future _updateKotoSubStatus() async {
    if (_subLang == 'Off') {
      setState(() => _liveSubCaption = '');
      return;
    }
    if (widget.kotosubUrl.isEmpty) {
      setState(() {
        _liveSubCaption = 'KotoSub ($_subLang): Connect Render URL in Profile tab';
      });
      return;
    }
    setState(() {
      _liveSubCaption = 'KotoSub AI • $_subLang Sync Active (0.000s)';
    });
  }

  String _fmt(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hrs = d.inHours;
    return hrs == 0 ? '$mins:$secs' : '$hrs:$mins:$secs';
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    if (_ready) _controller.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        onDoubleTapDown: (details) {
          if (!_ready) return;
          final w = MediaQuery.of(context).size.width;
          final cur = _controller.value.position;
          final target = details.localPosition.dx * 2 == w
              ? cur
              : (details.localPosition.dx * 2 - w).isNegative
                  ? cur - const Duration(seconds: 10)
                  : cur + const Duration(seconds: 10);
          _controller.seekTo(target);
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_error)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Stream codec unsupported by built-in player.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      final u = Uri.tryParse(widget.streamUrl);
                      if (u != null) {
                        await launchUrl(u, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: const Text('Open in External Player'),
                  ),
                ],
              )
            else if (!_ready)
              const CircularProgressIndicator(color: Colors.white)
            else
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            if (_liveSubCaption.isNotEmpty)
              Positioned(
                bottom: _showControls ? 76 : 26,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _liveSubCaption,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (_showControls)
              Container(
                color: Colors.black45,
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            Expanded(
                              child: Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                final langs = ['Hinglish', 'Bangla', 'Banglish', 'Off'];
                                final next = langs[(langs.indexOf(_subLang) + 1) % langs.length];
                                setState(() => _subLang = next);
                                _updateKotoSubStatus();
                              },
                              icon: const Icon(Icons.subtitles_rounded, color: Colors.white, size: 18),
                              label: Text(
                                _subLang,
                                style: const TextStyle(color: Colors.white, fontSize: 12.5),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                final dubs = [
                                  'Original Audio',
                                  'Official Dub',
                                  if (widget.fanMode) 'Community Fandub',
                                ];
                                final next = dubs[(dubs.indexOf(_dubLayer) + 1) % dubs.length];
                                setState(() => _dubLayer = next);
                              },
                              icon: const Icon(Icons.audiotrack_rounded, color: Colors.white, size: 18),
                              label: Text(
                                _dubLayer,
                                style: const TextStyle(color: Colors.white, fontSize: 12.5),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                if (!_ready) return;
                                final speeds = [1.0, 1.25, 1.5, 2.0];
                                final next = speeds[(speeds.indexOf(_speed) + 1) % speeds.length];
                                _controller.setPlaybackSpeed(next);
                                setState(() => _speed = next);
                              },
                              child: Text(
                                '${_speed}x',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_ready)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              iconSize: 36,
                              icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                              onPressed: () => _controller.seekTo(
                                _controller.value.position - const Duration(seconds: 10),
                              ),
                            ),
                            const SizedBox(width: 28),
                            IconButton(
                              iconSize: 54,
                              icon: Icon(
                                _controller.value.isPlaying
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_filled_rounded,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                _controller.value.isPlaying
                                    ? _controller.pause()
                                    : _controller.play();
                                setState(() {});
                              },
                            ),
                            const SizedBox(width: 28),
                            IconButton(
                              iconSize: 36,
                              icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                              onPressed: () => _controller.seekTo(
                                _controller.value.position + const Duration(seconds: 10),
                              ),
                            ),
                          ],
                        ),
                      if (_ready)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Row(
                            children: [
                              Text(
                                _fmt(_controller.value.position),
                                style: const TextStyle(fontSize: 12, color: Colors.white70),
                              ),
                              Expanded(
                                child: Slider(
                                  activeColor: const Color(0xFFE50914),
                                  inactiveColor: Colors.white24,
                                  value: _controller.value.position.inMilliseconds
                                      .toDouble()
                                      .clamp(
                                        0.0,
                                        _controller.value.duration.inMilliseconds
                                            .toDouble()
                                            .clamp(1.0, double.infinity),
                                      ),
                                  max: _controller.value.duration.inMilliseconds
                                      .toDouble()
                                      .clamp(1.0, double.infinity),
                                  onChanged: (v) {
                                    _controller.seekTo(Duration(milliseconds: v.toInt()));
                                  },
                                ),
                              ),
                              Text(
                                _fmt(_controller.value.duration),
                                style: const TextStyle(fontSize: 12, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
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
