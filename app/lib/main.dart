import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

typedef JsonMap = Map<String,dynamic>;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  final controller = CastexController();
  await controller.init();
  runApp(CastexApp(controller: controller));
}

// ============================================================================
// 1. CORE CONFIGURATION (PRE-CONFIGURED WITH YOUR FIREBASE & KOTOSUB)
// ============================================================================
class CastexConfig {
  static const String appVersion = '1.0.0-flagship';
  static const String firebaseApiKey =
      'AIzaSyCgbpacxuwoJgwneGFlk_Vln4nWgnZ4FCc';
  static const String firebaseDbUrl =
      'https://castex-app-2eb5b-default-rtdb.asia-southeast1.firebasedatabase.app';
  static const String kotoSubServerUrl = 'https://sub-bot-act8.onrender.com';
  static const String defaultCinemetaUrl =
      'https://v3-cinemeta.strem.io/manifest.json';
}

// ============================================================================
// 2. THEME, LIQUID GLASS & CUSTOMIZATION MODEL
// ============================================================================
class CastexAppearance {
  String accentHex;
  bool amoledBlack;
  String glassSurface; // Liquid, Frosted, Clear, Solid
  double blurRadius;
  double tintOpacity;
  String edgeGlow; // Off, Subtle, Balanced, Bold
  bool autoPosterAura;
  String dockMode; // Adaptive, Expanded, Compact
  double dockRadius;
  bool liquidLens;
  bool fanMode;
  bool spoilerShield;
  bool cloudflareDns;
  bool autoNextEpisode;
  String defaultSubLang; // Hinglish, Bangla, Banglish, English
  bool dualSubtitles;
  double subFontSize;
  double subBgOpacity;

  CastexAppearance({
    this.accentHex = '#E50914',
    this.amoledBlack = true,
    this.glassSurface = 'Liquid',
    this.blurRadius = 18.0,
    this.tintOpacity = 0.62,
    this.edgeGlow = 'Balanced',
    this.autoPosterAura = true,
    this.dockMode = 'Adaptive',
    this.dockRadius = 32.0,
    this.liquidLens = true,
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
      return const Color(0xFFE50914);
    }
  }

  Color get bgColor =>
      amoledBlack ? const Color(0xFF000000) : const Color(0xFF0B0D12);

  Color get cardColor =>
      amoledBlack ? const Color(0xFF0E1015) : const Color(0xFF151922);

  double get glowStrength {
    switch (edgeGlow) {
      case 'Off':
        return 0.0;
      case 'Subtle':
        return 0.25;
      case 'Bold':
        return 0.72;
      default:
        return 0.45;
    }
  }

  JsonMap toJson() => {
        'accentHex': accentHex,
        'amoledBlack': amoledBlack,
        'glassSurface': glassSurface,
        'blurRadius': blurRadius,
        'tintOpacity': tintOpacity,
        'edgeGlow': edgeGlow,
        'autoPosterAura': autoPosterAura,
        'dockMode': dockMode,
        'dockRadius': dockRadius,
        'liquidLens': liquidLens,
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
      accentHex: json['accentHex']?.toString() ?? '#E50914',
      amoledBlack: json['amoledBlack'] ?? true,
      glassSurface: json['glassSurface']?.toString() ?? 'Liquid',
      blurRadius: (json['blurRadius'] as num?)?.toDouble() ?? 18.0,
      tintOpacity: (json['tintOpacity'] as num?)?.toDouble() ?? 0.62,
      edgeGlow: json['edgeGlow']?.toString() ?? 'Balanced',
      autoPosterAura: json['autoPosterAura'] ?? true,
      dockMode: json['dockMode']?.toString() ?? 'Adaptive',
      dockRadius: (json['dockRadius'] as num?)?.toDouble() ?? 32.0,
      liquidLens: json['liquidLens'] ?? true,
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
    final surf = glassSurface.isNotEmpty ? glassSurface[0].toUpperCase() : 'L';
    final glow = edgeGlow.isNotEmpty ? edgeGlow[0].toUpperCase() : 'B';
    return 'CX-$hex-$surf$glow';
  }

  bool applyPresetCode(String raw) {
    final code = raw.trim().toUpperCase();
    if (code == 'CX-CYBERPUNK') {
      accentHex = '#00F5D4';
      glassSurface = 'Liquid';
      edgeGlow = 'Bold';
      blurRadius = 22.0;
      return true;
    }
    if (code == 'CX-GHIBLI') {
      accentHex = '#F59E0B';
      glassSurface = 'Frosted';
      edgeGlow = 'Subtle';
      blurRadius = 16.0;
      return true;
    }
    final parts = code.split('-');
    if (parts.length == 3 && parts[0] == 'CX' && parts[1].length == 6) {
      accentHex = '#${parts[1]}';
      if (parts[2].isNotEmpty) {
        final s = parts[2][0];
        glassSurface = s == 'F'
            ? 'Frosted'
            : s == 'C'
                ? 'Clear'
                : s == 'S'
                    ? 'Solid'
                    : 'Liquid';
      }
      if (parts[2].length > 1) {
        final g = parts[2][1];
        edgeGlow = g == 'O'
            ? 'Off'
            : g == 'S'
                ? 'Subtle'
                : g == 'B'
                    ? 'Bold'
                    : 'Balanced';
      }
      return true;
    }
    return false;
  }
}

// ============================================================================
// 3. USER PROFILE & BUILT-IN AVATAR STUDIO (20 AVATARS)
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
    AvatarPreset(Icons.bolt_rounded, 0xFFE50914, 0xFF7F0000),
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
        boxShadow: [
          BoxShadow(
            color: Color(preset.c1).withOpacity(0.35),
            blurRadius: 10,
          ),
        ],
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
// 4. MEDIA, EPISODE, STREAM, QUIZ & ADDON MODELS
// ============================================================================
class QuizQuestion {
  final String question;
  final String optionA;
  final String optionB;
  final String optionC;
  final String correctOption; // 'a', 'b', or 'c'

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

class SubtitleCue {
  final String en;
  final String hinglish;
  final String bangla;
  final String banglish;

  const SubtitleCue({
    required this.en,
    required this.hinglish,
    required this.bangla,
    required this.banglish,
  });

  String byLang(String lang) {
    if (lang == 'Bangla') return bangla;
    if (lang == 'Banglish') return banglish;
    if (lang == 'English') return en;
    return hinglish;
  }
}

class StreamSource {
  final String id;
  final String title;
  final String quality;
  final String dubLayer;
  final String language;
  final String provider;
  final String url;

