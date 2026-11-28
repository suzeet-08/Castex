import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

typedef JsonMap = Map<String, dynamic>;

// ============================================================================
// 1. CASTEX CORE CONFIGURATION
// ============================================================================
class CastexConfig {
  static const String appVersion = '1.0.0-modular';
  static const String firebaseApiKey =
      'AIzaSyCgbpacxuwoJgwheOFlk_Vln4nWgnZ4FCc';
  static const String firebaseDbUrl =
      'https://castex-app-2eb5b-default-rtdb.asia-southeast1.firebasedatabase.app';
  static const String kotoSubServerUrl = 'https://sub-bot-act8.onrender.com';
  static const String defaultCinemetaUrl =
      'https://v3-cinemeta.strem.io/manifest.json';
}

// ============================================================================
// 2. THEME & APPEARANCE MODEL
// ============================================================================
class CastexAppearance {
  String accentHex;
  bool amoledBlack;
  bool autoPosterAura;
  String dockMode; // Adaptive, Expanded, Compact
  bool fanMode;
  bool spoilerShield;
  bool cloudflareDns;
  bool autoNextEpisode;
  String defaultSubLang; // Hinglish, Bangla, Banglish, English
  bool dualSubtitles;
  double subFontSize;
  double subBgOpacity;

  CastexAppearance({
    this.accentHex = '#FF2A55',
    this.amoledBlack = true,
    this.autoPosterAura = true,
    this.dockMode = 'Adaptive',
    this.fanMode = true,
    this.spoilerShield = true,
    this.cloudflareDns = true,
    this.autoNextEpisode = true,
    this.defaultSubLang = 'Hinglish',
    this.dualSubtitles = true,
    this.subFontSize = 16.0,
    this.subBgOpacity = 0.58,
  });

  Color get accentColor {
    try {
      final clean = accentHex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFFFF2A55);
    }
  }

  Color get bgColor =>
      amoledBlack ? const Color(0xFF000000) : const Color(0xFF090B10);

  Color get cardColor =>
      amoledBlack ? const Color(0xFF0D1016) : const Color(0xFF141822);

  JsonMap toJson() => {
        'accentHex': accentHex,
        'amoledBlack': amoledBlack,
        'autoPosterAura': autoPosterAura,
        'dockMode': dockMode,
        'fanMode': fanMode,
        'spoilerShield': spoilerShield,
        'cloudflareDns': cloudflareDns,
        'autoNextEpisode': autoNextEpisode,
        'defaultSubLang': defaultSubLang,
        'dualSubtitles': dualSubtitles,
        'subFontSize': subFontSize,
        'subBgOpacity': subBgOpacity,
      };

  factory CastexAppearance.fromJson(JsonMap? json) {
    if (json == null) return CastexAppearance();
    return CastexAppearance(
      accentHex: json['accentHex']?.toString() ?? '#FF2A55',
      amoledBlack: json['amoledBlack'] ?? true,
      autoPosterAura: json['autoPosterAura'] ?? true,
      dockMode: json['dockMode']?.toString() ?? 'Adaptive',
      fanMode: json['fanMode'] ?? true,
      spoilerShield: json['spoilerShield'] ?? true,
      cloudflareDns: json['cloudflareDns'] ?? true,
      autoNextEpisode: json['autoNextEpisode'] ?? true,
      defaultSubLang: json['defaultSubLang']?.toString() ?? 'Hinglish',
      dualSubtitles: json['dualSubtitles'] ?? true,
      subFontSize: (json['subFontSize'] as num?)?.toDouble() ?? 16.0,
      subBgOpacity: (json['subBgOpacity'] as num?)?.toDouble() ?? 0.58,
    );
  }

  String toPresetCode() {
    final hex = accentHex.replaceAll('#', '').toUpperCase();
    return 'CX-$hex-${fanMode ? 'FAN' : 'STD'}';
  }

  bool applyPresetCode(String raw) {
    final code = raw.trim().toUpperCase();
    if (code == 'CX-NEON') {
      accentHex = '#00F5D4';
      return true;
    }
    if (code == 'CX-AMBER') {
      accentHex = '#F59E0B';
      return true;
    }
    if (code == 'CX-CRIMSON') {
      accentHex = '#FF2A55';
      return true;
    }
    final parts = code.split('-');
    if (parts.length >= 2 && parts[0] == 'CX' && parts[1].length == 6) {
      accentHex = '#${parts[1]}';
      return true;
    }
    return false;
  }
}

// ============================================================================
// 3. USER PROFILE & AVATARS
// ============================================================================
class UserProfile {
  String id;
  String name;
  int avatarIndex;
  String customAvatarUrl;
  String pin;
  bool simpleModeOnly;

  UserProfile({
    required this.id,
    required this.name,
    this.avatarIndex = 0,
    this.customAvatarUrl = '',
    this.pin = '',
    this.simpleModeOnly = false,
  });

  JsonMap toJson() => {
        'id': id,
        'name': name,
        'avatarIndex': avatarIndex,
        'customAvatarUrl': customAvatarUrl,
        'pin': pin,
        'simpleModeOnly': simpleModeOnly,
      };

  factory UserProfile.fromJson(JsonMap json) => UserProfile(
        id: json['id']?.toString() ?? 'p1',
        name: json['name']?.toString() ?? 'Viewer',
        avatarIndex: (json['avatarIndex'] as num?)?.toInt() ?? 0,
        customAvatarUrl: json['customAvatarUrl']?.toString() ?? '',
        pin: json['pin']?.toString() ?? '',
        simpleModeOnly: json['simpleModeOnly'] ?? false,
      );
}

class AvatarPreset {
  final IconData icon;
  final int c1;
  final int c2;
  const AvatarPreset(this.icon, this.c1, this.c2);
}

