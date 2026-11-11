import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../theme.dart';
import 'consent_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int page = 0;

  static const _pages = [
    ('assets/images/onboard_1.svg', 'Instant personal loans', 'Get money in your bank account quickly with a simple, fully digital application.'),
    ('assets/images/onboard_2.svg', 'Paperless KYC', 'Just click photos of your Aadhaar, PAN and a selfie. No branch visits, no paperwork.'),
    ('assets/images/onboard_3.svg', 'Safe & transparent', 'Clear EMIs, no hidden charges, and your documents are encrypted and kept private.'),
  ];

  Future<void> _done() async {
    await context.read<AppState>().setOnboarded();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ConsentScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final last = page == _pages.length - 1;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: _done, child: const Text('Skip')),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pc,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => page = i),
              itemBuilder: (_, i) {
                final p = _pages[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Expanded(flex: 5, child: SvgPicture.asset(p.$1)),
                    const SizedBox(height: 24),
                    Text(p.$2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.2)),
                    const SizedBox(height: 12),
                    Text(p.$3, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15.5, color: AppColors.textMuted, height: 1.5)),
                    const Spacer(flex: 1),
                  ]),
                );
              },
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < _pages.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == page ? 26 : 8,
                height: 8,
                decoration: BoxDecoration(color: i == page ? AppColors.primary : AppColors.border, borderRadius: BorderRadius.circular(8)),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: ElevatedButton(
              onPressed: () => last ? _done() : _pc.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOut),
              child: Text(last ? 'Get started' : 'Next'),
            ),
          ),
        ]),
      ),
    );
  }
}
