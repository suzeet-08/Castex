# Castex Master Architecture & Strategy Notes

## 1. Core Rules & Constraints
- **100% Phone-Only Development:** Built using Android phone, GitHub Web/Actions, Cloudflare, Render, Firebase, and Google Colab at ₹0 server cost.
- **Zero-Telegram Policy:** No Telegram bots, channels, or storage dependencies. All catalogs, subtitle caches, and app notices run via GitHub + Cloudflare + Firebase.
- **Privacy First:** Never link personal social media accounts. Use a dedicated Discord server and a separate public Instagram dev page loaded dynamically via remote JSON.
- **Ad-Free Player:** Keep playback 100% ad-free. Monetize via companion website (Google AdSense), affiliate links, and voluntary supporter tips (UPI/Ko-fi/PayPal) to fund future PC/laptop hardware and team expansion.

## 2. Four App Editions
1. **Castex Stable:** Bug-free release for daily users.
2. **Castex Beta:** Early-access build for Discord testers before Stable rollout.
3. **Castex Advance:** Pro fork with dual-stream audio mixer, shader controls, and experimental tools.
4. **Castex Lite:** 8-12 MB ultra-fast build for low-RAM devices (excludes heavy modules like Game/Quiz).

## 3. Core Engines
- **Hybrid Dub Router:** Switches between Original Voice, Official Dubs (Muse India, Ani-One), and Community Fandubs (YouTube/Odysee embeds + 1080p video + external audio sync bridge).
- **KotoSub AI Engine:** Extracts embedded subtitles directly from the active stream to eliminate episode mismatch, translating at `0.000s` sync via Render + GitHub cache + Colab/Groq/Gemini.
- **Plugin System:** Supports Stremio addon URLs and custom GitHub JSON manifests (auto-updated via AniList, Kitsu, TMDB, Cinemeta, and YouTube RSS). No fragile HTML web-scrapers.
- **UX Modes:** `Simple Mode` (clean TV/Netflix UI for casual/older viewers) vs. `Fan Mode` (Canon/Filler tags, AniSkip, lore popups, Share Studio, and Profile -> Game -> Quiz).

## 4. Phased Release Roadmap
- **Phase 1 (v1.0 - Core Engine):** Android Mobile (Stable + Lite) & Web/PWA, Stremio/JSON catalog, Hybrid Dub Router + KotoSub, Simple/Fan Mode toggle, Remote JSON config, In-App Notification Bell.
- **Phase 2 (v1.2 - Multi-Device & Comfort):** Beta channel open, GitHub Actions builds for Android TV/Firestick, iOS (`.ipa`), macOS (`.dmg`), 6-digit Firebase sync code, AniSkip, Canon/Filler tags, Offline Pocket Mode, companion website + AdSense.
- **Phase 3 (v1.5 - Social & Retention):** Fan Mode Quiz (`Profile -> Game -> Quiz` with 80% watch rule & one-time Firebase lock), Live Watch-Party, Quote/Manga Share Studio, Spoiler-Free Character Cards, Monthly CineWrap card.
- **Phase 4 (v2.0 - Advance & Scaling):** Castex Advance release, voluntary supporter tip jar, PC/laptop upgrade, dedicated cloud servers, and team onboarding.
- 
