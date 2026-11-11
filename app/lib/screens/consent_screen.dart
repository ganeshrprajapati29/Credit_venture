import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'auth/mobile_screen.dart';
import 'legal_screen.dart';

/// Prominent disclosure of every permission and data point we collect,
/// shown before any permission prompt (Google Play + RBI digital lending requirement).
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});
  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool busy = false;

  static const _items = [
    (Icons.photo_camera_rounded, 'Camera', 'To click photos of your Aadhaar, PAN, bank proof and a selfie for KYC. Photos are taken only when you tap upload.'),
    (Icons.location_on_rounded, 'Location (optional)', 'Approximate location at login to prevent fraud and confirm you are applying from India. You can deny this.'),
    (Icons.notifications_active_rounded, 'Notifications', 'To update you on application status, disbursal and EMI due dates.'),
    (Icons.phone_android_rounded, 'Device information', 'Device model, OS version and app version to keep your account secure and fix issues.'),
    (Icons.person_rounded, 'Information you provide', 'Name, date of birth, PAN, Aadhaar, address, employment and bank details you enter in the application.'),
  ];

  Future<void> _agree() async {
    setState(() => busy = true);
    // Ask for runtime permissions after the disclosure. Each can be denied.
    try {
      await [Permission.camera, Permission.locationWhenInUse, Permission.notification].request();
    } catch (_) {
      // Permission APIs can fail on some devices; the user can still grant them later when needed.
    }
    if (!mounted) return;
    await context.read<AppState>().setConsent();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MobileScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(22, 24, 22, 16), children: [
              Center(child: SvgPicture.asset('assets/images/consent.svg', height: 130)),
              const SizedBox(height: 18),
              const Text('Your privacy matters', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                'To assess your loan application we need the following. Data is encrypted and sent over HTTPS only to our servers.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, height: 1.5),
              ),
              const SizedBox(height: 22),
              for (final it in _items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
                      child: Icon(it.$1, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(it.$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 3),
                        Text(it.$3, style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.45)),
                      ]),
                    ),
                  ]),
                ),
              const InfoBanner(
                icon: Icons.verified_user_rounded,
                color: AppColors.accentDark,
                text: 'We never access your contacts, SMS, call logs, or photos you do not choose. We will never contact your friends or family.',
              ),
              const SizedBox(height: 14),
              Wrap(alignment: WrapAlignment.center, children: [
                const Text('By continuing you agree to our ', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                GestureDetector(
                  onTap: () => LegalScreen.open(context, terms: true),
                  child: const Text('Terms of Service', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary, decoration: TextDecoration.underline)),
                ),
                const Text(' & ', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                GestureDetector(
                  onTap: () => LegalScreen.open(context, terms: false),
                  child: const Text('Privacy Policy', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary, decoration: TextDecoration.underline)),
                ),
              ]),
            ]),
          ),
          BottomAction(
            child: Row(children: [
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Consent required'),
                      content: const Text('We need your consent to process a loan application. You can close the app if you do not wish to continue.'),
                      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                    ),
                  ),
                  child: const Text('Disagree'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(flex: 3, child: PrimaryButton(label: 'I agree', loading: busy, onPressed: _agree)),
            ]),
          ),
        ]),
      ),
    );
  }
}