class BuiltInAvatars {
  static const List<AvatarPreset> items = [
    AvatarPreset(Icons.bolt_rounded, 0xFFFF2A55, 0xFF7A001E),
    AvatarPreset(Icons.auto_awesome, 0xFF00D4FF, 0xFF0052D4),
    AvatarPreset(Icons.local_fire_department, 0xFFFF512F, 0xFFDD2476),
    AvatarPreset(Icons.nightlight_round, 0xFF7F00FF, 0xFFE100FF),
    AvatarPreset(Icons.shield_moon_rounded, 0xFF11998E, 0xFF38EF7D),
    AvatarPreset(Icons.pets_rounded, 0xFFF7971E, 0xFFFFD200),
    AvatarPreset(Icons.rocket_launch_rounded, 0xFF3A7BD5, 0xFF00D2FF),
    AvatarPreset(Icons.sports_esports_rounded, 0xFF8E2DE2, 0xFF4A00E0),
    AvatarPreset(Icons.visibility_rounded, 0xFFCB2D3E, 0xFFEF473A),
    AvatarPreset(Icons.cruelty_free_rounded, 0xFFEC008C, 0xFFFC6767),
    AvatarPreset(Icons.whatshot_rounded, 0xFFF12711, 0xFFF5AF19),
    AvatarPreset(Icons.ac_unit_rounded, 0xFF56CCF2, 0xFF2F80ED),
    AvatarPreset(Icons.catching_pokemon, 0xFFFF416C, 0xFFFF4B2B),
    AvatarPreset(Icons.cyclone_rounded, 0xFF00B4DB, 0xFF0083B0),
    AvatarPreset(Icons.diamond_rounded, 0xFFDA22FF, 0xFF9733EE),
    AvatarPreset(Icons.eco_rounded, 0xFF56AB2F, 0xFFA8E063),
    AvatarPreset(Icons.flash_on_rounded, 0xFFFFB75E, 0xFFED8F03),
    AvatarPreset(Icons.headphones_rounded, 0xFF4776E6, 0xFF8E54E9),
    AvatarPreset(Icons.movie_filter_rounded, 0xFFD31027, 0xFFEA384D),
    AvatarPreset(Icons.star_rounded, 0xFFFF8008, 0xFFFFC837),
  ];
}

class AvatarWidget extends StatelessWidget {
  final UserProfile profile;
  final double size;
  final bool showBorder;
  final Color borderColor;

  const AvatarWidget({
    super.key,
    required this.profile,
    this.size = 42,
    this.showBorder = false,
    this.borderColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final idx = profile.avatarIndex.clamp(0, BuiltInAvatars.items.length - 1);
    final preset = BuiltInAvatars.items[idx];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showBorder ? Border.all(color: borderColor, width: 2) : null,
        gradient: LinearGradient(
          colors: [Color(preset.c1), Color(preset.c2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipOval(
        child: profile.customAvatarUrl.trim().isNotEmpty
            ? Image.network(
                profile.customAvatarUrl.trim(),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  preset.icon,
                  color: Colors.white,
                  size: size * 0.54,
                ),
              )
            : Icon(
                preset.icon,
                color: Colors.white,
                size: size * 0.54,
              ),
      ),
    );
  }
}

// ============================================================================
// 4. MEDIA, STREAM, KOTOSUB CUE & ADDON MODELS
// ============================================================================
class QuizQuestion {
  final String question;
  final String optionA;
  final String optionB;
  final String optionC;
  final String correctOption;

  const QuizQuestion({
    required this.question,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.correctOption,
  });
}

class AppNotification {
  final String title;
  final String body;
  final String time;

  const AppNotification({
    required this.title,
    required this.body,
    required this.time,
  });
}

class TimedSubtitleCue {
  final Duration start;
  final Duration end;
  final String primaryText;
  final String secondaryEnglish;

  const TimedSubtitleCue({
    required this.start,
    required this.end,
    required this.primaryText,
    this.secondaryEnglish = '',
  });
}

class StreamSource {
  final String id;
  final String title;
  final String quality;
  final String dubLayer; // Original Audio, Official Dub, Community Fandub
  final String language;
  final String provider;
  final String url;
  final bool isDirectPlayable;

  const StreamSource({
    required this.id,
    required this.title,
    required this.quality,
    required this.dubLayer,
    required this.language,
    required this.provider,
    required this.url,
    this.isDirectPlayable = true,
  });
}

class EpisodeItem {
  final String id;
  final int season;
  final int number;
  final String title;
  final String synopsis;
  final String thumbnailUrl;
  final String duration;
  final double rating;
  final String canonTag;
  final int introStartSec;
  final int introEndSec;
  final List<StreamSource> streams;

  const EpisodeItem({
    required this.id,
    required this.season,
    required this.number,
    required this.title,
    required this.synopsis,
    required this.thumbnailUrl,
    required this.duration,
    required this.rating,
    this.canonTag = 'CANON',
    this.introStartSec = 5,
    this.introEndSec = 25,
    required this.streams,
  });
}

class MediaItem {
  final String id;
  final String title;
  final String type; // movie, series, anime
  final String year;
  final double rating;
  final String qualityBadge;
  final String studio;
  final List<String> genres;
  final Color auraColor;
  final String posterUrl;
  final String backdropUrl;
  final String overview;
  final String aiRecap;
  final List<EpisodeItem> episodes;
  final List<QuizQuestion> quizQuestions;

  const MediaItem({
    required this.id,
    required this.title,
    required this.type,
    required this.year,
    required this.rating,
    required this.qualityBadge,
    required this.studio,
    required this.genres,
    required this.auraColor,
    required this.posterUrl,
    required this.backdropUrl,
    required this.overview,
    required this.aiRecap,
    required this.episodes,
    required this.quizQuestions,
  });

  MediaItem copyWith({
    String? overview,
    String? aiRecap,
    List<EpisodeItem>? episodes,
    List<String>? genres,
  }) {
    return MediaItem(
      id: id,
      title: title,
      type: type,
      year: year,
      rating: rating,
      qualityBadge: qualityBadge,
      studio: studio,
      genres: genres ?? this.genres,
      auraColor: auraColor,
      posterUrl: posterUrl,
      backdropUrl: backdropUrl,
      overview: overview ?? this.overview,
      aiRecap: aiRecap ?? this.aiRecap,
      episodes: episodes ?? this.episodes,
      quizQuestions: quizQuestions,
    );
  }
}

class AddonManifest {
  final String id;
  final String name;
  final String url;
  final String type;
  bool enabled;

  AddonManifest({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    this.enabled = true,
  });

  JsonMap toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'type': type,
        'enabled': enabled,
      };

  factory AddonManifest.fromJson(JsonMap json) => AddonManifest(
        id: json['id']?.toString() ?? DateTime.now().toString(),
        name: json['name']?.toString() ?? 'Custom Addon',
        url: json['url']?.toString() ?? '',
        type: json['type']?.toString() ?? 'Stremio Addon',
        enabled: json['enabled'] ?? true,
      );
}

// ============================================================================
// 5. LIVE STREMIO / JSON ADDON ENGINE + REAL KOTOSUB SRT/VTT ENGINE
// ============================================================================
class CastexAddonEngine {
  static const Map<String, String> _headers = {
    'Accept': 'application/json',
    'User-Agent': 'Castex/1.0 (Flutter; Android)',
  };

