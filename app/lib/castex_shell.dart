import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'castex_core.dart';
import 'castex_home_discover.dart';
import 'castex_library_profile.dart';

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
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              },
            ),
            colorScheme: ColorScheme.dark(
              primary: app.accentColor,
              secondary: app.accentColor,
              surface: app.cardColor,
            ),
            cardColor: app.cardColor,
          ),
          home: !controller.hasAppAccess
              ? AuthGateScreen(controller: controller)
              : !controller.profileUnlocked
                  ? ProfilePinGateScreen(controller: controller)
                  : MainShellScreen(controller: controller),
        );
      },
    );
  }
}

// ============================================================================
// AUTH GATE (FIREBASE EMAIL + LOCAL MODE)
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
  bool _isSignUp = true;
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1016),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: app.accentColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'CX',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'CASTEX',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isSignUp
                        ? 'Create Cloud Sync Account'
                        : 'Sign In • Cloud Sync Profile',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: const Icon(Icons.email_outlined),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Password (min 6 chars)',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (_errorMsg != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _errorMsg!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: app.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
                              fontSize: 15,
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
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
                              ? 'Already registered? Sign In'
                              : 'New here? Create Account',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      if (!_isSignUp)
                        TextButton(
                          onPressed: _forgotPassword,
                          child: const Text(
                            'Reset Pass',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => widget.controller.enterLocalMode(),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Use Castex Local Mode'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// PROFILE 4-DIGIT PIN GATE
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
                  size: 80,
                  showBorder: true,
                  borderColor: app.accentColor,
                ),
                const SizedBox(height: 12),
                Text(
                  profile.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text('Enter 4-Digit Profile PIN',
                    style: TextStyle(color: Colors.white60)),
                const SizedBox(height: 16),
                SizedBox(
                  width: 170,
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
                  ),
                ),
                if (_err != null)
                  Text(_err!, style: const TextStyle(color: Colors.redAccent)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SIGNATURE CASTEX LIGER SHELL (4-MODE LIQUID GLASS + 120HZ OPTIMIZED)
// ============================================================================
class MainShellScreen extends StatefulWidget {
  final CastexController controller;
  const MainShellScreen({super.key, required this.controller});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  final ValueNotifier<int> _tabNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> _compactDockNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Color> _auraNotifier =
      ValueNotifier<Color>(const Color(0xFFFF2A55));

  void _onScroll(double offset) {
    if (widget.controller.appearance.dockMode != 'Adaptive') return;
    final compact = offset > 70;
    if (compact != _compactDockNotifier.value) {
      _compactDockNotifier.value = compact;
    }
  }

  void _showLiquidGlassSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1016),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final app = widget.controller.appearance;
          const descriptions = {
            'Off': 'Pure #000000 AMOLED Black • Maximum battery & sharp text',
            'Crystal Frost': 'Translucent frosted glass + specular edge border',
            'Liquid Prism': 'Adaptive poster aura glow + vibrant tinted glass',
            'Smoke Obsidian': 'Deep smoked charcoal glass • Low-glare cinema depth',
          };

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: app.accentColor),
                    const SizedBox(width: 8),
                    const Text(
                      'Liquid Glass Engine (4 Modes)',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...CastexAppearance.glassModes.map((mode) {
                  final selected = app.liquidGlassMode == mode;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? app.accentColor.withOpacity(0.18)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? app.accentColor : Colors.white12,
                      ),
                    ),
                    child: ListTile(
                      title: Text(
                        mode,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        descriptions[mode] ?? '',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11.5),
                      ),
                      trailing: Icon(
                        selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: selected ? app.accentColor : Colors.white38,
                      ),
                      onTap: () {
                        widget.controller.updateAppearance(
                          (a) => a.liquidGlassMode = mode,
                        );
                        setModal(() {});
                      },
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1016),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Castex Hub Alerts',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...widget.controller.notifications.map(
              (n) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.notifications_active_rounded,
                    color: widget.controller.appearance.accentColor),
                title: Text(n.title),
                subtitle: Text(n.body,
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 12)),
                trailing: Text(n.time,
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabNotifier.dispose();
    _compactDockNotifier.dispose();
    _auraNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.controller.appearance;

    return Scaffold(
      backgroundColor: app.bgColor,
      body: Stack(
        children: [
          // 4-Mode Liquid Glass Ambient Backdrop Layer
          RepaintBoundary(
            child: ValueListenableBuilder<Color>(
              valueListenable: _auraNotifier,
              builder: (_, auraColor, __) {
                final activeColor =
                    app.autoPosterAura ? auraColor : app.accentColor;
                final double topOpacity = app.liquidGlassMode == 'Liquid Prism'
                    ? 0.34
                    : app.liquidGlassMode == 'Crystal Frost'
                        ? 0.20
                        : app.liquidGlassMode == 'Smoke Obsidian'
                            ? 0.14
                            : 0.16;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 450),
                  height: app.liquidGlassMode == 'Liquid Prism' ? 320 : 230,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        activeColor.withOpacity(topOpacity),
                        app.bgColor.withOpacity(0.0),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Castex Minimal Header Bar with Quick Liquid Glass Button
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: app.accentColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'CX',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'CASTEX',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 2.5,
                        ),
                      ),
                      const Spacer(),
                      // 1-Tap Liquid Glass Mode Pill
                      GestureDetector(
                        onTap: _showLiquidGlassSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: app.cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: app.glassBorderColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.blur_on_rounded,
                                  size: 13, color: app.accentColor),
                              const SizedBox(width: 4),
                              Text(
                                app.liquidGlassMode == 'Off'
                                    ? 'AMOLED'
                                    : app.liquidGlassMode.split(' ').last.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => widget.controller.updateAppearance(
                          (a) => a.fanMode = !a.fanMode,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: app.cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: widget.controller.effectiveFanMode
                                  ? app.accentColor
                                  : Colors.white12,
                            ),
                          ),
                          child: Text(
                            widget.controller.effectiveFanMode
                                ? 'FAN'
                                : 'SIMPLE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: widget.controller.effectiveFanMode
                                  ? app.accentColor
                                  : Colors.white70,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.notifications_none_rounded),
                        onPressed: _showNotificationsSheet,
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _tabNotifier,
                    builder: (_, tabIndex, __) {
                      return IndexedStack(
                        index: tabIndex,
                        children: [
                          CastexStageHomeTab(
                            controller: widget.controller,
                            onScroll: _onScroll,
                            onAuraChanged: (c) => _auraNotifier.value = c,
                            onOpenDiscover: () => _tabNotifier.value = 1,
                          ),
                          LiveSearchTab(controller: widget.controller),
                          LibraryTab(controller: widget.controller),
                          ProfileAndSettingsTab(controller: widget.controller),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // 4-Mode Liquid Glass Floating Capsule Dock (RepaintBoundary 120Hz Safe)
          Positioned(
            left: 0,
            right: 0,
            bottom: 14,
            child: Center(
              child: RepaintBoundary(
                child: ValueListenableBuilder<int>(
                  valueListenable: _tabNotifier,
                  builder: (_, tabIndex, __) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: _compactDockNotifier,
                      builder: (_, isCompactScroll, __) {
                        final compact = app.dockMode == 'Compact' ||
                            (app.dockMode == 'Adaptive' && isCompactScroll);
                        const icons = [
                          Icons.grid_view_rounded,
                          Icons.travel_explore_rounded,
                          Icons.collections_bookmark_rounded,
                          Icons.account_circle_rounded,
                        ];
                        const labels = ['Stage', 'Discover', 'Vault', 'Me'];

                        final dockContent = AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 10 : 12,
                            vertical: compact ? 6 : 8,
                          ),
                          decoration: BoxDecoration(
                            color: app.dockColor,
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(color: app.glassBorderColor),
                            boxShadow: [
                              BoxShadow(
                                color: app.liquidGlassMode == 'Liquid Prism'
                                    ? app.accentColor.withOpacity(0.22)
                                    : Colors.black87,
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(icons.length, (i) {
                              final selected = tabIndex == i;
                              return GestureDetector(
                                onTap: () => _tabNotifier.value = i,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: selected && !compact ? 13 : 10,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? app.accentColor.withOpacity(0.24)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (i == 3)
                                        AvatarWidget(
                                          profile:
                                              widget.controller.activeProfile,
                                          size: 20,
                                          showBorder: selected,
                                          borderColor: app.accentColor,
                                        )
                                      else
                                        Icon(
                                          icons[i],
                                          size: 21,
                                          color: selected
                                              ? app.accentColor
                                              : Colors.white60,
                                        ),
                                      if (selected && !compact) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          labels[i],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
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

                        if (!app.isGlassEnabled) return dockContent;

                        return ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: app.glassBlurSigma,
                              sigmaY: app.glassBlurSigma,
                            ),
                            child: dockContent,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
