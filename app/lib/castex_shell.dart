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
                splashColor: app.accentColor.withOpacity(0.10),
                highlightColor: app.accentColor.withOpacity(0.06),
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

    // Shared Liquid Glass surface used by the shell-level screens and controls.
    class _CastexGlass extends StatelessWidget {
      final Widget child;
      final CastexAppearance appearance;
      final EdgeInsetsGeometry padding;
      final BorderRadius borderRadius;
      final Color? tint;
      final double? blur;
      final bool glow;
      final Border? border;

      const _CastexGlass({
        required this.child,
        required this.appearance,
        this.padding = EdgeInsets.zero,
        this.borderRadius = const BorderRadius.all(Radius.circular(22)),
        this.tint,
        this.blur,
        this.glow = false,
        this.border,
      });

      @override
      Widget build(BuildContext context) {
        final enabled = appearance.isGlassEnabled;
        final sigma = blur ?? appearance.glassBlurSigma;
        final baseTint = tint ?? appearance.cardColor;

        return ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: enabled ? sigma : 0,
              sigmaY: enabled ? sigma : 0,
            ),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: baseTint,
                borderRadius: borderRadius,
                border: border ??
                    Border.all(
                      color: enabled
                          ? appearance.glassBorderColor
                          : Colors.white.withOpacity(0.08),
                      width: 1,
                    ),
                boxShadow: glow
                    ? [
                        BoxShadow(
                          color: appearance.accentColor.withOpacity(0.16),
                          blurRadius: 28,
                          spreadRadius: -5,
                        ),
                      ]
                    : null,
              ),
              child: child,
            ),
          ),
        );
      }
    }

    class _CastexBackdrop extends StatelessWidget {
      final CastexAppearance appearance;
      final Color aura;

      const _CastexBackdrop({
        required this.appearance,
        required this.aura,
      });

      @override
      Widget build(BuildContext context) {
        final color = appearance.autoPosterAura ? aura : appearance.accentColor;
        final intensity = switch (appearance.liquidGlassMode) {
          'Liquid Prism' => 0.27,
          'Crystal Frost' => 0.19,
          'Smoke Obsidian' => 0.12,
          _ => 0.07,
        };

        return Positioned.fill(
          child: IgnorePointer(
            child: Stack(
              children: [
                Container(color: appearance.bgColor),
                Positioned(
                  top: -150,
                  left: -90,
                  child: _AuraOrb(
                    color: color.withOpacity(intensity),
                    size: 340,
                  ),
                ),
                Positioned(
                  top: 170,
                  right: -180,
                  child: _AuraOrb(
                    color: appearance.accentColor.withOpacity(intensity * 0.45),
                    size: 300,
                  ),
                ),
                if (appearance.liquidGlassMode == 'Crystal Frost')
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.035),
                            Colors.transparent,
                            appearance.accentColor.withOpacity(0.035),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }
    }

    class _AuraOrb extends StatelessWidget {
      final Color color;
      final double size;

      const _AuraOrb({required this.color, required this.size});

      @override
      Widget build(BuildContext context) {
        return ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
        );
      }
    }

    // ============================================================================
    // AUTH GATE
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

      @override
      void dispose() {
        _emailCtrl.dispose();
        _passCtrl.dispose();
        super.dispose();
      }

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
          userEmail: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          isSignUp: _isSignUp,
        );

        if (!mounted) return;
        setState(() {
          _loading = false;
          _errorMsg = err;
        });
      }

      Future<void> _forgotPassword() async {
        if (_emailCtrl.text.trim().isEmpty) {
          setState(() => _errorMsg = 'Enter your email above first to reset.');
          return;
        }

        final err = await widget.controller.sendPasswordReset(_emailCtrl.text.trim());
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              err ?? 'Password reset link sent to ${_emailCtrl.text.trim()}',
            ),
          ),
        );
      }

      InputDecoration _fieldDecoration({
        required String label,
        required IconData icon,
        Widget? suffix,
      }) {
        return InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          suffixIcon: suffix,
          filled: true,
          fillColor: Colors.white.withOpacity(0.055),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: widget.controller.appearance.accentColor.withOpacity(0.8),
              width: 1.2,
            ),
          ),
        );
      }

      @override
      Widget build(BuildContext context) {
        final app = widget.controller.appearance;

        return Scaffold(
          backgroundColor: app.bgColor,
          body: Stack(
            children: [
              _CastexBackdrop(appearance: app, aura: app.accentColor),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: _CastexGlass(
                        appearance: app,
                        padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
                        borderRadius: BorderRadius.circular(28),
                        glow: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Column(
                                children: [
                                  Container(
                                    width: 62,
                                    height: 62,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(19),
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          app.accentColor,
                                          app.accentColor.withOpacity(0.48),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: app.accentColor.withOpacity(0.35),
                                          blurRadius: 24,
                                          spreadRadius: -4,
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'CX',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'CASTEX',
                                    style: TextStyle(
                                      fontSize: 25,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 4,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _isSignUp
                                        ? 'CREATE YOUR CASTEX ACCOUNT'
                                        : 'WELCOME BACK TO CASTEX',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.7,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),
                            TextField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: _fieldDecoration(
                                label: 'Email Address',
                                icon: Icons.alternate_email_rounded,
                              ),
                            ),
                            const SizedBox(height: 13),
                            TextField(
                              controller: _passCtrl,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _loading ? null : _submit(),
                              decoration: _fieldDecoration(
                                label: 'Password (min 6 characters)',
                                icon: Icons.lock_outline_rounded,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    color: Colors.white54,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                            ),
                            if (_errorMsg != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _errorMsg!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: app.accentColor,
                                  foregroundColor: Colors.white,
                                  elevation: 8,
                                  shadowColor: app.accentColor.withOpacity(0.28),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 21,
                                        height: 21,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        _isSignUp ? 'Create Account' : 'Sign In',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: TextButton(
                                    onPressed: () => setState(() {
                                      _isSignUp = !_isSignUp;
                                      _errorMsg = null;
                                    }),
                                    child: Text(
                                      _isSignUp
                                          ? 'Already registered? Sign in'
                                          : 'New here? Create account',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ),
                                if (!_isSignUp)
                                  TextButton(
                                    onPressed: _forgotPassword,
                                    child: const Text(
                                      'Reset password',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: Colors.white.withOpacity(0.12),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      'OR',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: Colors.white.withOpacity(0.12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  widget.controller.enterLocalMode(),
                              icon: const Icon(Icons.play_arrow_rounded, size: 19),
                              label: const Text('Continue in Local Mode'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: app.glassBorderColor,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'AD-FREE • OPEN SOURCE • YOUR MEDIA SPACE',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white30,
                                fontSize: 8.5,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
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
    // PROFILE PIN GATE
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
      void dispose() {
        _pinCtrl.dispose();
        super.dispose();
      }

      void _checkPin(String value) {
        if (value.length != 4) return;

        if (value == widget.controller.activeProfile.pin) {
          widget.controller.unlockProfile();
        } else {
          setState(() {
            _err = 'Incorrect PIN. Try again.';
            _pinCtrl.clear();
          });
        }
      }

      @override
      Widget build(BuildContext context) {
        final profile = widget.controller.activeProfile;
        final app = widget.controller.appearance;

        return Scaffold(
          backgroundColor: app.bgColor,
          body: Stack(
            children: [
              _CastexBackdrop(appearance: app, aura: app.accentColor),
              SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: _CastexGlass(
                        appearance: app,
                        padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
                        borderRadius: BorderRadius.circular(28),
                        glow: true,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AvatarWidget(
                              profile: profile,
                              size: 88,
                              showBorder: true,
                              borderColor: app.accentColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              profile.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 7),
                            const Text(
                              'ENTER YOUR 4-DIGIT PROFILE PIN',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                                letterSpacing: 1.3,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: 190,
                              child: TextField(
                                controller: _pinCtrl,
                                maxLength: 4,
                                obscureText: true,
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                onChanged: _checkPin,
                                style: const TextStyle(
                                  fontSize: 25,
                                  letterSpacing: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.055),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: app.glassBorderColor,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: app.accentColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (_err != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _err!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
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
    // MAIN CASTEX SHELL — LIQUID GLASS
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

      static const _icons = [
        Icons.grid_view_rounded,
        Icons.travel_explore_rounded,
        Icons.collections_bookmark_rounded,
        Icons.account_circle_rounded,
      ];

      static const _labels = ['Stage', 'Discover', 'Vault', 'Me'];

      void _onScroll(double offset) {
        if (widget.controller.appearance.dockMode != 'Adaptive') return;

        final compact = offset > 70;
        if (compact != _compactDockNotifier.value) {
          _compactDockNotifier.value = compact;
        }
      }

      void _showLiquidGlassSheet() {
        final app = widget.controller.appearance;

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.black.withOpacity(0.62),
          builder: (ctx) {
            return StatefulBuilder(
              builder: (ctx, setModal) {
                final current = widget.controller.appearance;
                const descriptions = {
                  'Off': 'Pure AMOLED black with no blur.',
                  'Crystal Frost': 'Soft frosted glass with clean bright edges.',
                  'Liquid Prism': 'Vibrant tinted glass with adaptive colour glow.',
                  'Smoke Obsidian': 'Dark smoked glass for a subtle cinema look.',
                };

                return SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: _CastexGlass(
                      appearance: current,
                      blur: 26,
                      tint: const Color(0xF20B0D14),
                      borderRadius: BorderRadius.circular(28),
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                      glow: true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 38,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: current.accentColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.blur_on_rounded,
                                  color: current.accentColor,
                                ),
                              ),
                              const SizedBox(width: 11),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Liquid Glass',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Choose your Castex appearance',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ...CastexAppearance.glassModes.map((mode) {
                            final selected = current.liquidGlassMode == mode;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 9),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(17),
                                onTap: () {
                                  widget.controller.updateAppearance(
                                    (a) => a.liquidGlassMode = mode,
                                  );
                                  setModal(() {});
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.all(13),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? current.accentColor.withOpacity(0.14)
                                        : Colors.white.withOpacity(0.035),
                                    borderRadius: BorderRadius.circular(17),
                                    border: Border.all(
                                      color: selected
                                          ? current.accentColor.withOpacity(0.8)
                                          : Colors.white.withOpacity(0.08),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      _ModePreview(
                                        mode: mode,
                                        accent: current.accentColor,
                                        selected: selected,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              mode,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: selected
                                                    ? Colors.white
                                                    : Colors.white.withOpacity(0.88),
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              descriptions[mode] ?? '',
                                              style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 10.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        selected
                                            ? Icons.check_circle_rounded
                                            : Icons.circle_outlined,
                                        color: selected
                                            ? current.accentColor
                                            : Colors.white30,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      }

      void _showNotificationsSheet() {
        final app = widget.controller.appearance;

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _CastexGlass(
                appearance: app,
                blur: 24,
                tint: const Color(0xF20B0D14),
                borderRadius: BorderRadius.circular(26),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Castex Hub Alerts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (widget.controller.notifications.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 22),
                        child: Center(
                          child: Text(
                            'You are all caught up.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                      )
                    else
                      ...widget.controller.notifications.map(
                        (n) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.notifications_active_rounded,
                            color: app.accentColor,
                          ),
                          title: Text(
                            n.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            n.body,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Text(
                            n.time,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      Widget _buildHeader(CastexAppearance app) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 7, 14, 9),
          child: _CastexGlass(
            appearance: app,
            blur: 20,
            tint: app.dockColor.withOpacity(0.92),
            borderRadius: BorderRadius.circular(19),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 31,
                  height: 31,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: [
                        app.accentColor,
                        app.accentColor.withOpacity(0.55),
                      ],
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'CX',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                const Text(
                  'CASTEX',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 2.4,
                  ),
                ),
                const Spacer(),
                _HeaderPill(
                  label: app.liquidGlassMode == 'Off'
                      ? 'AMOLED'
                      : app.liquidGlassMode.toUpperCase(),
                  icon: Icons.blur_on_rounded,
                  color: app.accentColor,
                  onTap: _showLiquidGlassSheet,
                ),
                const SizedBox(width: 6),
                _HeaderPill(
                  label: widget.controller.effectiveFanMode ? 'FAN' : 'SIMPLE',
                  color: widget.controller.effectiveFanMode
                      ? app.accentColor
                      : Colors.white70,
                  onTap: () => widget.controller.updateAppearance(
                    (a) => a.fanMode = !a.fanMode,
                  ),
                ),
                const SizedBox(width: 2),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Notifications',
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                    size: 21,
                  ),
                  onPressed: _showNotificationsSheet,
                ),
              ],
            ),
          ),
        );
      }

      Widget _buildDock(CastexAppearance app) {
        return Positioned(
          left: 0,
          right: 0,
          bottom: 10,
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

                      final dock = _CastexGlass(
                        appearance: app,
                        blur: app.glassBlurSigma + 5,
                        tint: app.dockColor.withOpacity(0.96),
                        borderRadius: BorderRadius.circular(28),
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 7 : 9,
                          vertical: compact ? 6 : 8,
                        ),
                        glow: app.liquidGlassMode == 'Liquid Prism',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(_icons.length, (i) {
                            final selected = tabIndex == i;
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _tabNotifier.value = i,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutCubic,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                padding: EdgeInsets.symmetric(
                                  horizontal: selected && !compact ? 13 : 11,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? app.accentColor.withOpacity(0.20)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(22),
                                  border: selected
                                      ? Border.all(
                                          color:
                                              app.accentColor.withOpacity(0.22),
                                        )
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (i == 3)
                                      AvatarWidget(
                                        profile: widget.controller.activeProfile,
                                        size: 21,
                                        showBorder: selected,
                                        borderColor: app.accentColor,
                                      )
                                    else
                                      Icon(
                                        _icons[i],
                                        size: 21,
                                        color: selected
                                            ? app.accentColor
                                            : Colors.white60,
                                      ),
                                    if (selected && !compact) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        _labels[i],
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                          color: selected
                                              ? Colors.white
                                              : Colors.white70,
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

                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: dock,
                      );
                    },
                  );
                },
              ),
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
          extendBody: true,
          body: Stack(
            children: [
              ValueListenableBuilder<Color>(
                valueListenable: _auraNotifier,
                builder: (_, aura, __) =>
                    _CastexBackdrop(appearance: app, aura: aura),
              ),
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _buildHeader(app),
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
                                onAuraChanged: (color) =>
                                    _auraNotifier.value = color,
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
              _buildDock(app),
            ],
          ),
        );
      }
    }

    class _HeaderPill extends StatelessWidget {
      final String label;
      final IconData? icon;
      final Color color;
      final VoidCallback onTap;

      const _HeaderPill({
        required this.label,
        required this.color,
        required this.onTap,
        this.icon,
      });

      @override
      Widget build(BuildContext context) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 12, color: color),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 0.45,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    class _ModePreview extends StatelessWidget {
      final String mode;
      final Color accent;
      final bool selected;

      const _ModePreview({
        required this.mode,
        required this.accent,
        required this.selected,
      });

      @override
      Widget build(BuildContext context) {
        final Color base = switch (mode) {
          'Crystal Frost' => const Color(0xFFB8D5E8),
          'Liquid Prism' => accent,
          'Smoke Obsidian' => const Color(0xFF525B6B),
          _ => const Color(0xFF050608),
        };

        return Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                base.withOpacity(mode == 'Off' ? 1 : 0.8),
                const Color(0xFF111722),
              ],
            ),
            border: Border.all(
              color: selected ? accent : Colors.white.withOpacity(0.14),
            ),
          ),
          child: Icon(
            mode == 'Off'
                ? Icons.contrast_rounded
                : mode == 'Crystal Frost'
                    ? Icons.ac_unit_rounded
                    : mode == 'Liquid Prism'
                        ? Icons.auto_awesome_rounded
                        : Icons.nights_stay_rounded,
            color: Colors.white.withOpacity(0.92),
            size: 20,
          ),
        );
      }
    }