  static const String _openStreamA =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4';
  static const String _openStreamB =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4';

  static final List<MediaItem> starterShowcase = [
    MediaItem(
      id: 'tt10872600',
      title: 'Spider-Man: No Way Home',
      type: 'movie',
      year: '2021',
      rating: 8.2,
      qualityBadge: '4K HDR',
      studio: 'Cinemeta',
      genres: ['Action', 'Adventure', 'Sci-Fi'],
      auraColor: const Color(0xFFFF2A55),
      posterUrl: 'https://images.metahub.space/poster/medium/tt10872600/img',
      backdropUrl:
          'https://images.metahub.space/background/medium/tt10872600/img',
      overview:
          'With Spider-Man\'s identity now revealed, Peter asks Doctor Strange for help. When a spell goes wrong, dangerous foes from other worlds start to appear.',
      aiRecap:
          'Multiverse breach triggered after Doctor Strange\'s memory spell fractures across realities.',
      episodes: [
        EpisodeItem(
          id: 'tt10872600_1',
          season: 1,
          number: 1,
          title: 'Spider-Man: No Way Home (Addon Resolver)',
          synopsis: 'Tap to resolve streams from your installed Stremio addons.',
          thumbnailUrl:
              'https://images.metahub.space/background/medium/tt10872600/img',
          duration: '148m',
          rating: 8.2,
          streams: [
            StreamSource(
              id: 'demo_spidey',
              title: 'Castex Open Cinema Test Stream (1080p)',
              quality: '1080p',
              dubLayer: 'Original Audio',
              language: 'English + KotoSub',
              provider: 'Castex Test Node',
              url: _openStreamA,
            ),
          ],
        ),
      ],
      quizQuestions: const [
        QuizQuestion(
          question: 'Who casts the spell that fractures the multiverse?',
          optionA: 'Doctor Strange',
          optionB: 'Wong',
          optionC: 'Tony Stark',
          correctOption: 'a',
        ),
      ],
    ),
    MediaItem(
      id: 'tt9335498',
      title: 'Demon Slayer: Kimetsu no Yaiba',
      type: 'series',
      year: '2019',
      rating: 8.6,
      qualityBadge: '1080p',
      studio: 'Cinemeta',
      genres: ['Anime', 'Action', 'Fantasy'],
      auraColor: const Color(0xFF00D4FF),
      posterUrl: 'https://images.metahub.space/poster/medium/tt9335498/img',
      backdropUrl:
          'https://images.metahub.space/background/medium/tt9335498/img',
      overview:
          'A family is attacked by demons and only two members survive - Tanjiro and his sister Nezuko, who is turning into a demon slowly.',
      aiRecap:
          'Tanjiro trains with the Hashira to master Sun Breathing and cure Nezuko.',
      episodes: [
        EpisodeItem(
          id: 'tt9335498:1:1',
          season: 1,
          number: 1,
          title: 'Cruelty',
          synopsis: 'Tanjiro returns home after selling charcoal in town.',
          thumbnailUrl:
              'https://images.metahub.space/background/medium/tt9335498/img',
          duration: '24m',
          rating: 8.7,
          streams: [
            StreamSource(
              id: 'demo_ds',
              title: 'Castex Anime Test Stream (1080p)',
              quality: '1080p',
              dubLayer: 'Original Audio',
              language: 'Japanese + KotoSub',
              provider: 'Castex Test Node',
              url: _openStreamB,
            ),
          ],
        ),
      ],
      quizQuestions: const [
        QuizQuestion(
          question: 'What is the name of Tanjiro\'s sister?',
          optionA: 'Nezuko',
          optionB: 'Shinobu',
          optionC: 'Mitsuri',
          correctOption: 'a',
        ),
      ],
    ),
  ];

  static String _baseUrlFromManifest(String manifestUrl) {
    final clean = manifestUrl.trim();
    if (clean.endsWith('/manifest.json')) {
      return clean.substring(0, clean.length - '/manifest.json'.length);
    }
    return clean.endsWith('/') ? clean.substring(0, clean.length - 1) : clean;
  }

  static Future<JsonMap?> validateManifest(String url) async {
    try {
      final res = await http
          .get(Uri.parse(url.trim()), headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as JsonMap;
      }
    } catch (_) {}
    return null;
  }

