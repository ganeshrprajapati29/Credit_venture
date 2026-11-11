import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'auth/mobile_screen.dart';
import 'consent_screen.dart';
import 'home/home_shell.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  String? error;
  String? blocker; // maintenance / update

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    setState(() {
      error = null;
      blocker = null;
    });
    final s = context.read<AppState>();
    final started = DateTime.now();
    try {
      await s.loadConfig();
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
      return;
    }
    if (s.appInfo['maintenanceMode'] == true) {
      setState(() => blocker = 'maintenance');
      return;
    }
    if (s.mustUpdate) {
      setState(() => blocker = 'update');
      return;
    }
    final restored = await s.restoreSession();
    final wait = const Duration(milliseconds: 1400) - DateTime.now().difference(started);
    if (wait > Duration.zero) await Future.delayed(wait);
    if (!mounted) return;

    Widget next;
    if (!s.onboarded) {
      next = const OnboardingScreen();
    } else if (!s.consentGiven) {
      next = const ConsentScreen();
    } else if (!restored) {
      next = const MobileScreen();
    } else {
      next = const HomeShell();
    }
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, _, _) => next,
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 400),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: Stack(children: [
          Positioned(top: -80, right: -60, child: _circle(220, 0.06)),
          Positioned(bottom: -100, left: -80, child: _circle(280, 0.05)),
          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: CurvedAnimation(parent: _c, curve: Curves.easeOut),
                child: ScaleTransition(
                  scale: Tween(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 30, offset: Offset(0, 12))]),
                      child: const BrandLogo(size: 104),
                    ),
                    const SizedBox(height: 24),
                    const Text('Credit Ventures', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    const SizedBox(height: 6),
                    Text('${s.settings['tagline'] ?? 'Instant personal loans, made simple'}', style: const TextStyle(color: AppColors.onHeroMuted, fontSize: 14)),
                    const SizedBox(height: 48),
                    if (error != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _boot,
                        style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.white.withValues(alpha: 0.15), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12)),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ] else if (blocker != null)
                      _Blocker(kind: blocker!, state: s, onRetry: _boot)
                    else
                      const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _circle(double size, double o) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: o)));
}

class _Blocker extends StatelessWidget {
  final String kind;
  final AppState state;
  final VoidCallback onRetry;
  const _Blocker({required this.kind, required this.state, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final maintenance = kind == 'maintenance';
    final apk = '${state.appInfo['apkUrl'] ?? ''}';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(maintenance ? Icons.construction_rounded : Icons.system_update_rounded, size: 44, color: AppColors.primary),
        const SizedBox(height: 12),
        Text(maintenance ? 'Under maintenance' : 'Update required', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          maintenance ? '${state.appInfo['maintenanceMessage'] ?? ''}' : 'A new version of Credit Ventures is available. Please update to continue.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 18),
        PrimaryButton(
          label: maintenance ? 'Retry' : 'Update now',
          onPressed: maintenance || apk.isEmpty ? onRetry : () => launchUrl(Uri.parse(apk), mode: LaunchMode.externalApplication),
        ),
      ]),
    );
  }
}
