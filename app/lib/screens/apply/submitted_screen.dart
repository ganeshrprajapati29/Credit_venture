import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class SubmittedScreen extends StatelessWidget {
  const SubmittedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final l = s.loan ?? {};
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              SvgPicture.asset('assets/images/success.svg', height: 190),
              const SizedBox(height: 24),
              const Text('Application submitted!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(
                'Your application ${l['loanNumber'] ?? ''} for ${inr(dig(l, 'offer.amount'))} has been received. Our team will verify your documents and update you shortly.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted, height: 1.5, fontSize: 15),
              ),
              const SizedBox(height: 24),
              SectionCard(
                child: Column(
                  children: const [
                    _Next(Icons.fact_check_outlined, 'Document verification', 'Usually within a few working hours'),
                    _Next(Icons.phone_in_talk_outlined, 'Verification call', 'Our team may call you from our official number'),
                    _Next(Icons.account_balance_outlined, 'Disbursal', 'Money is sent to your verified bank account'),
                  ],
                ),
              ),
              const Spacer(),
              PrimaryButton(label: 'Go to home', onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Next extends StatelessWidget {
  final IconData icon;
  final String t;
  final String s;
  const _Next(this.icon, this.t, this.s);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: AppColors.primarySoft,
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(s, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            ],
          ),
        ),
      ],
    ),
  );
}