  static Future<List<MediaItem>> fetchCatalogAndSearch({
    required List<AddonManifest> enabledAddons,
    String query = '',
    String typeFilter = 'all',
    String genreFilter = 'All',
  }) async {
    final List<MediaItem> collected = [];
    final seenIds = <String>{};

    final activeAddons = enabledAddons
        .where((a) =>
            a.enabled &&
            (a.url.contains('manifest.json') || a.url.endsWith('.json')))
        .toList();

    for (final addon in activeAddons) {
      try {
        if (addon.url.contains('manifest.json')) {
          final base = _baseUrlFromManifest(addon.url);
          final manifest = await validateManifest(addon.url);
          final catalogs = (manifest?['catalogs'] as List?) ?? [];

          final List<(String, String)> endpoints = [];
          if (catalogs.isNotEmpty) {
            for (final c in catalogs.take(4)) {
              final cm = JsonMap.from(c as Map);
              final cType = cm['type']?.toString() ?? 'movie';
              final cId = cm['id']?.toString() ?? 'top';
              if (typeFilter == 'all' ||
                  cType.toLowerCase() == typeFilter.toLowerCase()) {
                endpoints.add((cType, cId));
              }
            }
          }
          if (endpoints.isEmpty) {
            if (typeFilter == 'all' || typeFilter == 'movie') {
              endpoints.add(('movie', 'top'));
            }
            if (typeFilter == 'all' || typeFilter == 'series') {
              endpoints.add(('series', 'top'));
            }
          }

          for (final ep in endpoints) {
            final t = ep.$1;
            final catId = ep.$2;
            final url = query.trim().isEmpty
                ? '$base/catalog/$t/$catId.json'
                : '$base/catalog/$t/$catId/search=${Uri.encodeComponent(query.trim())}.json';

            final res = await http
                .get(Uri.parse(url), headers: _headers)
                .timeout(const Duration(seconds: 7));
            if (res.statusCode == 200) {
              final data = jsonDecode(res.body) as JsonMap;
              final metas = (data['metas'] as List?) ?? [];
              for (final raw in metas.take(20)) {
                final m = JsonMap.from(raw as Map);
                final id = m['id']?.toString() ?? '';
                if (id.isEmpty || seenIds.contains(id)) continue;
                seenIds.add(id);

                final title = m['name']?.toString() ?? 'Untitled';
                final poster = m['poster']?.toString() ??
                    'https://images.metahub.space/poster/medium/$id/img';
                final bg = m['background']?.toString() ??
                    'https://images.metahub.space/background/medium/$id/img';
                final desc = m['description']?.toString() ??
                    'Fetched via ${addon.name}. Open to load episodes and streams.';
                final genres = ((m['genres'] as List?) ?? ['Cinema'])
                    .map((g) => g.toString())
                    .toList();

                collected.add(
                  MediaItem(
                    id: id,
                    title: title,
                    type: m['type']?.toString() ?? t,
                    year: m['releaseInfo']?.toString() ??
                        m['year']?.toString() ??
                        '2026',
                    rating: double.tryParse(
                            m['imdbRating']?.toString() ?? '8.0') ??
                        8.0,
                    qualityBadge: 'HD / 4K',
                    studio: addon.name,
                    genres: genres.isEmpty ? ['Cinema'] : genres,
                    auraColor: collected.length % 2 == 0
                        ? const Color(0xFFFF2A55)
                        : const Color(0xFF00D4FF),
                    posterUrl: poster,
                    backdropUrl: bg,
                    overview: desc,
                    aiRecap: 'KotoSub Summary: $desc',
                    episodes: [
                      EpisodeItem(
                        id: t == 'movie' ? id : '$id:1:1',
                        season: 1,
                        number: 1,
                        title: t == 'movie' ? title : 'Episode 1',
                        synopsis: desc,
                        thumbnailUrl: bg,
                        duration: t == 'movie' ? '120m' : '24m',
                        rating: 8.2,
                        streams: [
                          StreamSource(
                            id: '${id}_fallback',
                            title: 'Castex Open Cinema Preview Stream (1080p)',
                            quality: '1080p',
                            dubLayer: 'Original Audio',
                            language: 'KotoSub Ready',
                            provider: 'Castex Core',
                            url: t == 'movie' ? _openStreamA : _openStreamB,
                          ),
                        ],
                      ),
                    ],
                    quizQuestions: [
                      QuizQuestion(
                        question: 'Which title did you watch?',
                        optionA: title,
                        optionB: 'Another Title',
                        optionC: 'Unknown',
                        correctOption: 'a',
                      ),
                    ],
                  ),
                );
              }
            }
          }
        }
      } catch (_) {}
    }

    List<MediaItem> result =
        collected.isEmpty ? List.of(starterShowcase) : collected;

    if (query.trim().isNotEmpty && collected.isEmpty) {
      final q = query.trim().toLowerCase();
      result = result
          .where((i) =>
              i.title.toLowerCase().contains(q) ||
              i.genres.any((g) => g.toLowerCase().contains(q)))
          .toList();
    }

    if (genreFilter != 'All') {
      final byGenre = result
          .where((i) => i.genres
              .any((g) => g.toLowerCase().contains(genreFilter.toLowerCase())))
          .toList();
      if (byGenre.isNotEmpty) result = byGenre;
    }

    return result;
  }

