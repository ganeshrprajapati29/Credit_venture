import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../home/home_shell.dart';

/// Login with MPIN, or create an MPIN (enter + confirm) for new users.
class MpinScreen extends StatefulWidget {
  final String mobile;
  final bool isLogin;
  const MpinScreen({super.key, required this.mobile, required this.isLogin});
  @override
  State<MpinScreen> createState() => _MpinScreenState();
}

class _MpinScreenState extends State<MpinScreen> {
  String pin = '';
  String? firstPin; // for registration confirm step
  bool busy = false;
  String? error;

  String get title => widget.isLogin ? 'Enter your MPIN' : (firstPin == null ? 'Create a 4-digit MPIN' : 'Confirm your MPIN');
  String get subtitle => widget.isLogin
      ? 'Welcome back! Login to +91 ${widget.mobile}'
      : (firstPin == null ? 'You will use this MPIN to login securely' : 'Re-enter the MPIN to confirm');

  void _tap(String d) {
    if (busy || pin.length >= 4) return;
    setState(() {
      error = null;
      pin += d;
    });
    if (pin.length == 4) _complete();
  }

  void _back() {
    if (pin.isEmpty || busy) return;
    setState(() => pin = pin.substring(0, pin.length - 1));
  }

  Future<void> _complete() async {
    final s = context.read<AppState>();
    if (!widget.isLogin && firstPin == null) {
      if (RegExp(r'^(\d)\1{3}$').hasMatch(pin) || ['1234', '4321', '0123'].contains(pin)) {
        setState(() {
          error = 'Too easy to guess. Choose a different MPIN.';
          pin = '';
        });
        return;
      }
      await Future.delayed(const Duration(milliseconds: 150));
      setState(() {
        firstPin = pin;
        pin = '';
      });
      return;
    }
    if (!widget.isLogin && pin != firstPin) {
      setState(() {
        error = 'MPINs do not match. Try again.';
        pin = '';
        firstPin = null;
      });
      return;
    }
    setState(() => busy = true);
    try {
      if (widget.isLogin) {
        await s.login(widget.mobile, pin);
      } else {
        await s.register(widget.mobile, pin);
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeShell()), (_) => false);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = errorText(e);
          pin = '';
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white),
      body: SafeArea(
        child: Column(children: [
          const SizedBox(height: 8),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(22)),
            child: const Icon(Icons.lock_rounded, color: AppColors.primary, size: 34),
          ),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 32),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < 4; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < pin.length ? (error != null ? AppColors.danger : AppColors.primary) : Colors.white,
                  border: Border.all(color: i < pin.length ? Colors.transparent : const Color(0xFFCBD5E1), width: 2),
                ),
              ),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            height: 40,
            child: busy
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                : error != null
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                      )
                    : null,
          ),
          const Spacer(),
          if (widget.isLogin)
            TextButton(
              onPressed: () => showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Forgot MPIN?'),
                  content: Text('For your security, MPIN reset is done by our support team after verifying your identity.\n\nCall: ${s.support['phone'] ?? ''}\nEmail: ${s.support['email'] ?? ''}'),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                ),
              ),
              child: const Text('Forgot MPIN?'),
            ),
          _Keypad(onDigit: _tap, onBack: _back),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBack;
  const _Keypad({required this.onDigit, required this.onBack});

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {VoidCallback? onTap, Widget? child}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Material(
              color: label.isEmpty ? Colors.transparent : const Color(0xFFF5F6FB),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onTap,
                child: SizedBox(height: 60, child: Center(child: child ?? Text(label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)))),
              ),
            ),
          ),
        );
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(children: [
        for (final r in rows) Row(children: [for (final d in r) key(d, onTap: () => onDigit(d))]),
        Row(children: [
          key(''),
          key('0', onTap: () => onDigit('0')),
          key('⌫', onTap: onBack, child: const Icon(Icons.backspace_outlined)),
        ]),
      ]),
    );
  }
}
