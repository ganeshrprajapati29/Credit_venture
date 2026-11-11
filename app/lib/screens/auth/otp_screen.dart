import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../home/home_shell.dart';
import 'auth_scaffold.dart';

/// Step 2 of login: 6-digit OTP. In demo mode the OTP is shown on screen.
class OtpScreen extends StatefulWidget {
  final String mobile;
  final Map<String, dynamic> initial; // response of /auth/otp/send
  const OtpScreen({super.key, required this.mobile, required this.initial});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  late Map<String, dynamic> info = widget.initial;
  int seconds = 30;
  Timer? _timer;
  bool busy = false;
  String? error;

  String? get demoOtp => info['demo'] == true ? '${info['otp']}' : null;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    seconds = (info['resendIn'] as num?)?.toInt() ?? 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => seconds = seconds > 0 ? seconds - 1 : 0);
      if (seconds == 0) t.cancel();
    });
  }

  Future<void> _resend() async {
    setState(() => error = null);
    try {
      final r = await context.read<AppState>().sendOtp(widget.mobile);
      if (!mounted) return;
      setState(() {
        info = r;
        _ctrl.clear();
      });
      _startTimer();
      showSnack(context, 'A new OTP has been sent');
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    }
  }

  Future<void> _verify() async {
    if (_ctrl.text.length != 6 || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await context.read<AppState>().verifyOtp(widget.mobile, _ctrl.text);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeShell()), (_) => false);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = errorText(e);
          busy = false;
          _ctrl.clear();
        });
      }
    }
  }

  void _autofill() {
    if (demoOtp == null) return;
    _ctrl.text = demoOtp!;
    setState(() {});
    _verify();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      illustration: 'assets/images/consent.svg',
      title: 'Verify your\nnumber',
      subtitle: 'OTP sent to +91 ${widget.mobile.substring(0, 5)} ${widget.mobile.substring(5)}',
      bottom: PrimaryButton(label: 'Verify & continue', loading: busy, onPressed: _ctrl.text.length == 6 ? _verify : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Enter 6 digit OTP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              TextButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.edit_rounded, size: 16), label: const Text('Change number')),
            ],
          ),
          if (demoOtp != null) ...[const SizedBox(height: 8), _DemoOtpCard(otp: demoOtp!, onUse: _autofill)],
          const SizedBox(height: 22),
          _OtpBoxes(
            controller: _ctrl,
            focus: _focus,
            error: error != null,
            onChanged: (v) {
              setState(() => error = null);
              if (v.length == 6) _verify();
            },
          ),
          const SizedBox(height: 14),
          if (error != null) ...[
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    error!,
                    style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Center(
            child: seconds > 0
                ? Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Resend OTP in ',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                        TextSpan(
                          text: '00:${seconds.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  )
                : TextButton.icon(onPressed: _resend, icon: const Icon(Icons.refresh_rounded), label: const Text('Resend OTP')),
          ),
          const SizedBox(height: 18),
          const InfoBanner(text: 'Never share your OTP with anyone. Credit Ventures staff will never ask for it.', icon: Icons.shield_outlined),
        ],
      ),
    );
  }
}

/// Shown only in demo mode (no SMS gateway yet) – looks like an incoming SMS.
class _DemoOtpCard extends StatelessWidget {
  final String otp;
  final VoidCallback onUse;
  const _DemoOtpCard({required this.otp, required this.onUse});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.sms_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CV-CRDVNT · now',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Your Credit Ventures OTP is '),
                      TextSpan(
                        text: otp,
                        style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Demo mode – OTP shown on screen',
                  style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onUse, child: const Text('Auto-fill')),
        ],
      ),
    );
  }
}

class _OtpBoxes extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final bool error;
  final ValueChanged<String> onChanged;
  const _OtpBoxes({required this.controller, required this.focus, required this.error, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => focus.requestFocus(),
      child: Stack(
        children: [
          // invisible field that receives the keyboard input (and SMS autofill)
          Opacity(
            opacity: 0,
            child: TextField(
              controller: controller,
              focusNode: focus,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: onChanged,
              decoration: const InputDecoration(counterText: ''),
            ),
          ),
          LayoutBuilder(
            builder: (_, c) {
              final boxW = ((c.maxWidth - 5 * 8) / 6).clamp(36.0, 54.0);
              return ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (_, v, _) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) {
                    final ch = i < v.text.length ? v.text[i] : '';
                    final active = i == v.text.length && focus.hasFocus;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: boxW,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: error ? AppColors.danger : (active || ch.isNotEmpty ? AppColors.primary : AppColors.border),
                          width: active ? 2 : 1.2,
                        ),
                      ),
                      child: Text(ch, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    );
                  }),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