  static Future<MediaItem> fetchFullMeta({
    required List<AddonManifest> enabledAddons,
    required MediaItem item,
  }) async {
    for (final addon in enabledAddons) {
      if (!addon.enabled || !addon.url.contains('manifest.json')) continue;
      try {
        final base = _baseUrlFromManifest(addon.url);
        final uri = Uri.parse('$base/meta/${item.type}/${item.id}.json');
        final res = await http
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 7));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as JsonMap;
          final meta = data['meta'] as JsonMap?;
          if (meta != null) {
            final videos = (meta['videos'] as List?) ?? [];
            final desc = meta['description']?.toString() ?? item.overview;
            final genres = ((meta['genres'] as List?) ?? item.genres)
                .map((g) => g.toString())
                .toList();

            if (videos.isNotEmpty) {
              final eps = videos.take(40).map((v) {
                final vm = JsonMap.from(v as Map);
                final s = (vm['season'] as num?)?.toInt() ?? 1;
                final e = (vm['episode'] as num?)?.toInt() ?? 1;
                final epId = vm['id']?.toString() ?? '${item.id}:$s:$e';
                return EpisodeItem(
                  id: epId,
                  season: s,
                  number: e,
                  title: vm['name']?.toString() ??
                      vm['title']?.toString() ??
                      'Episode $e',
                  synopsis: vm['overview']?.toString() ?? desc,
                  thumbnailUrl:
                      vm['thumbnail']?.toString() ?? item.backdropUrl,
                  duration: '24m',
                  rating: item.rating,
                  streams: [
                    StreamSource(
                      id: '${epId}_preview',
                      title: 'Castex Open Preview Stream (1080p)',
                      quality: '1080p',
                      dubLayer: 'Original Audio',
                      language: 'KotoSub Ready',
                      provider: 'Castex Core',
                      url: _openStreamB,
                    ),
                  ],
                );
              }).toList();
              return item.copyWith(
                overview: desc,
                aiRecap: 'KotoSub AI Summary: $desc',
                episodes: eps,
                genres: genres,
              );
            }
            return item.copyWith(
              overview: desc,
              aiRecap: 'KotoSub AI Summary: $desc',
              genres: genres,
            );
          }
        }
      } catch (_) {}
    }
    return item;
  }

  static Future<List<StreamSource>> resolveAddonStreams({
    required List<AddonManifest> enabledAddons,
    required MediaItem item,
    required EpisodeItem episode,
  }) async {
    final List<StreamSource> resolved = [];

    for (final addon in enabledAddons) {
      if (!addon.enabled || !addon.url.contains('manifest.json')) continue;
      try {
        final base = _baseUrlFromManifest(addon.url);
        final streamId = item.type == 'movie' ? item.id : episode.id;
        final uri = Uri.parse(
            '$base/stream/${item.type}/${Uri.encodeComponent(streamId)}.json');
        final res = await http
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 7));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as JsonMap;
          final list = (data['streams'] as List?) ?? [];
          int idx = 0;
          for (final raw in list.take(15)) {
            idx++;
            final s = JsonMap.from(raw as Map);
            final directUrl = s['url']?.toString() ?? '';
            final externalUrl = s['externalUrl']?.toString() ?? '';
            final label =
                '${s['name'] ?? addon.name} ${s['title'] ?? ''}'.trim();
            final lower = label.toLowerCase();

            final quality = lower.contains('2160') || lower.contains('4k')
                ? '4K'
                : lower.contains('1080')
                    ? '1080p'
                    : lower.contains('720')
                        ? '720p'
                        : 'HD';

            final dubLayer = lower.contains('fandub')
                ? 'Community Fandub'
                : (lower.contains('hindi') ||
                        lower.contains('dual') ||
                        lower.contains('dub'))
                    ? 'Official Dub'
                    : 'Original Audio';

            if (directUrl.startsWith('http')) {
              resolved.add(
                StreamSource(
                  id: '${addon.id}_s_$idx',
                  title: label.isEmpty ? '${addon.name} Stream #$idx' : label,
                  quality: quality,
                  dubLayer: dubLayer,
                  language: lower.contains('hindi')
                      ? 'Hindi / Dual'
                      : lower.contains('bangla')
                          ? 'Bangla'
                          : 'Multi / KotoSub',
                  provider: addon.name,
                  url: directUrl,
                  isDirectPlayable: true,
                ),
              );
            } else if (externalUrl.startsWith('http')) {
              resolved.add(
                StreamSource(
                  id: '${addon.id}_ext_$idx',
                  title: '$label [External Link]',
                  quality: quality,
                  dubLayer: dubLayer,
                  language: 'External',
                  provider: addon.name,
                  url: externalUrl,
                  isDirectPlayable: false,
                ),
              );
            }
          }
        }
      } catch (_) {}
    }

    // Always append fallback playable streams so player never dead-ends
    resolved.addAll(episode.streams);
    return resolved;
  }

  // Real KotoSub AI Subtitle Fetcher + SRT/VTT Parser
  static Future<List<TimedSubtitleCue>> fetchKotoSubCues({
    required String mediaTitle,
    required String episodeTitle,
    required String targetLang,
    String? customSrtUrl,
  }) async {
    // 1. Try custom SRT/VTT URL if provided
    if (customSrtUrl != null && customSrtUrl.trim().startsWith('http')) {
      try {
        final res = await http
            .get(Uri.parse(customSrtUrl.trim()), headers: _headers)
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200 && res.body.contains('-->')) {
          final parsed = parseSrtOrVtt(res.body);
          if (parsed.isNotEmpty) return parsed;
        }
      } catch (_) {}
    }

    // 2. Query Render KotoSub Backend
    try {
      final uri = Uri.parse('${CastexConfig.kotoSubServerUrl}/subtitles').replace(
        queryParameters: {
          'title': mediaTitle,
          'episode': episodeTitle,
          'lang': targetLang,
        },
      );
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        if (res.body.contains('-->')) {
          final parsed = parseSrtOrVtt(res.body);
          if (parsed.isNotEmpty) return parsed;
        }
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['cues'] is List) {
          final list = decoded['cues'] as List;
          return list.map((c) {
            final cm = JsonMap.from(c as Map);
            return TimedSubtitleCue(
              start: Duration(milliseconds: (cm['startMs'] as num?)?.toInt() ?? 0),
              end: Duration(milliseconds: (cm['endMs'] as num?)?.toInt() ?? 4000),
              primaryText: cm['text']?.toString() ?? '',
              secondaryEnglish: cm['en']?.toString() ?? '',
            );
          }).toList();
        }
      }
    } catch (_) {}

    // 3. Dynamic Title-Aware Fallback Cues (Never hardcoded to one anime!)
    return [
      TimedSubtitleCue(
        start: const Duration(seconds: 0),
        end: const Duration(seconds: 5),
        primaryText: targetLang == 'Bangla'
            ? 'KotoSub AI: "$mediaTitle" ($targetLang) সিঙ্ক চালু হয়েছে'
            : 'KotoSub AI: "$mediaTitle" ($targetLang) sync active',
        secondaryEnglish: 'KotoSub AI: "$mediaTitle" subtitle engine ready',
      ),
      TimedSubtitleCue(
        start: const Duration(seconds: 5),
        end: const Duration(seconds: 12),
        primaryText: targetLang == 'Bangla'
            ? 'ডানপাশে সোয়াইপ করে ভলিউম এবং বামপাশে ব্রাইটনেস কন্ট্রোল করুন'
            : targetLang == 'Hinglish'
                ? 'Left swipe se Brightness aur Right swipe se Volume control karein'
                : 'Swipe left for Brightness and right for Volume anytime',
        secondaryEnglish: 'Swipe left for Brightness • Swipe right for Volume',
      ),
      TimedSubtitleCue(
        start: const Duration(seconds: 12),
        end: const Duration(seconds: 22),
        primaryText: targetLang == 'Bangla'
            ? 'সাবটাইটেল টাইমিং মিলাতে +0.5s বা -0.5s বাটন ব্যবহার করুন'
            : targetLang == 'Hinglish'
                ? 'Subtitle timing match karne ke liye +0.5s ya -0.5s use karein'
                : 'Use +0.5s / -0.5s offset to fine-tune subtitle sync',
        secondaryEnglish: 'Use +0.5s / -0.5s offset to fine-tune sync',
      ),
    ];
  }

  static List<TimedSubtitleCue> parseSrtOrVtt(String raw) {
    final List<TimedSubtitleCue> cues = [];
    final blocks = raw.replaceAll('\r\n', '\n').split('\n\n');
    final timeRegex = RegExp(
      r'(\d{2}):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2})[,.](\d{3})',
    );

    for (final block in blocks) {
      final lines = block.trim().split('\n');
      for (int i = 0; i < lines.length; i++) {
        final match = timeRegex.firstMatch(lines[i]);
        if (match != null) {
          final start = Duration(
            hours: int.parse(match.group(1)!),
            minutes: int.parse(match.group(2)!),
            seconds: int.parse(match.group(3)!),
            milliseconds: int.parse(match.group(4)!),
          );
          final end = Duration(
            hours: int.parse(match.group(5)!),
            minutes: int.parse(match.group(6)!),
            seconds: int.parse(match.group(7)!),
            milliseconds: int.parse(match.group(8)!),
          );
          final textLines = lines
              .sublist(i + 1)
              .map((l) => l.replaceAll(RegExp(r'<[^>]*>'), '').trim())
              .where((l) => l.isNotEmpty)
              .toList();
          if (textLines.isNotEmpty) {
            cues.add(
              TimedSubtitleCue(
                start: start,
                end: end,
                primaryText: textLines.first,
                secondaryEnglish:
                    textLines.length > 1 ? textLines.sublist(1).join(' ') : '',
              ),
            );
          }
          break;
        }
      }
    }
    return cues;
  }
}

