import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_state.dart';
import '../theme.dart';

class LegalScreen extends StatelessWidget {
  final bool terms;
  const LegalScreen({super.key, required this.terms});

  static Future<void> open(BuildContext context, {required bool terms}) async {
    final s = context.read<AppState>();
    final url = '${s.legal[terms ? 'termsUrl' : 'privacyUrl'] ?? ''}';
    if (url.startsWith('http')) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => LegalScreen(terms: terms)));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final text = '${s.legal[terms ? 'termsText' : 'privacyText'] ?? ''}'.trim();
    final company = '${s.settings['companyName'] ?? 'Credit Ventures'}';
    final fallback = terms
        ? 'These Terms govern your use of the $company app. Loans are sanctioned at the sole discretion of our lending partner after verification of the information and documents you submit. The interest rate, processing fee, EMI and total repayable amount are shown to you before you sign the loan agreement. Late payment may attract charges as stated in your agreement. You must provide true and complete information.'
        : '$company collects only the information required to process your loan: details you enter, KYC documents you upload, device information and (if permitted) approximate location. We do not access your contacts, SMS, call logs or media. Data is transmitted over HTTPS, stored securely, shared only with our lending partner and credit bureaus with your consent, and retained as required by law. Contact our grievance officer for any concern.';
    return Scaffold(
      appBar: AppBar(title: Text(terms ? 'Terms of Service' : 'Privacy Policy')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(text.isEmpty ? fallback : text, style: const TextStyle(height: 1.6, fontSize: 14.5, color: AppColors.text)),
      ]),
    );
  }
}