  const StreamSource({
    required this.id,
    required this.title,
    required this.quality,
    required this.dubLayer,
    required this.language,
    required this.provider,
    required this.url,
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
  final String type;
  final String year;
  final double rating;
  final int? rankToday;
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
    this.rankToday,
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
// 5. CURATED BUILT-IN SHOWCASE CATALOG
// ============================================================================
class CastexCatalog {
  static const String _stream1080 =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4';
  static const String _streamAnimeDemo =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4';
  static const String _streamActionDemo =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';

  static final List<MediaItem> items = [
    MediaItem(
      id: 'cx_jjk_s2',
      title: 'Jujutsu Kaisen: Shibuya Incident',
      type: 'Anime',
      year: '2026',
      rating: 9.4,
      rankToday: 1,
      qualityBadge: '4K HDR',
      studio: 'Crunchyroll',
      genres: ['Anime', 'Action', 'Supernatural'],
      auraColor: const Color(0xFF9D4EDD),
      posterUrl:
          'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=600&q=80',
      backdropUrl:
          'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=1200&q=80',
      overview:
          'October 31st in Shibuya: special grade curses erect a veil trapping civilians as Satoru Gojo steps into an ambush designed to seal the strongest sorcerer.',
      aiRecap:
          'Previously: Yuji Itadori mastered Black Flash alongside Nobara and Megumi. Meanwhile, Geto and Mahito collected Sukuna fingers to spring the Shibuya Prison Realm trap.',
      episodes: [
        EpisodeItem(
          id: 'jjk_e1',
          season: 2,
          number: 1,
          title: 'The Curtain Falls Over Shibuya',
          synopsis:
              'Multiple veils descend across Shibuya Station as sorcerers are split into underground strike teams.',
          thumbnailUrl:
              'https://images.unsplash.com/photo-1541562232579-512a21360020?w=800&q=80',
          duration: '24m',
          rating: 9.2,
          canonTag: 'CANON',
          streams: [
            StreamSource(
              id: 's1',
              title: 'Castex Direct • 1080p HEVC [Dual Audio]',
              quality: '1080p',
              dubLayer: 'Original Audio',
              language: 'Japanese + KotoSub',
              provider: 'Castex Core',
              url: _streamAnimeDemo,
            ),
            StreamSource(
              id: 's2',
              title: 'Crunchyroll Official Hindi/English Dub',
              quality: '1080p',
              dubLayer: 'Official Dub',
              language: 'Hindi / English',
              provider: 'Official Dub Router',
              url: _stream1080,
            ),
            StreamSource(
              id: 's3',
              title: 'Bengal Anime Fandub Studio [0.000s Sync]',
              quality: '1080p',
              dubLayer: 'Community Fandub',
              language: 'Bangla Fandub',
              provider: 'Verified Community',
              url: _streamActionDemo,
            ),
          ],
        ),
        EpisodeItem(
          id: 'jjk_e2',
          season: 2,
          number: 2,
          title: '0.2 Seconds Domain Expansion',
          synopsis:
              'Surrounded by transfigured humans in B5F, Gojo unleashes Unlimited Void for a fraction of a second.',
          thumbnailUrl:
              'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=800&q=80',
          duration: '24m',
          rating: 9.8,
          canonTag: 'CANON',
          streams: [
            StreamSource(
              id: 's4',
              title: 'Castex Direct • 4K Upscaled [KotoSub Ready]',
              quality: '4K HDR',
              dubLayer: 'Original Audio',
              language: 'Japanese + KotoSub',
              provider: 'Castex Core',
              url: _stream1080,
            ),
          ],
        ),
        EpisodeItem(
          id: 'jjk_e3',
          season: 2,
          number: 3,
          title: 'Shibuya Side-Story: Sorcerer Briefing',
          synopsis:
              'Tactical recap of Tokyo & Kyoto Jujutsu High teams before entering the subway.',
          thumbnailUrl:
              'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800&q=80',
          duration: '22m',
          rating: 7.4,
          canonTag: 'FILLER',
          streams: [
            StreamSource(
              id: 's5',
              title: 'Castex Direct • 1080p',
              quality: '1080p',
              dubLayer: 'Original Audio',
              language: 'Japanese',
              provider: 'Castex Core',
              url: _streamAnimeDemo,
            ),
          ],
        ),
      ],
      quizQuestions: [
        QuizQuestion(
          question:
              'How long did Satoru Gojo activate Unlimited Void in Shibuya B5F?',
          optionA: '0.2 Seconds',
          optionB: '2.0 Seconds',
          optionC: '0.02 Seconds',
          correctOption: 'a',
        ),
      ],
    ),
    MediaItem(
      id: 'cx_tears_steel',
      title: 'Tears of Steel: Cyber Protocol',
      type: 'Movie',
      year: '2026',
      rating: 8.9,
      rankToday: 2,
      qualityBadge: '4K',
      studio: 'Netflix',
      genres: ['Sci-Fi', 'Action', 'Cyberpunk'],
      auraColor: const Color(0xFF00D4FF),
      posterUrl:
          'https://images.unsplash.com/photo-1535223289827-42f1e9919769?w=600&q=80',
      backdropUrl:
          'https://images.unsplash.com/photo-1515630278258-407f66498911?w=1200&q=80',
      overview:
          'In a dystopian Amsterdam ruled by rogue synthetic intelligence, a team of resistance engineers attempts a memory-bridge experiment to save humanity.',
      aiRecap:
          'Feature Film: Thom and Celia parted ways years ago—now the dome shield around Amsterdam is failing as robotic sentinels breach the perimeter.',
      episodes: [
        EpisodeItem(
          id: 'tos_m1',
          season: 1,
          number: 1,
          title: 'Full Movie • Director Master',
          synopsis:
              'Complete feature presentation with KotoSub Hinglish/Bangla Dual Subtitles and Hybrid Dub Router.',
          thumbnailUrl:
              'https://images.unsplash.com/photo-1515630278258-407f66498911?w=800&q=80',
          duration: '12m',
          rating: 8.9,
          canonTag: 'CANON',
          streams: [
            StreamSource(
              id: 'tos_s1',
              title: 'Castex Ultra • 1080p Master [Zero-Buffer]',
              quality: '1080p',
              dubLayer: 'Original Audio',
              language: 'English + KotoSub',
              provider: 'Castex Core',
              url: _stream1080,
            ),
            StreamSource(
              id: 'tos_s2',
              title: 'Community Hinglish Fandub Layer',
              quality: '1080p',
              dubLayer: 'Community Fandub',
              language: 'Hinglish Fandub',
              provider: 'Indie Fandub Hub',
              url: _streamActionDemo,
            ),
          ],
        ),
      ],
      quizQuestions: [
        QuizQuestion(
          question: 'Which European city serves as the setting for Tears of Steel?',
          optionA: 'Tokyo',
          optionB: 'Amsterdam',
          optionC: 'Berlin',
          correctOption: 'b',
        ),
      ],
    ),
    MediaItem(
      id: 'cx_sintel_chronicles',
      title: 'Sintel: Last Dragon Rider',
      type: 'Anime',
      year: '2026',
      rating: 9.1,
      rankToday: 3,
      qualityBadge: '1080p',
      studio: 'Muse India',
      genres: ['Anime', 'Fantasy', 'Adventure'],
      auraColor: const Color(0xFFE50914),
      posterUrl:
          'https://images.unsplash.com/photo-1514539079130-25950c84af65?w=600&q=80',
      backdropUrl:
          'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=1200&q=80',
      overview:
          'A lone warrior crosses frozen mountain peaks and ancient temple ruins searching for Scales, the young dragon taken from her.',
      aiRecap:
          'Previously: After nursing an injured baby dragon back to health in the capital city, Sintel watched a towering elder dragon snatch Scales into the clouds.',
      episodes: [
        EpisodeItem(
          id: 'sin_e1',
          season: 1,
          number: 1,
          title: 'The Frozen Citadel',
          synopsis:
              'Sintel battles shadow guardians guarding the mountain sanctuary.',
          thumbnailUrl:
              'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=800&q=80',
          duration: '15m',
          rating: 9.1,
          canonTag: 'CANON',
          streams: [
            StreamSource(
              id: 'sin_s1',
              title: 'Muse Asia / Castex 1080p [KotoSub Sync]',
              quality: '1080p',
              dubLayer: 'Official Dub',
              language: 'English / Hinglish Sub',
              provider: 'Muse Hub',
              url: _streamAnimeDemo,
            ),
          ],
        ),
      ],
      quizQuestions: [
        QuizQuestion(
          question: 'What is the name of the baby dragon Sintel searches for?',
          optionA: 'Scales',
          optionB: 'Ignis',
          optionC: 'Draco',
          correctOption: 'a',
        ),
      ],
    ),
    MediaItem(
      id: 'cx_marvel_void',
      title: 'Doomsday: Multiverse Zero',
      type: 'Series',
      year: '2026',
      rating: 9.3,
      rankToday: 4,
      qualityBadge: '4K HDR',
      studio: 'Marvel',
      genres: ['Action', 'Sci-Fi', 'Thriller'],
      auraColor: const Color(0xFF10B981),
      posterUrl:
          'https://images.unsplash.com/photo-1635805737707-575885ab0820?w=600&q=80',
      backdropUrl:
          'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=1200&q=80',
      overview:
          'As incursions collapse Earth-818 into the Void, rogue variants assemble an unstable alliance against Doctor Doom.',
      aiRecap:
          'Previously: The TVA detected temporal decay across three anchor timelines while Superior tech signatures emerged in Latveria.',
      episodes: [
        EpisodeItem(
          id: 'mv_e1',
          season: 1,
          number: 1,
          title: 'Incursion Point',
          synopsis:
              'Two Earths collide in the upper atmosphere as heroes race to stabilize the quantum bridge.',
          thumbnailUrl:
              'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=800&q=80',
          duration: '46m',
          rating: 9.3,
          canonTag: 'CANON',
          streams: [
            StreamSource(
              id: 'mv_s1',
              title: 'Castex 4K Dolby Vision [Multi-Audio]',
              quality: '4K HDR',
              dubLayer: 'Official Dub',
              language: 'English / Hindi',
              provider: 'Disney+ / Castex',
              url: _streamActionDemo,
            ),
          ],
        ),
      ],
      quizQuestions: [
        QuizQuestion(
          question: 'What phenomenon threatens to collapse the timelines?',
          optionA: 'Incursions',
          optionB: 'Solar Flares',
          optionC: 'Wormhole Drift',
          correctOption: 'a',
        ),
      ],
    ),
  ];
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
  bool isSyncing = false;
  String syncStatus = 'Offline Local';

  CastexAppearance appearance = CastexAppearance();
  List<UserProfile> profiles = [
    UserProfile(id: 'p_main', name: 'Main Viewer', avatarIndex: 0),
  ];
  String activeProfileId = 'p_main';
  bool profileUnlocked = true;

  Set<String> watchlistIds = {'cx_jjk_s2', 'cx_tears_steel'};
  Set<String> offlinePocketIds = {'cx_sintel_chronicles'};
  Map<String, double> watchProgress = {'cx_jjk_s2': 0.45};
  Map<String, int> genreMinutes = {
    'Anime': 140,
    'Action': 110,
    'Sci-Fi': 75,
    'Fantasy': 45,
  };
  int totalWatchMinutes = 370;
  Set<String> completed80Ids = {};
  Set<String> quizClaimedIds = {};
  List<String> unlockedBadges = ['Early Flagship Builder'];
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
      name: 'KotoSub AI Hinglish/Bangla Engine',
      url: CastexConfig.kotoSubServerUrl,
      type: 'AI Subtitle Engine',
      enabled: true,
    ),
  ];

  final List<AppNotification> notifications = const [
    AppNotification(
      title: 'Castex v1.0.0 Flagship Live',
      body:
          'Liquid Glass UI, Firebase Cloud Sync, KotoSub Dual Subtitles & Hybrid Dub Router active.',
      time: 'Just now',
    ),
    AppNotification(
      title: 'Cloudflare DNS Bypass Active',
      body:
          'ISP-blocked Stremio addons now route via Cloudflare 1.1.1.1 DoH automatically.',
      time: 'Today',
    ),
  ];

  bool get isLoggedIn =>
      uid != null && uid!.isNotEmpty && idToken != null && idToken!.isNotEmpty;

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

    _loadLocalState();

    if (isLoggedIn) {
      if (activeProfile.pin.length == 4) {
        profileUnlocked = false;
      }
      unawaited(_refreshSessionAndPullCloud());
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

    totalWatchMinutes = _prefs.getInt('cx_total_mins') ?? 370;
    completed80Ids =
        (_prefs.getStringList('cx_completed80') ?? []).toSet();
    quizClaimedIds =
        (_prefs.getStringList('cx_quiz_claimed') ?? []).toSet();
    unlockedBadges =
        _prefs.getStringList('cx_badges') ?? ['Early Flagship Builder'];

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
      appearance = CastexAppearance.fromJson(
        JsonMap.from(data['appearance'] as Map),
      );
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
      return 'Wrong email or password.';
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
    if (!isLoggedIn) return;
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
    if (!isLoggedIn) return;
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
    await _prefs.remove('cx_uid');
    await _prefs.remove('cx_email');
    await _prefs.remove('cx_id_token');
    await _prefs.remove('cx_refresh_token');
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

  void toggleAddon(String id) {
    final idx = addons.indexWhere((a) => a.id == id);
    if (idx >= 0) {
      addons[idx].enabled = !addons[idx].enabled;
      unawaited(pushCloudSync());
    }
  }

  void removeAddon(String id) {
    addons.removeWhere((a) => a.id == id);
    unawaited(pushCloudSync());
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
      if (includeSensitive)
        'addons': addons.map((a) => a.toJson()).toList(),
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
          return 'Cloudflare 1.1.1.1 Resolved: ${answers.first['data']}';
        }
      }
      return 'Cloudflare DoH Active (Ready)';
    } catch (_) {
      return 'DoH Standby (Check Network)';
    }
  }
}