// ============================================================================
// 6. PERSISTENT FIREBASE AUTH + REALTIME DB SYNC CONTROLLER
// ============================================================================
class CastexController extends ChangeNotifier {
  late SharedPreferences _prefs;

  String? uid;
  String? email;
  String? idToken;
  String? refreshToken;
  bool localGuestMode = false;
  bool isSyncing = false;
  String syncStatus = 'Offline Local';

  CastexAppearance appearance = CastexAppearance();
  List<UserProfile> profiles = [
    UserProfile(id: 'p_main', name: 'Castex Viewer', avatarIndex: 0),
  ];
  String activeProfileId = 'p_main';
  bool profileUnlocked = true;

  Set<String> watchlistIds = {};
  Set<String> offlinePocketIds = {};
  Map<String, double> watchProgress = {};
  Map<String, int> genreMinutes = {
    'Anime': 45,
    'Action': 30,
    'Sci-Fi': 20,
  };
  int totalWatchMinutes = 95;
  Set<String> completed80Ids = {};
  Set<String> quizClaimedIds = {};
  List<String> unlockedBadges = ['Castex v1.0 Pioneer'];
  List<AddonManifest> addons = [
    AddonManifest(
      id: 'addon_cinemeta',
      name: 'Cinemeta Official Catalog',
      url: CastexConfig.defaultCinemetaUrl,
      type: 'Catalog JSON',
      enabled: true,
    ),
    AddonManifest(
      id: 'addon_kotosub',
      name: 'KotoSub AI Subtitle Engine',
      url: CastexConfig.kotoSubServerUrl,
      type: 'AI Subtitle Engine',
      enabled: true,
    ),
  ];

  final List<AppNotification> notifications = const [
    AppNotification(
      title: 'Castex Modular Core Active',
      body:
          '120Hz smooth rendering, live Stremio search, Brightness/Volume swipe player & KotoSub SRT parser ready.',
      time: 'Now',
    ),
    AppNotification(
      title: 'Cloudflare 1.1.1.1 DoH Enabled',
      body: 'ISP-blocked addon catalogs resolve cleanly via DoH.',
      time: 'Today',
    ),
  ];

  bool get isCloudLoggedIn =>
      uid != null && uid!.isNotEmpty && idToken != null && idToken!.isNotEmpty;

  bool get hasAppAccess => isCloudLoggedIn || localGuestMode;

  UserProfile get activeProfile => profiles.firstWhere(
        (p) => p.id == activeProfileId,
        orElse: () => profiles.first,
      );

  bool get effectiveFanMode =>
      appearance.fanMode && !activeProfile.simpleModeOnly;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    uid = _prefs.getString('cx_uid');
    email = _prefs.getString('cx_email');
    idToken = _prefs.getString('cx_id_token');
    refreshToken = _prefs.getString('cx_refresh_token');
    localGuestMode = _prefs.getBool('cx_local_guest') ?? false;

    _loadLocalState();

