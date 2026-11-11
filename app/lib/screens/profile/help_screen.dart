import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faqs = [
    ('Who can apply?', 'Indian residents aged 21 years and above with a regular monthly income, a valid PAN, Aadhaar and a bank account in their own name.'),
    ('Which documents are needed?', 'Aadhaar card (front & back), PAN card, a live selfie and a cancelled cheque / passbook / bank statement. A salary slip helps faster approval.'),
    ('How long does approval take?', 'Most applications are verified within a few working hours. You will get an update in the app at every step.'),
    ('How do I pay my EMI?', 'Pay to the account / UPI shown on the Pay EMI screen, then upload the screenshot with the UTR number. We verify it and mark your EMI as paid.'),
    ('Will you contact my family or friends?', 'Never. We do not access your contacts, SMS or call logs. We only contact you on your registered mobile number and email.'),
    ('Can I close my loan early?', 'Yes. Contact support for the foreclosure amount. During the cooling-off period you can exit without any penalty.'),
  ];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final sp = s.support;
    final g = Map<String, dynamic>.from(s.settings['grievanceOfficer'] ?? {});
    final phone = '${sp['phone'] ?? ''}'.replaceAll(' ', '');
    final wa = '${sp['whatsapp'] ?? ''}'.replaceAll(RegExp(r'[^0-9]'), '');
    return Scaffold(
      appBar: AppBar(title: const Text('Help & support')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(22)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('We are here to help', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${sp['hours'] ?? ''}', style: const TextStyle(color: AppColors.onHeroMuted)),
            const SizedBox(height: 16),
            Row(children: [
              if (phone.isNotEmpty) _btn(Icons.call_rounded, 'Call', () => launchUrl(Uri.parse('tel:$phone'))),
              if ('${sp['email'] ?? ''}'.isNotEmpty) _btn(Icons.mail_rounded, 'Email', () => launchUrl(Uri.parse('mailto:${sp['email']}'))),
              if (wa.isNotEmpty) _btn(Icons.chat_rounded, 'WhatsApp', () => launchUrl(Uri.parse('https://wa.me/$wa'), mode: LaunchMode.externalApplication)),
            ]),
          ]),
        ),
        const SizedBox(height: 18),
        const Text('Frequently asked questions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        SectionCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            for (final f in _faqs)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text(f.$1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  children: [Text(f.$2, style: const TextStyle(color: AppColors.textMuted, height: 1.5))],
                ),
              ),
          ]),
        ),
        const SizedBox(height: 18),
        const Text('Grievance redressal', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        SectionCard(
          child: Column(children: [
            KeyValueRow('Officer', '${g['name'] ?? '—'}'.isEmpty ? '—' : '${g['name']}'),
            KeyValueRow('Email', '${g['email'] ?? ''}'.isEmpty ? '${sp['email'] ?? '—'}' : '${g['email']}'),
            KeyValueRow('Phone', '${g['phone'] ?? ''}'.isEmpty ? '${sp['phone'] ?? '—'}' : '${g['phone']}'),
            if ('${sp['address'] ?? ''}'.isNotEmpty) KeyValueRow('Address', '${sp['address']}'),
            if ('${s.settings['lendingPartner'] ?? ''}'.isNotEmpty) KeyValueRow('Lending partner', '${s.settings['lendingPartner']}'),
          ]),
        ),
        const SizedBox(height: 12),
        const InfoBanner(
          icon: Icons.warning_amber_rounded,
          color: AppColors.warning,
          text: 'We never ask for your MPIN, OTP or card details over call. Never pay any upfront fee to anyone to get a loan approved.',
        ),
      ]),
    );
  }

  Widget _btn(IconData icon, String label, VoidCallback onTap) => Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Material(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(children: [
                  Icon(icon, color: Colors.white),
                  const SizedBox(height: 4),
                  Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
                ]),
              ),
            ),
          ),
        ),
      );
}
