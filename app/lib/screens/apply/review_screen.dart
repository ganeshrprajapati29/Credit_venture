import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../legal_screen.dart';
import 'submitted_screen.dart';

/// Loan summary + loan agreement e-sign (typed name) + final submit.
/// The Key Fact Statement is shown after approval, with the lender's final terms.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final sign = TextEditingController();
  bool agree = false, busy = false;

  Future<void> _submit() async {
    final s = context.read<AppState>();
    final b = s.loan?['basic'] ?? {};
    final expected = '${b['firstName']} ${b['lastName']}'.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (!agree) return showSnack(context, 'Please accept the loan agreement', error: true);
    if (sign.text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ') != expected) {
      return showSnack(context, 'Type your full name exactly as "${b['firstName']} ${b['lastName']}" to sign', error: true);
    }
    setState(() => busy = true);
    try {
      final r = await Api.instance.post('/loans/current/submit', {'agreementAccepted': true, 'signatureName': sign.text.trim()});
      if (!mounted) return;
      s.setLoan(r['data']['loan']);
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const SubmittedScreen()), (r) => r.isFirst);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final l = s.loan ?? {};
    final o = Map<String, dynamic>.from(l['offer'] ?? {});
    final b = Map<String, dynamic>.from(l['basic'] ?? {});
    final bank = Map<String, dynamic>.from(l['bank'] ?? {});
    final acc = '${bank['accountNumber'] ?? ''}';
    return StepScaffold(
      title: 'Review & sign',
      subtitle: 'Please check your loan details before signing',
      stepKey: 'review',
      bottom: PrimaryButton(label: 'Sign & submit application', icon: Icons.draw_rounded, loading: busy, onPressed: _submit),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Loan amount applied',
                        style: TextStyle(color: AppColors.onHeroMuted, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (l['productName'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          '${l['productName']}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    inr(o['amount']),
                    style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1.1),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      _heroStat('Tenure', fmtTenure(o['tenureMonths'])),
                      _heroStat('Monthly EMI', inr(o['emi']), highlight: true),
                      _heroStat('Interest', '${o['interestRate'] ?? '--'}% p.a.'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 15, color: AppColors.onHeroMuted),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Final amount, interest and fee are confirmed after approval in your Key Fact Statement.',
                        style: TextStyle(color: AppColors.onHeroMuted, fontSize: 12, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text('Your details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 10),
          SectionCard(
            child: Column(
              children: [
                KeyValueRow('Name', '${b['firstName']} ${b['lastName']}'),
                KeyValueRow('Date of birth', fmtDate(b['dob'])),
                KeyValueRow('PAN', '${dig(l, 'kyc.panNumber') ?? '—'}'),
                KeyValueRow('Aadhaar', '${dig(l, 'kyc.aadhaarNumber') ?? '—'}'),
                KeyValueRow('Loan type', '${l['productName'] ?? 'Personal Loan'}'),
                if (dig(l, 'employment.companyName') != null) KeyValueRow('Company', '${dig(l, 'employment.companyName')}'),
                for (final f in List<Map<String, dynamic>>.from(s.product('${l['product']}')?['fields'] ?? const []))
                  if (dig(l, 'productDetails.${f['key']}') != null)
                    KeyValueRow(
                      '${f['label']}'.replaceAll(RegExp(r'\s*\(.*\)$'), ''),
                      f['label'].toString().contains('₹') ? inr(asNum(dig(l, 'productDetails.${f['key']}'))) : '${dig(l, 'productDetails.${f['key']}')}',
                    ),
                KeyValueRow('City', '${dig(l, 'address.city') ?? '—'}'),
                KeyValueRow('Bank', '${bank['bankName'] ?? ''} · XXXX${acc.length > 4 ? acc.substring(acc.length - 4) : acc}'),
                KeyValueRow('IFSC', '${bank['ifsc'] ?? ''}'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text('Loan agreement', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 10),
          SectionCard(
            color: const Color(0xFFF8FAFC),
            child: Text(
              'I, ${b['firstName']} ${b['lastName']}, apply for a ${(l['productName'] ?? 'personal loan').toString().toLowerCase()} of ${inr(o['amount'])} repayable in ${o['tenureMonths']} monthly instalments of ${inr(o['emi'])} at ${o['interestRate']}% p.a. on reducing balance. '
              'I confirm that all information and documents provided by me are true and belong to me. I authorise ${s.settings['companyName'] ?? 'Credit Ventures'} and its lending partner to verify them, obtain my credit report, and disburse the loan only to my bank account listed above. '
              'I understand the final sanction is subject to verification, that I may cancel within the cooling-off period by repaying the principal and proportionate interest, and that delayed payments may attract charges as per the agreement and be reported to credit bureaus.',
              style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF334155)),
            ),
          ),
          const SizedBox(height: 10),
          ConsentTile(
            value: agree,
            onChanged: (v) => setState(() => agree = v),
            text: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'I have read and accept the loan agreement, '),
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: () => LegalScreen.open(context, terms: true),
                      child: const Text(
                        'Terms',
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
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          AppField(
            controller: sign,
            label: 'Type your full name to e-sign',
            helper: 'Must match: ${b['firstName']} ${b['lastName']}',
            caps: TextCapitalization.words,
            prefix: const Icon(Icons.draw_rounded),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String k, String v, {bool highlight = false}) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(color: AppColors.onHeroMuted, fontSize: 11.5)),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            v,
            style: TextStyle(color: highlight ? const Color(0xFF6EE7B7) : Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}