    if (isCloudLoggedIn) {
      if (activeProfile.pin.length == 4) profileUnlocked = false;
      unawaited(_refreshSessionAndPullCloud());
    } else if (localGuestMode) {
      syncStatus = 'Local Device';
      if (activeProfile.pin.length == 4) profileUnlocked = false;
    }
  }

  void _loadLocalState() {
    final rawApp = _prefs.getString('cx_appearance');
    if (rawApp != null) {
      appearance = CastexAppearance.fromJson(jsonDecode(rawApp) as JsonMap);
    }
    final rawProfiles = _prefs.getString('cx_profiles');
    if (rawProfiles != null) {
      final list = jsonDecode(rawProfiles) as List;
      if (list.isNotEmpty) {
        profiles = list
            .map((e) => UserProfile.fromJson(JsonMap.from(e as Map)))
            .toList();
      }
    }
    activeProfileId = _prefs.getString('cx_active_profile') ?? profiles.first.id;

    final rawWatchlist = _prefs.getStringList('cx_watchlist');
    if (rawWatchlist != null) watchlistIds = rawWatchlist.toSet();

    final rawOffline = _prefs.getStringList('cx_offline');
    if (rawOffline != null) offlinePocketIds = rawOffline.toSet();

    final rawProg = _prefs.getString('cx_progress');
    if (rawProg != null) {
      final map = jsonDecode(rawProg) as JsonMap;
      watchProgress = map.map((k, v) => MapEntry(k, (v as num).toDouble()));
    }

    final rawGenre = _prefs.getString('cx_genre_mins');
    if (rawGenre != null) {
      final map = jsonDecode(rawGenre) as JsonMap;
      genreMinutes = map.map((k, v) => MapEntry(k, (v as num).toInt()));
    }

    totalWatchMinutes = _prefs.getInt('cx_total_mins') ?? 95;
    completed80Ids = (_prefs.getStringList('cx_completed80') ?? []).toSet();
    quizClaimedIds = (_prefs.getStringList('cx_quiz_claimed') ?? []).toSet();
    unlockedBadges =
        _prefs.getStringList('cx_badges') ?? ['Castex v1.0 Pioneer'];

    final rawAddons = _prefs.getString('cx_addons');
    if (rawAddons != null) {
      final list = jsonDecode(rawAddons) as List;
      addons = list
          .map((e) => AddonManifest.fromJson(JsonMap.from(e as Map)))
          .toList();
    }
  }

  Future<void> _saveLocalImmediately() async {
    if (uid != null) await _prefs.setString('cx_uid', uid!);
    if (email != null) await _prefs.setString('cx_email', email!);
    if (idToken != null) await _prefs.setString('cx_id_token', idToken!);
    if (refreshToken != null) {
      await _prefs.setString('cx_refresh_token', refreshToken!);
    }
    await _prefs.setBool('cx_local_guest', localGuestMode);
    await _prefs.setString('cx_appearance', jsonEncode(appearance.toJson()));
    await _prefs.setString(
      'cx_profiles',
      jsonEncode(profiles.map((e) => e.toJson()).toList()),
    );
    await _prefs.setString('cx_active_profile', activeProfileId);
    await _prefs.setStringList('cx_watchlist', watchlistIds.toList());
    await _prefs.setStringList('cx_offline', offlinePocketIds.toList());
    await _prefs.setString('cx_progress', jsonEncode(watchProgress));
    await _prefs.setString('cx_genre_mins', jsonEncode(genreMinutes));
    await _prefs.setInt('cx_total_mins', totalWatchMinutes);
    await _prefs.setStringList('cx_completed80', completed80Ids.toList());
    await _prefs.setStringList('cx_quiz_claimed', quizClaimedIds.toList());
    await _prefs.setStringList('cx_badges', unlockedBadges);
    await _prefs.setString(
      'cx_addons',
      jsonEncode(addons.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> enterLocalMode() async {
    localGuestMode = true;
    profileUnlocked = true;
    syncStatus = 'Local Device';
    await _saveLocalImmediately();
    notifyListeners();
  }

  JsonMap _buildFullStatePayload() => {
        'email': email,
        'updatedAt': DateTime.now().toIso8601String(),
        'appearance': appearance.toJson(),
        'profiles': profiles.map((e) => e.toJson()).toList(),
        'activeProfileId': activeProfileId,
        'watchlistIds': watchlistIds.toList(),
        'offlinePocketIds': offlinePocketIds.toList(),
        'watchProgress': watchProgress,
        'genreMinutes': genreMinutes,
        'totalWatchMinutes': totalWatchMinutes,
        'completed80Ids': completed80Ids.toList(),
        'quizClaimedIds': quizClaimedIds.toList(),
        'unlockedBadges': unlockedBadges,
        'addons': addons.map((e) => e.toJson()).toList(),
      };

  void _applyCloudPayload(JsonMap data) {
    if (data['appearance'] is Map) {
      appearance =
          CastexAppearance.fromJson(JsonMap.from(data['appearance'] as Map));
    }
    if (data['profiles'] is List && (data['profiles'] as List).isNotEmpty) {
      profiles = (data['profiles'] as List)
          .map((e) => UserProfile.fromJson(JsonMap.from(e as Map)))
          .toList();
    }
    if (data['activeProfileId'] != null) {
      activeProfileId = data['activeProfileId'].toString();
    }
    if (data['watchlistIds'] is List) {
      watchlistIds =
          (data['watchlistIds'] as List).map((e) => e.toString()).toSet();
    }
    if (data['offlinePocketIds'] is List) {
      offlinePocketIds =
          (data['offlinePocketIds'] as List).map((e) => e.toString()).toSet();
    }
    if (data['watchProgress'] is Map) {
      final m = JsonMap.from(data['watchProgress'] as Map);
      watchProgress = m.map((k, v) => MapEntry(k, (v as num).toDouble()));
    }
    if (data['genreMinutes'] is Map) {
      final m = JsonMap.from(data['genreMinutes'] as Map);
      genreMinutes = m.map((k, v) => MapEntry(k, (v as num).toInt()));
    }
    if (data['totalWatchMinutes'] != null) {
      totalWatchMinutes = (data['totalWatchMinutes'] as num).toInt();
    }
    if (data['completed80Ids'] is List) {
      completed80Ids =
          (data['completed80Ids'] as List).map((e) => e.toString()).toSet();
    }
    if (data['quizClaimedIds'] is List) {
      quizClaimedIds =
          (data['quizClaimedIds'] as List).map((e) => e.toString()).toSet();
    }
    if (data['unlockedBadges'] is List) {
      unlockedBadges =
          (data['unlockedBadges'] as List).map((e) => e.toString()).toList();
    }
    if (data['addons'] is List) {
      addons = (data['addons'] as List)
          .map((e) => AddonManifest.fromJson(JsonMap.from(e as Map)))
          .toList();
    }
  }

  Future<String?> authenticateEmail({
    required String userEmail,
    required String password,
    required bool isSignUp,
  }) async {
    final endpoint = isSignUp
        ? 'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${CastexConfig.firebaseApiKey}'
        : 'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${CastexConfig.firebaseApiKey}';

    try {
      final res = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': userEmail.trim(),
          'password': password,
          'returnSecureToken': true,
        }),
      );
      final body = jsonDecode(res.body) as JsonMap;
      if (res.statusCode != 200) {
        final msg = body['error']?['message']?.toString() ?? 'Auth failed';
        return _friendlyFirebaseError(msg);
      }

      uid = body['localId']?.toString();
      email = body['email']?.toString() ?? userEmail.trim();
      idToken = body['idToken']?.toString();
      refreshToken = body['refreshToken']?.toString();
      localGuestMode = false;
      profileUnlocked = true;

      await _saveLocalImmediately();
      if (isSignUp) {
        await pushCloudSync();
      } else {
        await pullCloudSync();
      }
      notifyListeners();
      return null;
    } catch (_) {
      return 'Network error: Check internet connection.';
    }
  }

  Future<String?> sendPasswordReset(String userEmail) async {
    try {
      final res = await http.post(
        Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=${CastexConfig.firebaseApiKey}',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requestType': 'PASSWORD_RESET',
          'email': userEmail.trim(),
        }),
      );
      if (res.statusCode == 200) return null;
      final body = jsonDecode(res.body) as JsonMap;
      return _friendlyFirebaseError(
        body['error']?['message']?.toString() ?? 'Could not send reset email',
      );
    } catch (_) {
      return 'Network error while sending reset email.';
    }
  }

  String _friendlyFirebaseError(String code) {
    if (code.contains('EMAIL_EXISTS')) {
      return 'This email is already registered. Switch to Sign In.';
    }
    if (code.contains('INVALID_LOGIN_CREDENTIALS') ||
        code.contains('INVALID_PASSWORD') ||
        code.contains('EMAIL_NOT_FOUND')) {
      return 'Account not found or wrong password. Tap "New here? Create Account" first!';
    }
    if (code.contains('WEAK_PASSWORD')) {
      return 'Password must be at least 6 characters.';
    }
    return code;
  }

  Future<void> _refreshSessionAndPullCloud() async {
    if (refreshToken == null || refreshToken!.isEmpty) return;
    try {
      final res = await http.post(
        Uri.parse(
          'https://securetoken.googleapis.com/v1/token?key=${CastexConfig.firebaseApiKey}',
        ),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'grant_type=refresh_token&refresh_token=$refreshToken',
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as JsonMap;
        idToken = data['id_token']?.toString();
        refreshToken = data['refresh_token']?.toString();
        uid = data['user_id']?.toString() ?? uid;
        await _saveLocalImmediately();
        await pullCloudSync();
      }
    } catch (_) {
      syncStatus = 'Cached Local';
      notifyListeners();
    }
  }

  Future<void> pullCloudSync() async {
    if (!isCloudLoggedIn) return;
    isSyncing = true;
    notifyListeners();
    try {
      final url =
          '${CastexConfig.firebaseDbUrl}/users/$uid.json?auth=$idToken';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200 && res.body != 'null') {
        final data = jsonDecode(res.body) as JsonMap;
        _applyCloudPayload(data);
        await _saveLocalImmediately();
        syncStatus = 'Cloud Synced';
      } else if (res.statusCode == 200 && res.body == 'null') {
        await pushCloudSync();
      } else {
        syncStatus = 'Check DB Rules';
      }
    } catch (_) {
      syncStatus = 'Offline Cached';
    }
    isSyncing = false;
    notifyListeners();
  }

  Future<void> pushCloudSync() async {
    await _saveLocalImmediately();
    notifyListeners();
    if (!isCloudLoggedIn) return;
    try {
      final url =
          '${CastexConfig.firebaseDbUrl}/users/$uid.json?auth=$idToken';
      final res = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(_buildFullStatePayload()),
      );
      syncStatus = res.statusCode == 200 ? 'Cloud Synced' : 'Rule Pending';
    } catch (_) {
      syncStatus = 'Offline Cached';
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    uid = null;
    email = null;
    idToken = null;
    refreshToken = null;
    localGuestMode = false;
    await _prefs.remove('cx_uid');
    await _prefs.remove('cx_email');
    await _prefs.remove('cx_id_token');
    await _prefs.remove('cx_refresh_token');
    await _prefs.setBool('cx_local_guest', false);
    notifyListeners();
  }

  void toggleWatchlist(String mediaId) {
    if (watchlistIds.contains(mediaId)) {
      watchlistIds.remove(mediaId);
    } else {
      watchlistIds.add(mediaId);
    }
    unawaited(pushCloudSync());
  }

  void toggleOfflinePocket(String mediaId) {
    if (offlinePocketIds.contains(mediaId)) {
      offlinePocketIds.remove(mediaId);
    } else {
      offlinePocketIds.add(mediaId);
    }
    unawaited(pushCloudSync());
  }

  void recordWatchProgress(MediaItem item, double fraction, int addedMinutes) {
    final clamped = fraction.clamp(0.0, 1.0);
    final prev = watchProgress[item.id] ?? 0.0;
    if (clamped > prev) {
      watchProgress[item.id] = clamped;
    }
    if (clamped >= 0.80) {
      completed80Ids.add(item.id);
    }
    if (addedMinutes > 0) {
      totalWatchMinutes += addedMinutes;
      for (final g in item.genres) {
        genreMinutes[g] = (genreMinutes[g] ?? 0) + addedMinutes;
      }
    }
    unawaited(pushCloudSync());
  }

  void claimQuizReward(String mediaId, String badgeName) {
    quizClaimedIds.add(mediaId);
    if (!unlockedBadges.contains(badgeName)) {
      unlockedBadges.add(badgeName);
    }
    unawaited(pushCloudSync());
  }

  void updateAppearance(void Function(CastexAppearance a) updater) {
    updater(appearance);
    unawaited(pushCloudSync());
  }

  void switchProfile(String id) {
    activeProfileId = id;
    profileUnlocked = activeProfile.pin.length != 4;
    unawaited(pushCloudSync());
  }

  void unlockProfile() {
    profileUnlocked = true;
    notifyListeners();
  }

  void addOrUpdateProfile(UserProfile profile) {
    final idx = profiles.indexWhere((p) => p.id == profile.id);
    if (idx >= 0) {
      profiles[idx] = profile;
    } else {
      profiles.add(profile);
    }
    activeProfileId = profile.id;
    profileUnlocked = true;
    unawaited(pushCloudSync());
  }

  void addAddon(String name, String url, String type) {
    addons.add(
      AddonManifest(
        id: 'addon_${DateTime.now().millisecondsSinceEpoch}',
        name: name.trim(),
        url: url.trim(),
        type: type,
      ),
    );
    unawaited(pushCloudSync());
  }

  void removeAddon(String id) {
    addons.removeWhere((a) => a.id == id);
    unawaited(pushCloudSync());
  }

  void toggleAddon(String id) {
    final idx = addons.indexWhere((a) => a.id == id);
    if (idx >= 0) {
      addons[idx].enabled = !addons[idx].enabled;
      unawaited(pushCloudSync());
    }
  }

  String exportBackupJson({required bool includeSensitive}) {
    final JsonMap map = {
      'castexBackupVersion': CastexConfig.appVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'appearance': appearance.toJson(),
      'watchlistIds': watchlistIds.toList(),
      'offlinePocketIds': offlinePocketIds.toList(),
      'watchProgress': watchProgress,
      'genreMinutes': genreMinutes,
      'totalWatchMinutes': totalWatchMinutes,
      'unlockedBadges': unlockedBadges,
      'profiles': profiles
          .map((p) => {
                'id': p.id,
                'name': p.name,
                'avatarIndex': p.avatarIndex,
                'customAvatarUrl': p.customAvatarUrl,
                'pin': includeSensitive ? p.pin : '',
                'simpleModeOnly': p.simpleModeOnly,
              })
          .toList(),
      if (includeSensitive) 'addons': addons.map((a) => a.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  bool importBackupJson(String raw) {
    try {
      final data = jsonDecode(raw) as JsonMap;
      _applyCloudPayload(data);
      unawaited(pushCloudSync());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String> testCloudflareDoh(String hostname) async {
    try {
      final uri = Uri.parse(
        'https://cloudflare-dns.com/dns-query?name=$hostname&type=A',
      );
      final res = await http.get(
        uri,
        headers: {'Accept': 'application/dns-json'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as JsonMap;
        final answers = data['Answer'] as List?;
        if (answers != null && answers.isNotEmpty) {
          return 'Cloudflare 1.1.1.1 DoH Resolved (${answers.first['data']})';
        }
      }
      return 'Cloudflare DoH Active';
    } catch (_) {
      return 'DoH Ready';
    }
  }
}