// ============================================================================
// 7. ROOT APP & LIQUID GLASS HELPERS
// ============================================================================
class CastexApp extends StatelessWidget {
  final CastexController controller;
  const CastexApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final app = controller.appearance;
        return MaterialApp(
          title: 'Castex',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: app.bgColor,
            colorScheme: ColorScheme.dark(
              primary: app.accentColor,
              secondary: app.accentColor,
              surface: app.cardColor,
            ),
            cardColor: app.cardColor,
            dialogBackgroundColor: const Color(0xFF12141B),
          ),
          home: !controller.isLoggedIn
              ? AuthGateScreen(controller: controller)
              : !controller.profileUnlocked
                  ? ProfilePinGateScreen(controller: controller)
                  : MainShellScreen(controller: controller),
        );
      },
    );
  }
}

class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final CastexAppearance appearance;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? customTint;

  const LiquidGlassCard({
    super.key,
    required this.child,
    required this.appearance,
    this.borderRadius,
    this.padding,
    this.customTint,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(20);
    final isSolid = appearance.glassSurface == 'Solid';
    final blur = isSolid
        ? 0.0
        : appearance.glassSurface == 'Clear'
            ? appearance.blurRadius * 0.5
            : appearance.blurRadius;
    final opacity = isSolid
        ? 0.96
        : appearance.glassSurface == 'Clear'
            ? (appearance.tintOpacity * 0.45).clamp(0.15, 0.85)
            : appearance.tintOpacity;

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            color: (customTint ?? const Color(0xFF141720)).withOpacity(opacity),
            border: Border.all(
              color: Colors.white.withOpacity(
                appearance.edgeGlow == 'Off' ? 0.06 : 0.16,
              ),
              width: 1,
            ),
            gradient: appearance.glassSurface == 'Liquid'
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.14),
                      Colors.white.withOpacity(0.02),
                    ],
                  )
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

// ============================================================================
// 8. FIREBASE EMAIL + PASSWORD LOGIN & SIGNUP GATE
// ============================================================================
class AuthGateScreen extends StatefulWidget {
  final CastexController controller;
  const AuthGateScreen({super.key, required this.controller});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isSignUp = false;
  bool _loading = false;
  bool _obscure = true;
  String? _errorMsg;

