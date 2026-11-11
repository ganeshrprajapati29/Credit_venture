import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../legal_screen.dart';
import 'auth_scaffold.dart';
import 'otp_screen.dart';

/// Step 1 of login: mobile number (OTP is sent on Continue).
class MobileScreen extends StatefulWidget {
  const MobileScreen({super.key});
  @override
  State<MobileScreen> createState() => _MobileScreenState();
}

class _MobileScreenState extends State<MobileScreen> {
  final _ctrl = TextEditingController();
  bool busy = false;
  bool agree = true;

  bool get valid => Validators.mobile.hasMatch(_ctrl.text) && agree;

  Future<void> _next() async {
    if (!valid) return;
    FocusScope.of(context).unfocus();
    setState(() => busy = true);
    try {
      final res = await context.read<AppState>().sendOtp(_ctrl.text);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpScreen(mobile: _ctrl.text, initial: res),
        ),
      );
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Instant loans,\nzero paperwork',
      subtitle: 'Login or sign up with your mobile number',
      bottom: PrimaryButton(label: 'Get OTP', icon: Icons.arrow_forward_rounded, loading: busy, onPressed: valid ? _next : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter mobile number', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('We will send a 6 digit OTP to verify it', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 18),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _next(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 1.5),
            decoration: InputDecoration(
              hintText: '98765 43210',
              counterText: '',
              prefixIcon: Container(
                width: 74,
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🇮🇳', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 6),
                    Text('+91', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              suffixIcon: Validators.mobile.hasMatch(_ctrl.text) ? const Icon(Icons.check_circle_rounded, color: AppColors.accent) : null,
            ),
          ),
          const SizedBox(height: 8),
          const Text('Use the number linked to your Aadhaar and bank account', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 18),
          ConsentTile(
            value: agree,
            onChanged: (v) => setState(() => agree = v),
            text: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'I agree to the '),
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: () => LegalScreen.open(context, terms: true),
                      child: const Text(
                        'Terms of Service',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, fontSize: 13.5),
                      ),
                    ),
                  ),
                  const TextSpan(text: ' and '),
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: () => LegalScreen.open(context, terms: false),
                      child: const Text(
                        'Privacy Policy',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, fontSize: 13.5),
                      ),
                    ),
                  ),
                  const TextSpan(text: ', and to receive OTP and loan updates on this number.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          SectionCard(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: const Row(
              children: [
                Expanded(child: _Trust(Icons.lock_rounded, '100% secure')),
                Expanded(child: _Trust(Icons.bolt_rounded, 'Quick approval')),
                Expanded(child: _Trust(Icons.description_rounded, 'Paperless')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Trust extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Trust(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Column(
    children: [
      CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.primarySoft,
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
      const SizedBox(height: 6),
      Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
      ),
    ],
  );
}
