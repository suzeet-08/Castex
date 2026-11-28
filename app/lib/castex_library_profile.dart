import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'castex_core.dart';
import 'castex_home_discover.dart';

// ============================================================================
// LIBRARY / VAULT TAB
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
    final known = CastexAddonEngine.starterShowcase;
    final saved = known
        .where((m) => widget.controller.watchlistIds.contains(m.id))
        .toList();
    final pocket = known
        .where((m) => widget.controller.offlinePocketIds.contains(m.id))
        .toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 105),
      children: [
        Row(
          children: [
            _pill('Saved (${widget.controller.watchlistIds.length})', 0, app),
            const SizedBox(width: 8),
            _pill(
                'Pocket (${widget.controller.offlinePocketIds.length})', 1, app),
          ],
        ),
        const SizedBox(height: 16),
        if (_subTab == 0) ...[
          if (widget.controller.watchlistIds.isEmpty)
            const Text('No saved titles yet. Bookmark any movie or anime.',
                style: TextStyle(color: Colors.white60))
          else ...[
            ...saved.map((item) => _rowTile(item, app, pocketMode: false)),
            ...widget.controller.watchlistIds
                .where((id) => !known.any((k) => k.id == id))
                .map(
                  (id) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      tileColor: app.cardColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      title: Text('Saved Title ($id)'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          widget.controller.toggleWatchlist(id);
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                ),
          ],
        ] else ...[
          if (widget.controller.offlinePocketIds.isEmpty)
            const Text('Offline Pocket is empty.',
                style: TextStyle(color: Colors.white60))
          else
            ...pocket.map((item) => _rowTile(item, app, pocketMode: true)),
        ],
      ],
    );
  }

  Widget _pill(String text, int index, CastexAppearance app) {
    final active = _subTab == index;
    return GestureDetector(
      onTap: () => setState(() => _subTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? app.accentColor : app.cardColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Widget _rowTile(MediaItem item, CastexAppearance app,
      {required bool pocketMode}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        tileColor: app.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(item.posterUrl,
              width: 44, height: 62, fit: BoxFit.cover),
        ),
        title: Text(item.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${item.studio} • ★ ${item.rating}',
            style: const TextStyle(fontSize: 11.5)),
        trailing: IconButton(
          icon: Icon(Icons.remove_circle_outline, color: app.accentColor),
          onPressed: () {
            pocketMode
                ? widget.controller.toggleOfflinePocket(item.id)
                : widget.controller.toggleWatchlist(item.id);
            setState(() {});
          },
        ),
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
  }
}

// ============================================================================
// PROFILE, TASTE DNA, QUIZ & SETTINGS TAB
// ============================================================================
class ProfileAndSettingsTab extends StatefulWidget {
  final CastexController controller;
  const ProfileAndSettingsTab({super.key, required this.controller});

  @override
  State<ProfileAndSettingsTab> createState() => _ProfileAndSettingsTabState();
}

class _ProfileAndSettingsTabState extends State<ProfileAndSettingsTab> {
  String _query = '';
  bool _includeSensitive = true;

  void _openEditProfile({UserProfile? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final urlCtrl =
        TextEditingController(text: existing?.customAvatarUrl ?? '');
    final pinCtrl = TextEditingController(text: existing?.pin ?? '');
    int avatarIdx = existing?.avatarIndex ?? 0;
    bool simpleOnly = existing?.simpleModeOnly ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1016),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
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
                  existing == null ? 'New Profile' : 'Edit Profile',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Profile Name',
                    filled: true,
                    fillColor: Colors.white10,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 50,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: BuiltInAvatars.items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final tmp =
                          UserProfile(id: 't', name: '', avatarIndex: i);
                      return GestureDetector(
                        onTap: () => setModal(() => avatarIdx = i),
                        child: AvatarWidget(
                          profile: tmp,
                          size: 44,
                          showBorder: avatarIdx == i,
                          borderColor: widget.controller.appearance.accentColor,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Custom Avatar URL (Optional)',
                    filled: true,
                    fillColor: Colors.white10,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pinCtrl,
                  maxLength: 4,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '4-Digit PIN (Optional)',
                    filled: true,
                    fillColor: Colors.white10,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Standard Mode Only'),
                  value: simpleOnly,
                  onChanged: (v) => setModal(() => simpleOnly = v),
                ),
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
                          avatarIndex: avatarIdx,
                          customAvatarUrl: urlCtrl.text.trim(),
                          pin: pinCtrl.text.trim().length == 4
                              ? pinCtrl.text.trim()
                              : '',
                          simpleModeOnly: simpleOnly,
                        ),
                      );
                      Navigator.pop(ctx);
                    },
                    child: const Text('Save Profile'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openThemeStudio() {
    final app = widget.controller.appearance;
    final presetCtrl = TextEditingController();
    final hsv = HSVColor.fromColor(app.accentColor);
    double hue = hsv.hue;
    double sat = hsv.saturation;
    double val = hsv.value;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A0C10),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          void applyColor() {
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
                  const Text('Castex Theme & Accent Studio',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    children: [
                      '#FF2A55',
                      '#00D4FF',
                      '#10B981',
                      '#F59E0B',
                      '#A855F7',
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
                  const SizedBox(height: 10),
                  Text('Hue (${hue.round()}°)',
                      style: const TextStyle(fontSize: 12)),
                  Slider(
                    value: hue,
                    min: 0,
                    max: 360,
                    onChanged: (v) {
                      hue = v;
                      applyColor();
                    },
                  ),
                  Text('Saturation (${(sat * 100).round()}%)',
                      style: const TextStyle(fontSize: 12)),
                  Slider(
                    value: sat,
                    onChanged: (v) {
                      sat = v;
                      applyColor();
                    },
                  ),
                  Text('Brightness (${(val * 100).round()}%)',
                      style: const TextStyle(fontSize: 12)),
                  Slider(
                    value: val,
                    onChanged: (v) {
                      val = v;
                      applyColor();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pure OLED Black (#000000)'),
                    value: app.amoledBlack,
                    onChanged: (v) {
                      widget.controller
                          .updateAppearance((a) => a.amoledBlack = v);
                      setModal(() {});
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Poster Ambient Glow'),
                    value: app.autoPosterAura,
                    onChanged: (v) {
                      widget.controller
                          .updateAppearance((a) => a.autoPosterAura = v);
                      setModal(() {});
                    },
                  ),
                  Text('Preset Code: ${app.toPresetCode()}',
                      style: TextStyle(
                          color: app.accentColor, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: presetCtrl,
                          decoration: const InputDecoration(
                            hintText: 'CX-NEON, CX-AMBER, or #HEX',
                            filled: true,
                            fillColor: Colors.white10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (app.applyPresetCode(presetCtrl.text)) {
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

  void _openAddonsSheet() {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    String dohStatus = 'Cloudflare 1.1.1.1 DoH Ready';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1016),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
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
                const Text('Addon Sources & Cloudflare DNS',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cloudflare 1.1.1.1 DoH'),
                  subtitle: Text(dohStatus,
                      style: const TextStyle(
                          color: Colors.greenAccent, fontSize: 11.5)),
                  value: widget.controller.appearance.cloudflareDns,
                  onChanged: (v) async {
                    widget.controller
                        .updateAppearance((a) => a.cloudflareDns = v);
                    if (v) {
                      dohStatus = await widget.controller
                          .testCloudflareDoh('v3-cinemeta.strem.io');
                    }
                    setModal(() {});
                  },
                ),
                ...widget.controller.addons.map(
                  (a) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(a.name),
                    subtitle: Text(a.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: a.enabled,
                          onChanged: (_) {
                            widget.controller.toggleAddon(a.id);
                            setModal(() {});
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent, size: 20),
                          onPressed: () {
                            widget.controller.removeAddon(a.id);
                            setModal(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Addon / JSON Pack Name',
                    filled: true,
                    fillColor: Colors.white10,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'manifest.json or .json URL',
                    filled: true,
                    fillColor: Colors.white10,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameCtrl.text.isEmpty || urlCtrl.text.isEmpty) return;
                      final url = urlCtrl.text.trim();
                      final manifest =
                          await CastexAddonEngine.validateManifest(url);
                      widget.controller.addAddon(
                        nameCtrl.text,
                        url,
                        manifest != null ? 'Verified Stremio Addon' : 'JSON Source',
                      );
                      nameCtrl.clear();
                      urlCtrl.clear();
                      setModal(() {});
                    },
                    child: const Text('Verify & Add Source'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openBackupSheet() {
    final importCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1016),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
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
                const Text('Backup & Restore (.json)',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include Sensitive Info'),
                  value: _includeSensitive,
                  onChanged: (v) => setModal(() => _includeSensitive = v),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.copy_all_rounded),
                    label: const Text('Copy Backup JSON'),
                    onPressed: () {
                      final data = widget.controller
                          .exportBackupJson(includeSensitive: _includeSensitive);
                      Clipboard.setData(ClipboardData(text: data));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Backup JSON copied')),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: importCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Paste backup JSON to restore...',
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
                              ok ? 'Backup restored!' : 'Invalid JSON backup'),
                        ),
                      );
                    },
                    child: const Text('Restore JSON'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openQuizHub() {
    final unlocked = CastexAddonEngine.starterShowcase
        .where((m) => widget.controller.completed80Ids.contains(m.id))
        .toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1016),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Game • Lore & Episode Quiz',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (unlocked.isEmpty)
              const Text(
                'Watch 80%+ of a title in the player to unlock its quiz.',
                style: TextStyle(color: Colors.white60),
              )
            else
              ...unlocked.map(
                (item) => ListTile(
                  title: Text(item.title),
                  subtitle: Text(
                      widget.controller.quizClaimedIds.contains(item.id)
                          ? 'Completed'
                          : '1 Attempt Available'),
                  trailing: ElevatedButton(
                    onPressed: widget.controller.quizClaimedIds.contains(item.id)
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            final q = item.quizQuestions.first;
                            showDialog(
                              context: context,
                              builder: (dCtx) => AlertDialog(
                                title: Text(item.title),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(q.question),
                                    const SizedBox(height: 10),
                                    for (final opt in [
                                      ('a', q.optionA),
                                      ('b', q.optionB),
                                      ('c', q.optionC),
                                    ])
                                      ListTile(
                                        title: Text(opt.$2),
                                        onTap: () {
                                          Navigator.pop(dCtx);
                                          if (opt.$1 == q.correctOption) {
                                            widget.controller.claimQuizReward(
                                                item.id, '${item.title} Quiz');
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content:
                                                      Text('Badge Unlocked!')),
                                            );
                                          }
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                    child: const Text('Play'),
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
    final profile = widget.controller.activeProfile;
    final hours = (widget.controller.totalWatchMinutes / 60).toStringAsFixed(1);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 105),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: app.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  AvatarWidget(
                    profile: profile,
                    size: 56,
                    showBorder: true,
                    borderColor: app.accentColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(
                          widget.controller.email ?? 'Local Mode',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () => _openEditProfile(existing: profile),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat('${widget.controller.watchProgress.length}', 'Active'),
                  _stat('${widget.controller.watchlistIds.length}', 'Saved'),
                  _stat('${hours}h', 'Watched'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: app.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 78,
                height: 78,
                child: CustomPaint(
                  painter: TasteDnaPainter(widget.controller.genreMinutes),
                  child: const Center(
                    child: Text('DNA',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Taste DNA: ${widget.controller.genreMinutes.entries.map((e) => '${e.key} (${e.value}m)').join(' • ')}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        if (widget.controller.effectiveFanMode) ...[
          const SizedBox(height: 12),
          ListTile(
            tileColor: app.cardColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            leading: Icon(Icons.sports_esports_rounded, color: app.accentColor),
            title: const Text('Game • Quiz Challenge',
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
                '${widget.controller.completed80Ids.length} unlocked (80% completion)',
                style: const TextStyle(fontSize: 11.5)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _openQuizHub,
          ),
        ],
        const SizedBox(height: 14),
        TextField(
          onChanged: (v) => setState(() => _query = v.toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Filter settings...',
            prefixIcon: const Icon(Icons.tune_rounded, size: 20),
            filled: true,
            fillColor: app.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_show('theme color accent oled'))
          _tile(
            icon: Icons.palette_rounded,
            title: 'Theme & Accent',
            subtitle: '${app.accentHex} • ${app.toPresetCode()}',
            app: app,
            onTap: _openThemeStudio,
          ),
        if (_show('spoiler shield'))
          SwitchListTile(
            tileColor: app.cardColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Text('Spoiler Shield'),
            subtitle: const Text('Hide unwatched episode synopses & thumbs',
                style: TextStyle(fontSize: 11.5)),
            value: app.spoilerShield,
            onChanged: (v) =>
                widget.controller.updateAppearance((a) => a.spoilerShield = v),
          ),
        const SizedBox(height: 6),
        if (_show('kotosub subtitle language dual'))
          _tile(
            icon: Icons.subtitles_rounded,
            title: 'KotoSub Subtitle Language',
            subtitle:
                '${app.defaultSubLang} • Dual: ${app.dualSubtitles ? 'ON' : 'OFF'}',
            app: app,
            onTap: () {
              const langs = ['Hinglish', 'Bangla', 'Banglish', 'English'];
              final next =
                  langs[(langs.indexOf(app.defaultSubLang) + 1) % langs.length];
              widget.controller
                  .updateAppearance((a) => a.defaultSubLang = next);
            },
          ),
        if (_show('addons dns cloudflare'))
          _tile(
            icon: Icons.extension_rounded,
            title: 'Addons & Cloudflare DNS',
            subtitle: '${widget.controller.addons.length} sources configured',
            app: app,
            onTap: _openAddonsSheet,
          ),
        if (_show('backup restore json'))
          _tile(
            icon: Icons.backup_rounded,
            title: 'Backup & Restore (.json)',
            subtitle: 'Export or import saved state',
            app: app,
            onTap: _openBackupSheet,
          ),
        if (_show('sync cloud'))
          _tile(
            icon: Icons.cloud_sync_rounded,
            title: 'Cloud Sync',
            subtitle: widget.controller.syncStatus,
            app: app,
            onTap: () => widget.controller.pullCloudSync(),
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () => widget.controller.signOut(),
          icon: const Icon(Icons.logout_rounded),
          label: Text(
            widget.controller.isCloudLoggedIn
                ? 'Sign Out'
                : 'Account / Sign In',
          ),
        ),
      ],
    );
  }

  bool _show(String k) => _query.isEmpty || k.contains(_query);

  Widget _stat(String v, String l) {
    return Column(
      children: [
        Text(v,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        Text(l, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required CastexAppearance app,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        tileColor: app.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(icon, color: app.accentColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
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
    const colors = [
      Color(0xFFFF2A55),
      Color(0xFF00D4FF),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
    ];
    final rect = Offset.zero & size;
    double start = -math.pi / 2;
    int i = 0;
    for (final e in genreMinutes.entries) {
      final sweep = (e.value / total) * 2 * math.pi;
      final p = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect.deflate(7), start, sweep - 0.08, false, p);
      start += sweep;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