  Future<void> _submit() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.length < 6) {
      setState(() {
        _errorMsg = 'Enter a valid email and 6+ character password.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    final err = await widget.controller.authenticateEmail(
      userEmail: _emailCtrl.text,
      password: _passCtrl.text,
      isSignUp: _isSignUp,
    );
    if (mounted) {
      setState(() {
        _loading = false;
        _errorMsg = err;
      });
    }
  }

  Future<void> _forgotPassword() async {
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Enter your email above first to reset.');
      return;
    }
    final err = await widget.controller.sendPasswordReset(_emailCtrl.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          err ?? 'Password reset link sent to ${_emailCtrl.text.trim()}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.controller.appearance;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: app.accentColor.withOpacity(0.28),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: LiquidGlassCard(
                  appearance: app,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_circle_filled_rounded,
                              color: app.accentColor, size: 34),
                          const SizedBox(width: 10),
                          const Text(
                            'CASTEX',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isSignUp
                            ? 'Create Cloud Sync Account'
                            : 'Sign In • Persistent Cloud Profile',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.68),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: const Icon(Icons.email_outlined),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Password (min 6 chars)',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      if (_errorMsg != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMsg!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: app.accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isSignUp ? 'Create Account' : 'Sign In',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => setState(() {
                              _isSignUp = !_isSignUp;
                              _errorMsg = null;
                            }),
                            child: Text(
                              _isSignUp
                                  ? 'Already have an account? Sign In'
                                  : 'New here? Create Account',
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                          if (!_isSignUp)
                            TextButton(
                              onPressed: _forgotPassword,
                              child: const Text(
                                'Reset PIN/Pass',
                                style: TextStyle(fontSize: 12.5),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 9. PROFILE 4-DIGIT PIN GATE
// ============================================================================
class ProfilePinGateScreen extends StatefulWidget {
  final CastexController controller;
  const ProfilePinGateScreen({super.key, required this.controller});

  @override
  State<ProfilePinGateScreen> createState() => _ProfilePinGateScreenState();
}

class _ProfilePinGateScreenState extends State<ProfilePinGateScreen> {
  final _pinCtrl = TextEditingController();
  String? _err;

  @override
  Widget build(BuildContext context) {
    final profile = widget.controller.activeProfile;
    final app = widget.controller.appearance;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AvatarWidget(
                  profile: profile,
                  size: 84,
                  showBorder: true,
                  borderColor: app.accentColor,
                ),
                const SizedBox(height: 14),
                Text(
                  profile.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter 4-Digit Profile PIN',
                  style: TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _pinCtrl,
                    maxLength: 4,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 24,
                      letterSpacing: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    onChanged: (val) {
                      if (val.length == 4) {
                        if (val == profile.pin) {
                          widget.controller.unlockProfile();
                        } else {
                          setState(() {
                            _err = 'Incorrect PIN';
                            _pinCtrl.clear();
                          });
                        }
                      }
                    },
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                if (_err != null) ...[
                  const SizedBox(height: 8),
                  Text(_err!, style: const TextStyle(color: Colors.redAccent)),
                ],
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  children: widget.controller.profiles.map((p) {
                    return ActionChip(
                      avatar: AvatarWidget(profile: p, size: 22),
                      label: Text(p.name),
                      onPressed: () => widget.controller.switchProfile(p.id),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 10. MAIN SHELL WITH FLOATING LIQUID GLASS PILL DOCK & POSTER AURA
// ============================================================================
class MainShellScreen extends StatefulWidget {
  final CastexController controller;
  const MainShellScreen({super.key, required this.controller});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _tabIndex = 0;
  bool _dockCompact = false;
  Color _activeAura = const Color(0xFF9D4EDD);

  void _onScroll(double offset) {
    if (widget.controller.appearance.dockMode != 'Adaptive') return;
    final shouldCompact = offset > 90;
    if (shouldCompact != _dockCompact) {
      setState(() => _dockCompact = shouldCompact);
    }
  }

  void _showNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E1016),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Castex Announcements',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...widget.controller.notifications.map(
              (n) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: widget.controller.appearance.accentColor
                      .withOpacity(0.2),
                  child: Icon(
                    Icons.campaign_rounded,
                    color: widget.controller.appearance.accentColor,
                  ),
                ),
                title: Text(n.title),
                subtitle: Text(
                  n.body,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                trailing: Text(
                  n.time,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.controller.appearance;
    final aura = app.autoPosterAura ? _activeAura : app.accentColor;

    return Scaffold(
      backgroundColor: app.bgColor,
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            height: 360,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.7),
                radius: 1.1,
                colors: [
                  aura.withOpacity(0.32),
                  app.bgColor.withOpacity(0.0),
                ],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.play_circle_filled_rounded,
                          color: app.accentColor, size: 26),
                      const SizedBox(width: 8),
                      const Text(
                        'CASTEX',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 19,
                          letterSpacing: 2.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.controller.syncStatus,
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => widget.controller.updateAppearance(
                          (a) => a.fanMode = !a.fanMode,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: widget.controller.effectiveFanMode
                                ? app.accentColor.withOpacity(0.22)
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: widget.controller.effectiveFanMode
                                  ? app.accentColor
                                  : Colors.white24,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                widget.controller.effectiveFanMode
                                    ? Icons.auto_awesome
                                    : Icons.tv_rounded,
                                size: 13,
                                color: widget.controller.effectiveFanMode
                                    ? app.accentColor
                                    : Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.controller.effectiveFanMode
                                    ? 'Fan Mode'
                                    : 'Simple',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Stack(
                          children: [
                            const Icon(Icons.notifications_none_rounded),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: app.accentColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                        onPressed: _showNotificationsSheet,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _tabIndex,
                    children: [
                      HomeTab(
                        controller: widget.controller,
                        onScroll: _onScroll,
                        onAuraChanged: (c) {
                          if (_activeAura != c) {
                            setState(() => _activeAura = c);
                          }
                        },
                      ),
                      SearchTab(controller: widget.controller),
                      LibraryTab(controller: widget.controller),
                      ProfileAndSettingsTab(controller: widget.controller),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Center(
              child: _buildFloatingLiquidDock(app),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingLiquidDock(CastexAppearance app) {
    final compact = app.dockMode == 'Compact' ||
        (app.dockMode == 'Adaptive' && _dockCompact);

    const icons = [
      Icons.home_rounded,
      Icons.search_rounded,
      Icons.bookmarks_rounded,
      Icons.person_rounded,
    ];
    const labels = ['Home', 'Search', 'Library', 'Profile'];

    return LiquidGlassCard(
      appearance: app,
      borderRadius: BorderRadius.circular(app.dockRadius),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 7 : 9,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(icons.length, (i) {
          final selected = _tabIndex == i;
          final isProfile = i == 3;
          return GestureDetector(
            onTap: () => setState(() => _tabIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: EdgeInsets.symmetric(
                horizontal: selected && !compact ? 14 : 11,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(app.dockRadius),
                color: selected
                    ? app.accentColor.withOpacity(app.liquidLens ? 0.28 : 0.18)
                    : Colors.transparent,
                border: selected && app.liquidLens
                    ? Border.all(
                        color: app.accentColor.withOpacity(0.65),
                        width: 1,
                      )
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isProfile)
                    AvatarWidget(
                      profile: widget.controller.activeProfile,
                      size: 22,
                      showBorder: selected,
                      borderColor: app.accentColor,
                    )
                  else
                    Icon(
                      icons[i],
                      size: selected ? 23 : 21,
                      color: selected ? Colors.white : Colors.white60,
                    ),
                  if (selected && !compact) ...[
                    const SizedBox(width: 7),
                    Text(
                      labels[i],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ============================================================================
// 11. HOME TAB
// ============================================================================
class HomeTab extends StatelessWidget {
  final CastexController controller;
  final void Function(double offset) onScroll;
  final void Function(Color aura) onAuraChanged;

  const HomeTab({
    super.key,
    required this.controller,
    required this.onScroll,
    required this.onAuraChanged,
  });

  @override
  Widget build(BuildContext context) {
    final app = controller.appearance;
    final hero = CastexCatalog.items.first;
    final continueList = CastexCatalog.items
        .where((m) => (controller.watchProgress[m.id] ?? 0) > 0)
        .toList();

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollUpdateNotification) {
          onScroll(n.metrics.pixels);
        }
        return false;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
        children: [
          GestureDetector(
            onTap: () {
              onAuraChanged(hero.auraColor);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MediaDetailScreen(
                    controller: controller,
                    item: hero,
                  ),
                ),
              );
            },
            child: Container(
              height: 330,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: hero.auraColor.withOpacity(app.glowStrength),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: hero.auraColor.withOpacity(app.glowStrength * 0.5),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(23),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(hero.backdropUrl, fit: BoxFit.cover),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Color(0x88000000),
                            Color(0xF5000000),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 14,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: app.accentColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '#1 TODAY • KOTOSUB AI READY',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hero.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${hero.studio} • ${hero.genres.join(' • ')} • ★ ${hero.rating}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            CastexCinemaPlayerScreen(
                                          controller: controller,
                                          item: hero,
                                          episode: hero.episodes.first,
                                          stream:
                                              hero.episodes.first.streams.first,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: const Text(
                                    'Watch Now',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: app.accentColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              LiquidGlassCard(
                                appearance: app,
                                borderRadius: BorderRadius.circular(14),
                                child: IconButton(
                                  icon: Icon(
                                    controller.watchlistIds.contains(hero.id)
                                        ? Icons.bookmark_added_rounded
                                        : Icons.bookmark_add_outlined,
                                  ),
                                  onPressed: () =>
                                      controller.toggleWatchlist(hero.id),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (continueList.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Text(
              'Continue Watching',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 135,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: continueList.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, idx) {
                  final item = continueList[idx];
                  final prog = controller.watchProgress[item.id] ?? 0.0;
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CastexCinemaPlayerScreen(
                          controller: controller,
                          item: item,
                          episode: item.episodes.first,
                          stream: item.episodes.first.streams.first,
                        ),
                      ),
                    ),
                    child: Container(
                      width: 230,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: app.cardColor,
                        border: Border.all(color: Colors.white12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(item.backdropUrl, fit: BoxFit.cover),
                            Container(color: Colors.black54),
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 14,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${(prog * 100).round()}% watched • Tap to Resume',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: prog,
                                      minHeight: 4,
                                      backgroundColor: Colors.white24,
                                      valueColor: AlwaysStoppedAnimation(
                                          app.accentColor),
                                    ),
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
            ),
          ],
          const SizedBox(height: 22),
          const Text(
            'Studios & Dub Hubs',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                'Crunchyroll',
                'Netflix',
                'Marvel',
                'Muse India',
                'Fandub Hub',
              ]
                  .map(
                    (studio) => Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: app.cardColor,
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        studio,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Top Ranked Today',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 245,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: CastexCatalog.items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, idx) {
                final item = CastexCatalog.items[idx];
                return GestureDetector(
                  onTap: () {
                    onAuraChanged(item.auraColor);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MediaDetailScreen(
                          controller: controller,
                          item: item,
                        ),
                      ),
                    );
                  },
                  child: SizedBox(
                    width: 148,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: item.auraColor
                                    .withOpacity(app.glowStrength),
                                width: 1.2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(item.posterUrl,
                                      fit: BoxFit.cover),
                                  if (item.rankToday != null)
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.black87,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '#${item.rankToday}',
                                          style: TextStyle(
                                            color: app.accentColor,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black87,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.qualityBadge,
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '★ ${item.rating} • ${item.type}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
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
      ),
    );
  }
}

// ============================================================================
// 12. SEARCH TAB
// ============================================================================
class SearchTab extends StatefulWidget {
  final CastexController controller;
  const SearchTab({super.key, required this.controller});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  String _query = '';
  String _selectedGenre = 'All';

  @override
  Widget build(BuildContext context) {
    final app = widget.controller.appearance;
    final results = CastexCatalog.items.where((item) {
      final matchesQuery = _query.isEmpty ||
          item.title.toLowerCase().contains(_query.toLowerCase()) ||
          item.studio.toLowerCase().contains(_query.toLowerCase());
      final matchesGenre =
          _selectedGenre == 'All' || item.genres.contains(_selectedGenre);
      return matchesQuery && matchesGenre;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'Search Anime, Movies, Studios, Addons...',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: app.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: ['All', 'Anime', 'Action', 'Sci-Fi', 'Fantasy', 'Thriller']
                .map((g) {
              final active = _selectedGenre == g;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(g),
                  selected: active,
                  selectedColor: app.accentColor,
                  onSelected: (_) => setState(() => _selectedGenre = g),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        ...results.map(
          (item) => ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 6),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                item.posterUrl,
                width: 54,
                height: 76,
                fit: BoxFit.cover,
              ),
            ),
            title: Text(item.title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              '${item.type} • ${item.studio} • ★ ${item.rating}',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
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
}

// ============================================================================
// 13. LIBRARY TAB
// ============================================================================
class LibraryTab extends StatefulWidget {
  final CastexController controller;
  const LibraryTab({super.key, required this.controller});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  int _subTab = 0;

  @override
  Widget build(BuildContext context) {
    final app = widget.controller.appearance;
    final savedItems = CastexCatalog.items
        .where((m) => widget.controller.watchlistIds.contains(m.id))
        .toList();
    final pocketItems = CastexCatalog.items
        .where((m) => widget.controller.offlinePocketIds.contains(m.id))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        Row(
          children: [
            _pill('Saved (${savedItems.length})', 0, app),
            const SizedBox(width: 8),
            _pill('Offline Pocket (${pocketItems.length})', 1, app),
            const SizedBox(width: 8),
            _pill('Collections', 2, app),
          ],
        ),
        const SizedBox(height: 18),
        if (_subTab == 0)
          ...savedItems.map((item) => _mediaRow(item, app, isPocket: false)),
        if (_subTab == 1) ...[
          LiquidGlassCard(
            appearance: app,
            padding: const EdgeInsets.all(14),
            child: const Row(
              children: [
                Icon(Icons.train_rounded, color: Colors.amberAccent),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Offline Pocket Mode caches episode metadata & KotoSub Hinglish/Bangla subtitles for zero-signal train/metro commutes.',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...pocketItems.map((item) => _mediaRow(item, app, isPocket: true)),
        ],
        if (_subTab == 2) ...[
          _collectionTile(
            'Anime Must-Watch',
            '${CastexCatalog.items.where((m) => m.type == 'Anime').length} titles',
            Icons.auto_awesome,
            app,
          ),
          _collectionTile(
            'Quiz Unlocked (80%+ Watched)',
            '${widget.controller.completed80Ids.length} titles ready for Fan Quiz',
            Icons.emoji_events_rounded,
            app,
          ),
        ],
      ],
    );
  }

  Widget _pill(String label, int index, CastexAppearance app) {
    final active = _subTab == index;
    return GestureDetector(
      onTap: () => setState(() => _subTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: active ? app.accentColor : app.cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }

  Widget _mediaRow(MediaItem item, CastexAppearance app,
      {required bool isPocket}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: app.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              item.posterUrl,
              width: 56,
              height: 78,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '${item.studio} • ${item.qualityBadge} • ★ ${item.rating}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              isPocket
                  ? Icons.offline_pin_rounded
                  : Icons.bookmark_remove_rounded,
              color: app.accentColor,
            ),
            onPressed: () => isPocket
                ? widget.controller.toggleOfflinePocket(item.id)
                : widget.controller.toggleWatchlist(item.id),
          ),
        ],
      ),
    );
  }

  Widget _collectionTile(
      String title, String sub, IconData icon, CastexAppearance app) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        tileColor: app.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: CircleAvatar(
          backgroundColor: app.accentColor.withOpacity(0.2),
          child: Icon(icon, color: app.accentColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(sub, style: const TextStyle(color: Colors.white60)),
      ),
    );
  }
}

// ============================================================================
// 14. PROFILE DASHBOARD, TASTE DNA, FAN QUIZ & GROUPED SETTINGS
// ============================================================================
class ProfileAndSettingsTab extends StatefulWidget {
  final CastexController controller;
  const ProfileAndSettingsTab({super.key, required this.controller});

  @override
  State<ProfileAndSettingsTab> createState() => _ProfileAndSettingsTabState();
}

class _ProfileAndSettingsTabState extends State<ProfileAndSettingsTab> {
  String _settingsQuery = '';
  bool _includeSensitiveBackup = true;

  void _openEditProfileDialog({UserProfile? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final urlCtrl =
        TextEditingController(text: existing?.customAvatarUrl ?? '');
    final pinCtrl = TextEditingController(text: existing?.pin ?? '');
    int selectedAvatar = existing?.avatarIndex ?? 0;
    bool simpleOnly = existing?.simpleModeOnly ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E1016),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existing == null ? 'Create Profile' : 'Edit Profile & Avatar',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Profile Name',
                    filled: true,
                    fillColor: Colors.white10,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Choose Built-In Avatar (20 Presets)',
                    style: TextStyle(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 54,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: BuiltInAvatars.items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, idx) {
                      final temp = UserProfile(
                        id: 'tmp',
                        name: '',
                        avatarIndex: idx,
                      );
                      return GestureDetector(
                        onTap: () => setModal(() => selectedAvatar = idx),
                        child: AvatarWidget(
                          profile: temp,
                          size: 48,
                          showBorder: selectedAvatar == idx,
                          borderColor: widget.controller.appearance.accentColor,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Custom Avatar Image URL (Optional)',
                    filled: true,
                    fillColor: Colors.white10,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pinCtrl,
                  maxLength: 4,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '4-Digit Profile PIN Lock (Leave empty for none)',
                    filled: true,
                    fillColor: Colors.white10,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Simple Mode Only (For Family/TV)'),
                  value: simpleOnly,
                  onChanged: (v) => setModal(() => simpleOnly = v),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.controller.appearance.accentColor,
                    ),
                    onPressed: () {
                      if (nameCtrl.text.trim().isEmpty) return;
                      widget.controller.addOrUpdateProfile(
                        UserProfile(
                          id: existing?.id ??
                              'p_${DateTime.now().millisecondsSinceEpoch}',
                          name: nameCtrl.text.trim(),
                          avatarIndex: selectedAvatar,
                          customAvatarUrl: urlCtrl.text.trim(),
                          pin: pinCtrl.text.trim().length == 4
                              ? pinCtrl.text.trim()
                              : '',
                          simpleModeOnly: simpleOnly,
                        ),
                      );
                      Navigator.pop(ctx);
                    },
                    child: const Text('Save Profile to Cloud'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAppearanceStudio() {
    final app = widget.controller.appearance;
    final presetCtrl = TextEditingController();
    final hsv = HSVColor.fromColor(app.accentColor);
    double hue = hsv.hue;
    double sat = hsv.saturation;
    double val = hsv.value;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B0D12),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          void applyHsb() {
            final c = HSVColor.fromAHSV(1.0, hue, sat, val).toColor();
            final hex =
                '#${c.value.toRadixString(16).substring(2).toUpperCase()}';
            widget.controller.updateAppearance((a) => a.accentHex = hex);
            setModal(() {});
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Liquid Glass & HSB Color Studio',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    children: [
                      '#E50914',
                      '#00D4FF',
                      '#9D4EDD',
                      '#10B981',
                      '#F59E0B',
                      '#F43F5E',
                      '#FFFFFF',
                    ].map((hex) {
                      final color = Color(
                          int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
                      return GestureDetector(
                        onTap: () {
                          final h = HSVColor.fromColor(color);
                          hue = h.hue;
                          sat = h.saturation;
                          val = h.value;
                          widget.controller
                              .updateAppearance((a) => a.accentHex = hex);
                          setModal(() {});
                        },
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: color,
                          child: app.accentHex.toUpperCase() == hex
                              ? const Icon(Icons.check,
                                  size: 16, color: Colors.black)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Text('Hue (${hue.round()}°)',
                      style: const TextStyle(fontSize: 12)),
                  Slider(
                    value: hue,
                    min: 0,
                    max: 360,
                    onChanged: (v) {
                      hue = v;
                      applyHsb();
                    },
                  ),
                  Text('Saturation (${(sat * 100).round()}%)',
                      style: const TextStyle(fontSize: 12)),
                  Slider(
                    value: sat,
                    onChanged: (v) {
                      sat = v;
                      applyHsb();
                    },
                  ),
                  Text('Brightness (${(val * 100).round()}%)',
                      style: const TextStyle(fontSize: 12)),
                  Slider(
                    value: val,
                    onChanged: (v) {
                      val = v;
                      applyHsb();
                    },
                  ),
                  const Divider(),
                  const Text('Liquid Glass Surface & Dock',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Liquid', 'Frosted', 'Clear', 'Solid'].map((s) {
                      return ChoiceChip(
                        label: Text(s),
                        selected: app.glassSurface == s,
                        onSelected: (_) {
                          widget.controller
                              .updateAppearance((a) => a.glassSurface = s);
                          setModal(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Adaptive', 'Expanded', 'Compact'].map((m) {
                      return ChoiceChip(
                        label: Text('Dock: $m'),
                        selected: app.dockMode == m,
                        onSelected: (_) {
                          widget.controller
                              .updateAppearance((a) => a.dockMode = m);
                          setModal(() {});
                        },
                      );
                    }).toList(),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('AMOLED Pure Black (#000000)'),
                    value: app.amoledBlack,
                    onChanged: (v) {
                      widget.controller
                          .updateAppearance((a) => a.amoledBlack = v);
                      setModal(() {});
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto Poster Aura Glow'),
                    value: app.autoPosterAura,
                    onChanged: (v) {
                      widget.controller
                          .updateAppearance((a) => a.autoPosterAura = v);
                      setModal(() {});
                    },
                  ),
                  const Divider(),
                  Text(
                    'Shareable UI Preset Code: ${app.toPresetCode()}',
                    style: TextStyle(
                      color: app.accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: presetCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Enter code (e.g. CX-CYBERPUNK)',
                            filled: true,
                            fillColor: Colors.white10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final ok = app.applyPresetCode(presetCtrl.text);
                          if (ok) {
                            widget.controller.pushCloudSync();
                            setModal(() {});
                          }
                        },
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openFanQuizHub() {
    final unlockedItems = CastexCatalog.items
        .where((m) => widget.controller.completed80Ids.contains(m.id))
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E1016),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fan Mode • Anime & Lore Quiz',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Watch 80%+ of any episode/movie to unlock its 1-attempt KotoSub AI Quiz & earn profile badges!',
              style: TextStyle(color: Colors.white60, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            if (unlockedItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No episode at 80%+ yet. Open any episode in the player and watch or scrub past 80% to unlock!',
                  style: TextStyle(color: Colors.amberAccent),
                ),
              )
            else
              ...unlockedItems.map((item) {
                final claimed =
                    widget.controller.quizClaimedIds.contains(item.id);
                return ListTile(
                  title: Text(item.title),
                  subtitle: Text(claimed
                      ? 'Badge Unlocked!'
                      : '${item.quizQuestions.length} MCQ Ready'),
                  trailing: ElevatedButton(
                    onPressed: claimed
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            _launchQuizQuestions(item);
                          },
                    child: Text(claimed ? 'Claimed' : 'Start Quiz'),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  void _launchQuizQuestions(MediaItem item) {
    final q = item.quizQuestions.first;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${item.title} Quiz'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(q.question),
            const SizedBox(height: 14),
            _quizOptTile(ctx, item, 'a', q.optionA, q.correctOption),
            _quizOptTile(ctx, item, 'b', q.optionB, q.correctOption),
            _quizOptTile(ctx, item, 'c', q.optionC, q.correctOption),
          ],
        ),
      ),
    );
  }

  Widget _quizOptTile(BuildContext ctx, MediaItem item, String key, String text,
      String correct) {
    return ListTile(
      title: Text(text),
      onTap: () {
        Navigator.pop(ctx);
        if (key == correct) {
          widget.controller.claimQuizReward(
            item.id,
            '${item.studio} Master',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Correct! Unlocked "${item.studio} Master" Badge!',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Wrong answer! Try another title.'),
            ),
          );
        }
      },
    );
  }

  void _openAddonsManager() {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    String dohResult = 'Cloudflare 1.1.1.1 DoH Ready';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E1016),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Stremio Addons & Cloudflare DoH',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Built-in Cloudflare DNS (1.1.1.1)'),
                  subtitle: Text(dohResult,
                      style: const TextStyle(
                          color: Colors.greenAccent, fontSize: 11.5)),
                  value: widget.controller.appearance.cloudflareDns,
                  onChanged: (v) async {
                    widget.controller
                        .updateAppearance((a) => a.cloudflareDns = v);
                    if (v) {
                      dohResult = await widget.controller
                          .testCloudflareDoh('v3-cinemeta.strem.io');
                    }
                    setModal(() {});
                  },
                ),
                const Divider(),
                ...widget.controller.addons.map(
                  (a) => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(a.name),
                    subtitle: Text(a.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11)),
                    value: a.enabled,
                    onChanged: (_) {
                      widget.controller.toggleAddon(a.id);
                      setModal(() {});
                    },
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Addon / Fandub Pack Name',
                    filled: true,
                    fillColor: Colors.white10,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'manifest.json or GitHub JSON URL',
                    filled: true,
                    fillColor: Colors.white10,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (nameCtrl.text.isEmpty || urlCtrl.text.isEmpty) return;
                      widget.controller.addAddon(
                        nameCtrl.text,
                        urlCtrl.text,
                        'Stremio / JSON',
                      );
                      nameCtrl.clear();
                      urlCtrl.clear();
                      setModal(() {});
                    },
                    child: const Text('Install Addon URL'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openBackupRestoreSheet() {
    final importCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E1016),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Backup & Restore (.json)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include Sensitive Info'),
                  subtitle: const Text(
                    'Include installed Addon URLs & 4-digit Profile PINs in backup',
                    style: TextStyle(fontSize: 11.5),
                  ),
                  value: _includeSensitiveBackup,
                  onChanged: (v) =>
                      setModal(() => _includeSensitiveBackup = v),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.copy_all_rounded),
                    label: const Text('Copy Full JSON Backup to Clipboard'),
                    onPressed: () {
                      final jsonStr = widget.controller.exportBackupJson(
                        includeSensitive: _includeSensitiveBackup,
                      );
                      Clipboard.setData(ClipboardData(text: jsonStr));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Backup JSON copied to clipboard!'),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: importCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Paste Castex .json backup here to restore...',
                    filled: true,
                    fillColor: Colors.white10,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      final ok =
                          widget.controller.importBackupJson(importCtrl.text);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? 'Backup restored & synced to cloud!'
                                : 'Invalid backup JSON format.',
                          ),
                        ),
                      );
                    },
                    child: const Text('Restore & Sync'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.controller.appearance;
    final profile = widget.controller.activeProfile;
    final hours = (widget.controller.totalWatchMinutes / 60).toStringAsFixed(1);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        LiquidGlassCard(
          appearance: app,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  AvatarWidget(
                    profile: profile,
                    size: 62,
                    showBorder: true,
                    borderColor: app.accentColor,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.controller.email ?? '',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          children: widget.controller.unlockedBadges
                              .map(
                                (b) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: app.accentColor.withOpacity(0.22),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    b,
                                    style: TextStyle(
                                      color: app.accentColor,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () =>
                        _openEditProfileDialog(existing: profile),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ...widget.controller.profiles.map((p) {
                      final active = p.id == profile.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: AvatarWidget(profile: p, size: 20),
                          label: Text(p.name),
                          selected: active,
                          onSelected: (_) =>
                              widget.controller.switchProfile(p.id),
                        ),
                      );
                    }),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 16),
                      label: const Text('Add Profile'),
                      onPressed: () => _openEditProfileDialog(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LiquidGlassCard(
          appearance: app,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: CustomPaint(
                  painter: TasteDnaPainter(widget.controller.genreMinutes),
                  child: const Center(
                    child: Text(
                      'Taste\nDNA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _statCol('${widget.controller.watchProgress.length}',
                            'Watching'),
                        _statCol('${widget.controller.watchlistIds.length}',
                            'Saved'),
                        _statCol('${hours}h', 'Watch Time'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Top Genres: ${widget.controller.genreMinutes.keys.take(3).join(' • ')}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (widget.controller.effectiveFanMode) ...[
          const SizedBox(height: 14),
          ListTile(
            tileColor: app.accentColor.withOpacity(0.16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: app.accentColor.withOpacity(0.5)),
            ),
            leading: Icon(Icons.sports_esports_rounded, color: app.accentColor),
            title: const Text('Game → Anime & Lore Quiz',
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              '${widget.controller.completed80Ids.length} quizzes unlocked (80% watch rule)',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _openFanQuizHub,
          ),
        ],
        const SizedBox(height: 18),
        const Text(
          'Settings & Studio',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: (v) => setState(() => _settingsQuery = v.toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Search settings (Glass, Color, DNS, Subtitles, Backup)...',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            filled: true,
            fillColor: app.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_matches('appearance glass color hsb theme dock preset'))
          _settingTile(
            icon: Icons.palette_rounded,
            title: 'Appearance & Liquid Glass Studio',
            subtitle:
                'HSB Color Picker, ${app.glassSurface} Glass, ${app.dockMode} Dock, Preset ${app.toPresetCode()}',
            onTap: _openAppearanceStudio,
            app: app,
          ),
        if (_matches('spoiler shield layout unwatched blur'))
          SwitchListTile(
            tileColor: app.cardColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            secondary: Icon(Icons.visibility_off_rounded, color: app.accentColor),
            title: const Text('Smart AI Spoiler Shield'),
            subtitle: const Text(
              'Blur unwatched episode thumbnails & hide spoiler lines',
              style: TextStyle(fontSize: 12),
            ),
            value: app.spoilerShield,
            onChanged: (v) =>
                widget.controller.updateAppearance((a) => a.spoilerShield = v),
          ),
        const SizedBox(height: 8),
        if (_matches('kotosub playback subtitle language dual'))
          _settingTile(
            icon: Icons.subtitles_rounded,
            title: 'Playback & KotoSub AI Engine',
            subtitle:
                'Default: ${app.defaultSubLang} • Dual Subtitles: ${app.dualSubtitles ? 'ON' : 'OFF'}',
            onTap: () {
              const langs = ['Hinglish', 'Bangla', 'Banglish', 'English'];
              final next =
                  langs[(langs.indexOf(app.defaultSubLang) + 1) % langs.length];
              widget.controller
                  .updateAppearance((a) => a.defaultSubLang = next);
            },
            app: app,
          ),
        if (_matches('addons stremio cloudflare dns bypass'))
          _settingTile(
            icon: Icons.extension_rounded,
            title: 'Addons & Cloudflare DNS (1.1.1.1)',
            subtitle:
                '${widget.controller.addons.length} installed • ISP Bypass: ${app.cloudflareDns ? 'ACTIVE' : 'OFF'}',
            onTap: _openAddonsManager,
            app: app,
          ),
        if (_matches('backup restore json export'))
          _settingTile(
            icon: Icons.backup_rounded,
            title: 'Backup & Restore (.json)',
            subtitle: 'Export/Import with Include Sensitive Info toggle',
            onTap: _openBackupRestoreSheet,
            app: app,
          ),
        if (_matches('sync cloud firebase'))
          _settingTile(
            icon: Icons.cloud_sync_rounded,
            title: 'Force Cloud Sync Now',
            subtitle: 'Status: ${widget.controller.syncStatus}',
            onTap: () => widget.controller.pullCloudSync(),
            app: app,
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: () => widget.controller.signOut(),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign Out of Cloud Account'),
        ),
      ],
    );
  }

  bool _matches(String keywords) =>
      _settingsQuery.isEmpty || keywords.contains(_settingsQuery);

  Widget _statCol(String val, String label) {
    return Column(
      children: [
        Text(val,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required CastexAppearance app,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        tileColor: app.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(icon, color: app.accentColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class TasteDnaPainter extends CustomPainter {
  final Map<String, int> genreMinutes;
  TasteDnaPainter(this.genreMinutes);

  @override
  void paint(Canvas canvas, Size size) {
    int total = 0;
    for (final v in genreMinutes.values) {
      total += v;
    }
    if (total == 0) return;

    const palette = [
      Color(0xFFE50914),
      Color(0xFF00D4FF),
      Color(0xFF9D4EDD),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
    ];

    final rect = Offset.zero & size;
    double startAngle = -math.pi / 2;
    int idx = 0;

    for (final entry in genreMinutes.entries) {
      final sweep = (entry.value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = palette[idx % palette.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
          rect.deflate(8), startAngle, sweep - 0.08, false, paint);
      startAngle += sweep;
      idx++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ============================================================================
// 15. DETAIL SCREEN
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
  String _dubFilter = 'All';

  void _openStreamPicker(EpisodeItem ep) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E1016),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final filtered = ep.streams.where((s) {
            return _dubFilter == 'All' || s.dubLayer == _dubFilter;
          }).toList();

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Stream • Ep ${ep.number}: ${ep.title}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
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
                const SizedBox(height: 12),
                ...filtered.map(
                  (s) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: widget
                          .controller.appearance.accentColor
                          .withOpacity(0.2),
                      child: Text(
                        s.quality.split(' ').first,
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
                    trailing: const Icon(Icons.play_circle_fill_rounded),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CastexCinemaPlayerScreen(
                            controller: widget.controller,
                            item: widget.item,
                            episode: ep,
                            stream: s,
                          ),
                        ),
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
    final item = widget.item;
    final watchedPct = widget.controller.watchProgress[item.id] ?? 0.0;

    return Scaffold(
      backgroundColor: app.bgColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: app.bgColor,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                item.title,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(item.backdropUrl, fit: BoxFit.cover),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, app.bgColor],
                      ),
                    ),
                  ),
                ],
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
                    Chip(label: Text(item.qualityBadge)),
                    const SizedBox(width: 8),
                    Chip(label: Text(item.studio)),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        widget.controller.watchlistIds.contains(item.id)
                            ? Icons.bookmark_added_rounded
                            : Icons.bookmark_add_outlined,
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
                const SizedBox(height: 10),
                Text(item.overview,
                    style: const TextStyle(color: Colors.white70, height: 1.4)),
                if (widget.controller.effectiveFanMode) ...[
                  const SizedBox(height: 14),
                  LiquidGlassCard(
                    appearance: app,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome,
                                size: 16, color: app.accentColor),
                            const SizedBox(width: 6),
                            const Text(
                              'Previously On... (KotoSub AI Recap)',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.aiRecap,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Episodes & Hybrid Streams',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    if (app.spoilerShield)
                      const Text(
                        'Spoiler Shield ON',
                        style: TextStyle(
                            color: Colors.amberAccent, fontSize: 11.5),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                ...item.episodes.map((ep) {
                  final isUnwatched = ep.number > 1 && watchedPct < 0.80;
                  final hideSpoiler = app.spoilerShield && isUnwatched;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: app.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 110,
                            height: 68,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(ep.thumbnailUrl,
                                    fit: BoxFit.cover),
                                if (hideSpoiler)
                                  BackdropFilter(
                                    filter:
                                        ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                    child: Container(
                                      color: Colors.black54,
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.visibility_off_rounded,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'E${ep.number} • ${ep.duration}',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.white60),
                                  ),
                                  const SizedBox(width: 6),
                                  if (widget.controller.effectiveFanMode)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: ep.canonTag == 'FILLER'
                                            ? Colors.orange.withOpacity(0.25)
                                            : Colors.green.withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        ep.canonTag,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: ep.canonTag == 'FILLER'
                                              ? Colors.orangeAccent
                                              : Colors.greenAccent,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                hideSpoiler
                                    ? 'Episode ${ep.number} (Spoiler Shielded)'
                                    : ep.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                              Text(
                                hideSpoiler
                                    ? 'Watch previous episode to reveal synopsis'
                                    : ep.synopsis,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11.5, color: Colors.white60),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.play_circle_fill_rounded,
                              color: app.accentColor, size: 32),
                          onPressed: () => _openStreamPicker(ep),
                        ),
                      ],
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

// ============================================================================
// 16. FULLSCREEN CINEMA PLAYER
// ============================================================================
class CastexCinemaPlayerScreen extends StatefulWidget {
  final CastexController controller;
  final MediaItem item;
  final EpisodeItem episode;
  final StreamSource stream;

  const CastexCinemaPlayerScreen({
    super.key,
    required this.controller,
    required this.item,
    required this.episode,
    required this.stream,
  });

  @override
  State<CastexCinemaPlayerScreen> createState() =>
      _CastexCinemaPlayerScreenState();
}

class _CastexCinemaPlayerScreenState extends State<CastexCinemaPlayerScreen> {
  late VideoPlayerController _videoCtrl;
  bool _initialized = false;
  bool _showControls = true;
  bool _isFast2x = false;
  String _activeDubLayer = '';
  String _subLang = 'Hinglish';
  double _subOffsetSec = 0.0;
  String? _errorText;

  static const List<SubtitleCue> _kotoSubSampleCue = [
    SubtitleCue(
      en: 'Domain Expansion: Unlimited Void!',
      hinglish: 'Domain Expansion: Unlimited Void — ab koi bach nahi sakta!',
      bangla: 'ডোমেইন এক্সপ্যানশন: আনলিমিটেড ভয়েড — এখন আর কেউ পালাতে পারবে না!',
      banglish: 'Domain Expansion: Unlimited Void — ekhon ar keu palate parbe na!',
    ),
    SubtitleCue(
      en: 'Hold the line! The barrier is collapsing!',
      hinglish: 'Line pakad ke rakho! Barrier tootne wala hai!',
      bangla: 'লাইন ধরে রাখো! ব্যারিয়ার এখনই ভেঙে পড়বে!',
      banglish: 'Line dhore rakho! Barrier ekhoni bhenge porbe!',
    ),
    SubtitleCue(
      en: 'Castex KotoSub AI synced at 0.000s latency.',
      hinglish: 'Castex KotoSub AI 0.000s sync mein live chal raha hai.',
      bangla: 'Castex KotoSub AI ০.০০০ সেকেন্ড সিঙ্কে লাইভ চলছে।',
      banglish: 'Castex KotoSub AI 0.000s sync-e live cholche.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _activeDubLayer = widget.stream.dubLayer;
    _subLang = widget.controller.appearance.defaultSubLang;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initPlayer(widget.stream.url);
  }

  Future<void> _initPlayer(String url) async {
    setState(() {
      _initialized = false;
      _errorText = null;
    });
    _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await _videoCtrl.initialize();
      _videoCtrl.addListener(_onTick);
      await _videoCtrl.play();
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      if (mounted) {
        setState(() => _errorText = 'Stream failed to load: $e');
      }
    }
  }

  void _onTick() {
    if (!mounted || !_videoCtrl.value.isInitialized) return;
    final pos = _videoCtrl.value.position.inSeconds;
    final dur = _videoCtrl.value.duration.inSeconds;
    if (dur > 0) {
      final frac = pos / dur;
      if (frac >= 0.80 &&
          !widget.controller.completed80Ids.contains(widget.item.id)) {
        widget.controller.recordWatchProgress(widget.item, frac, 5);
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    if (_initialized && _videoCtrl.value.isInitialized) {
      final dur = _videoCtrl.value.duration.inSeconds;
      final pos = _videoCtrl.value.position.inSeconds;
      if (dur > 0) {
        widget.controller.recordWatchProgress(
          widget.item,
          pos / dur,
          (pos / 60).ceil(),
        );
      }
    }
    _videoCtrl.removeListener(_onTick);
    _videoCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _seekRelative(int sec) {
    if (!_initialized) return;
    final target = _videoCtrl.value.position + Duration(seconds: sec);
    _videoCtrl.seekTo(target < Duration.zero ? Duration.zero : target);
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.controller.appearance;
    final posSec = _initialized ? _videoCtrl.value.position.inSeconds : 0;
    final durSec = _initialized ? _videoCtrl.value.duration.inSeconds : 1;
    final cueIdx = ((posSec + _subOffsetSec.round()).abs() ~/ 4) %
        _kotoSubSampleCue.length;
    final currentCue = _kotoSubSampleCue[cueIdx];
    final showAniSkip = widget.controller.effectiveFanMode &&
        posSec >= widget.episode.introStartSec &&
        posSec <= widget.episode.introEndSec;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        onLongPressStart: (_) {
          if (_initialized) {
            _videoCtrl.setPlaybackSpeed(2.0);
            setState(() => _isFast2x = true);
          }
        },
        onLongPressEnd: (_) {
          if (_initialized) {
            _videoCtrl.setPlaybackSpeed(1.0);
            setState(() => _isFast2x = false);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: _errorText != null
                  ? Text(_errorText!,
                      style: const TextStyle(color: Colors.redAccent))
                  : _initialized
                      ? AspectRatio(
                          aspectRatio: _videoCtrl.value.aspectRatio,
                          child: VideoPlayer(_videoCtrl),
                        )
                      : CircularProgressIndicator(color: app.accentColor),
            ),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onDoubleTap: () => _seekRelative(-10),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onDoubleTap: () => _seekRelative(10),
                  ),
                ),
              ],
            ),
            if (_isFast2x)
              Positioned(
                top: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '2.0x Speed ▶▶',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            if (_subLang != 'Off')
              Positioned(
                left: 36,
                right: 36,
                bottom: _showControls ? 86 : 24,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(app.subBgOpacity),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentCue.byLang(_subLang),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: app.subFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (app.dualSubtitles && _subLang != 'English')
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              currentCue.en,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: app.subFontSize * 0.78,
                                color: Colors.amberAccent,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            if (showAniSkip)
              Positioned(
                right: 24,
                bottom: _showControls ? 96 : 32,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: app.accentColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    _videoCtrl.seekTo(
                      Duration(seconds: widget.episode.introEndSec + 1),
                    );
                  },
                  icon: const Icon(Icons.skip_next_rounded),
                  label: const Text('Skip Intro (AniSkip)'),
                ),
              ),
            if (_showControls) ...[
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.item.title} • E${widget.episode.number}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'Dub: $_activeDubLayer • KotoSub: $_subLang (${_subOffsetSec >= 0 ? '+' : ''}${_subOffsetSec.toStringAsFixed(1)}s)',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (layer) =>
                          setState(() => _activeDubLayer = layer),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'Original Audio',
                            child: Text('Layer 1: Original Audio')),
                        PopupMenuItem(
                            value: 'Official Dub',
                            child: Text('Layer 2: Official Dub')),
                        PopupMenuItem(
                            value: 'Community Fandub',
                            child: Text('Layer 3: Verified Fandub')),
                      ],
                      child: Chip(
                        avatar: const Icon(Icons.record_voice_over, size: 15),
                        label: Text(_activeDubLayer,
                            style: const TextStyle(fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      onSelected: (val) {
                        if (val == '+0.5') {
                          setState(() => _subOffsetSec += 0.5);
                        } else if (val == '-0.5') {
                          setState(() => _subOffsetSec -= 0.5);
                        } else {
                          setState(() => _subLang = val);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'Hinglish',
                            child: Text('KotoSub: Hinglish (Dual)')),
                        PopupMenuItem(
                            value: 'Bangla',
                            child: Text('KotoSub: বাংলা (Dual)')),
                        PopupMenuItem(
                            value: 'Banglish',
                            child: Text('KotoSub: Banglish (Dual)')),
                        PopupMenuItem(
                            value: 'English',
                            child: Text('KotoSub: English')),
                        PopupMenuItem(value: 'Off', child: Text('Subtitles Off')),
                        PopupMenuDivider(),
                        PopupMenuItem(
                            value: '+0.5', child: Text('Sync Offset +0.5s')),
                        PopupMenuItem(
                            value: '-0.5', child: Text('Sync Offset -0.5s')),
                      ],
                      child: Chip(
                        avatar: const Icon(Icons.subtitles, size: 15),
                        label: Text('KotoSub: $_subLang',
                            style: const TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      iconSize: 34,
                      icon: const Icon(Icons.replay_10_rounded),
                      onPressed: () => _seekRelative(-10),
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      iconSize: 54,
                      icon: Icon(
                        _initialized && _videoCtrl.value.isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_filled_rounded,
                        color: app.accentColor,
                      ),
                      onPressed: () {
                        if (!_initialized) return;
                        _videoCtrl.value.isPlaying
                            ? _videoCtrl.pause()
                            : _videoCtrl.play();
                        setState(() {});
                      },
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      iconSize: 34,
                      icon: const Icon(Icons.forward_10_rounded),
                      onPressed: () => _seekRelative(10),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 14,
                child: Row(
                  children: [
                    Text(
                      _fmtDuration(Duration(seconds: posSec)),
                      style: const TextStyle(fontSize: 12),
                    ),
                    Expanded(
                      child: Slider(
                        activeColor: app.accentColor,
                        value: posSec.toDouble().clamp(0, durSec.toDouble()),
                        min: 0,
                        max: math.max(1, durSec.toDouble()),
                        onChanged: (v) {
                          if (_initialized) {
                            _videoCtrl.seekTo(Duration(seconds: v.round()));
                          }
                        },
                      ),
                    ),
                    Text(
                      _fmtDuration(Duration(seconds: durSec)),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
