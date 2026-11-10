import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'mpin_screen.dart';

class MobileScreen extends StatefulWidget {
  const MobileScreen({super.key});
  @override
  State<MobileScreen> createState() => _MobileScreenState();
}

class _MobileScreenState extends State<MobileScreen> {
  final _ctrl = TextEditingController();
  bool busy = false;

  bool get valid => Validators.mobile.hasMatch(_ctrl.text);

  Future<void> _next() async {
    if (!valid) return;
    setState(() => busy = true);
    try {
      final registered = await context.read<AppState>().isRegistered(_ctrl.text);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => MpinScreen(mobile: _ctrl.text, isLogin: registered)));
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 36, 24, 36),
          decoration: const BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const BrandLogo(size: 56),
            const SizedBox(height: 22),
            const Text('Welcome to\nCredit Ventures', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, height: 1.15)),
            const SizedBox(height: 10),
            const Text('Personal loans from ₹5,000 with simple, transparent EMIs.', style: TextStyle(color: Color(0xFFC3CBFD), fontSize: 14.5)),
            const SizedBox(height: 22),
            Wrap(spacing: 8, runSpacing: 8, children: const [
              _Pill(Icons.bolt_rounded, 'Quick approval'),
              _Pill(Icons.description_rounded, 'Paperless'),
              _Pill(Icons.shield_rounded, '100% secure'),
            ]),
          ]),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(24, 32, 24, 24), children: [
            const Text('Enter your mobile number', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Use the number linked to your Aadhaar & bank account', style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 22),
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
                counterText: '',
                hintText: '98765 43210',
                prefixIcon: Container(
                  width: 72,
                  alignment: Alignment.center,
                  child: const Text('+91', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ]),
        ),
        BottomAction(child: PrimaryButton(label: 'Continue', icon: Icons.arrow_forward_rounded, loading: busy, onPressed: valid ? _next : null)),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Pill(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(30)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: const Color(0xFF6EE7B7)),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ]),
      );
}
