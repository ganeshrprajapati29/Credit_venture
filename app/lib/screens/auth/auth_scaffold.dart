import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme.dart';
import '../../widgets/common.dart';

/// Shared layout for login screens: green illustrated header + rounded form sheet.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final String illustration;
  final bool showBack;
  final Widget child;
  final Widget bottom;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.bottom,
    this.illustration = 'assets/images/onboard_1.svg',
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.heroGradient),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  Positioned(
                    right: -40,
                    top: -30,
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(showBack ? 8 : 22, top + 10, 18, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (showBack)
                              IconButton(
                                onPressed: () => Navigator.maybePop(context),
                                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                              )
                            else ...[
                              const BrandLogo(size: 38),
                              const SizedBox(width: 10),
                              const Text(
                                'Credit Ventures',
                                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: EdgeInsets.only(left: showBack ? 14 : 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, height: 1.2),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(subtitle, style: const TextStyle(color: AppColors.onHeroMuted, fontSize: 13.5, height: 1.4)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              SvgPicture.asset(illustration, width: 110, height: 110),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListView(padding: const EdgeInsets.fromLTRB(22, 26, 22, 24), children: [child]),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomAction(child: bottom),
      ),
    );
  }
}
