# Castex

**Independent Identity. Premium Experience. Zero Ads.**

![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)
![Framework: Flutter](https://img.shields.io/badge/Flutter-Dart-02569B?logo=flutter)
![Platform: Android](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)
![Status: Early Prototype](https://img.shields.io/badge/Status-Early%20Prototype%20(~20%25)-orange)
![Contributors Welcome](https://img.shields.io/badge/Contributors-Welcome-brightgreen)

**Castex** is a free, open-source, 100% ad-free media and anime streaming client built with Flutter. It is designed around an original, refined dark UI, a flexible JSON/Stremio-compatible addon architecture, and intelligent multi-language subtitle delivery (**KotoSub** for Hinglish, Bangla, Banglish, and global languages).

> **Note:** Castex is currently in its **early prototype stage (~20%)** and was initially prototyped entirely from an Android smartphone using GitHub Actions. We are actively looking for **Flutter developers, UI/UX designers, and player/video engineers** to co-build v1.0!

---

## Core Vision & Principles

* **100% Ad-Free & Open-Source:** Licensed under GNU GPLv3. No tracking ads, no paywalls.
* **Original Design Identity:** Not a clone of existing apps—built for a clean, cinematic, OLED-friendly experience that runs smoothly across `60Hz / 90Hz / 120Hz` Android displays.
* **Copyright & DMCA Conscious:** Castex does **not** host, store, or scrape copyrighted media. Content metadata and streams rely strictly on user-configured external JSON manifests and Stremio-compatible addons.
* **Zero-Telegram Architecture:** Completely independent of Telegram bots, channels, or storage dependencies.
* **KotoSub & Hybrid Audio Vision:** Built to support synchronized AI-translated subtitles (Hinglish, Bangla, Banglish, English + Dual Subtitles) and seamless audio/dub switching.

---

## Tech Stack

| Component | Technology |
| :--- | :--- |
| **Framework** | Flutter / Dart |
| **CI/CD & Builds** | GitHub Actions (Automated Android APK builds) |
| **Auth & Cloud Sync** | Firebase Email Auth & Realtime Database (with Local Guest Mode) |
| **Subtitle Backend** | KotoSub (FastAPI / Render) |
| **Catalog Standard** | Stremio `manifest.json` & Custom Remote JSON Addons |
| **Network** | `http` + Cloudflare `1.1.1.1` DoH support |
| **Local Storage** | `shared_preferences` |

---

## Current Prototype Status

**Working / Started:**
* Automated Android APK build pipeline via GitHub Actions
* Basic Firebase Email Auth + Local Guest Mode & local persistence
* Initial Stremio/Cinemeta manifest & addon data models
* Early prototype screens (Home, Search, Library, Profile, Settings) and basic `video_player` integration

**Where We Need Help (Active Priorities):**
1. **Modular Architecture:** Splitting the prototype code cleanly into `core/`, `data/`, `features/`, and `shared/`.
2. **Modern UI/UX Redesign:** Replacing prototype cards with a polished
