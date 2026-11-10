import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../legal_screen.dart';
import 'flow.dart';
import 'submitted_screen.dart';

/// Key Fact Statement + loan agreement e-sign (typed name) + final submit.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final sign = TextEditingController();
  bool agree = false, busy = false;

  /// Annual percentage rate including fees (IRR of the cash flows).
  double _apr(num net, num emi, int n) {
    if (net <= 0 || emi <= 0 || n <= 0) return 0;
    double r = 0.02;
    for (var i = 0; i < 100; i++) {
      double f = -net.toDouble(), d = 0;
      for (var k = 1; k <= n; k++) {
        f += emi / pow(1 + r, k);
        d += -k * emi / pow(1 + r, k + 1);
      }
      final nr = r - f / d;
      if ((nr - r).abs() < 1e-9) break;
      r = nr;
    }
    return r * 12 * 100;
  }

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
    final apr = _apr(asNum(o['disbursalAmount']) ?? 0, asNum(o['emi']) ?? 0, (asNum(o['tenureMonths']) ?? 0).toInt());
    final acc = '${bank['accountNumber'] ?? ''}';
    return StepScaffold(
      title: 'Review & sign',
      subtitle: 'Please check your loan details before signing',
      step: 8,
      totalSteps: ApplyFlow.totalSteps,
      bottom: PrimaryButton(label: 'Sign & submit application', icon: Icons.draw_rounded, loading: busy, onPressed: _submit),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(22)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Loan amount', style: TextStyle(color: Color(0xFFC3CBFD))),
                Text(inr(o['amount']), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${o['tenureMonths']} months', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              Text('EMI ${inr(o['emi'])}', style: const TextStyle(color: Color(0xFF6EE7B7), fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
          ]),
        ),
        const SizedBox(height: 18),
        const Text('Key Fact Statement', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        const SizedBox(height: 10),
        SectionCard(
          child: Column(children: [
            KeyValueRow('Sanctioned amount', inr(o['amount'])),
            KeyValueRow('Tenure', '${o['tenureMonths']} monthly instalments'),
            KeyValueRow('Interest rate', '${o['interestRate']}% p.a. (reducing balance)'),
            KeyValueRow('Monthly EMI', inr(o['emi'])),
            KeyValueRow('Processing fee', inr(o['processingFee'])),
            KeyValueRow('GST on fee', inr(o['gstOnFee'])),
            KeyValueRow('Net amount disbursed', inr(o['disbursalAmount']), bold: true),
            KeyValueRow('Total interest', inr(o['totalInterest'])),
            KeyValueRow('Total amount repayable', inr(o['totalPayable']), bold: true),
            KeyValueRow('Annual percentage rate (APR)', '${apr.toStringAsFixed(2)}%', bold: true),
            const KeyValueRow('Cooling-off period', '3 days (prepay without penalty)'),
            if ('${s.settings['lendingPartner'] ?? ''}'.isNotEmpty) KeyValueRow('Lender', '${s.settings['lendingPartner']}'),
          ]),
        ),
        const SizedBox(height: 18),
        const Text('Your details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        const SizedBox(height: 10),
        SectionCard(
          child: Column(children: [
            KeyValueRow('Name', '${b['firstName']} ${b['lastName']}'),
            KeyValueRow('Date of birth', fmtDate(b['dob'])),
            KeyValueRow('PAN', '${dig(l, 'kyc.panNumber') ?? '—'}'),
            KeyValueRow('Aadhaar', '${dig(l, 'kyc.aadhaarNumber') ?? '—'}'),
            KeyValueRow('Company', '${dig(l, 'employment.companyName') ?? '—'}'),
            KeyValueRow('City', '${dig(l, 'address.city') ?? '—'}'),
            KeyValueRow('Bank', '${bank['bankName'] ?? ''} · XXXX${acc.length > 4 ? acc.substring(acc.length - 4) : acc}'),
            KeyValueRow('IFSC', '${bank['ifsc'] ?? ''}'),
          ]),
        ),
        const SizedBox(height: 18),
        const Text('Loan agreement', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        const SizedBox(height: 10),
        SectionCard(
          color: const Color(0xFFF8FAFC),
          child: Text(
            'I, ${b['firstName']} ${b['lastName']}, apply for a personal loan of ${inr(o['amount'])} repayable in ${o['tenureMonths']} monthly instalments of ${inr(o['emi'])} at ${o['interestRate']}% p.a. on reducing balance. '
            'I confirm that all information and documents provided by me are true and belong to me. I authorise ${s.settings['companyName'] ?? 'Credit Ventures'} and its lending partner to verify them, obtain my credit report, and disburse the loan only to my bank account listed above. '
            'I understand the final sanction is subject to verification, that I may cancel within the cooling-off period by repaying the principal and proportionate interest, and that delayed payments may attract charges as per the agreement and be reported to credit bureaus.',
            style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF334155)),
          ),
        ),
        const SizedBox(height: 10),
        ConsentTile(
          value: agree,
          onChanged: (v) => setState(() => agree = v),
          text: Text.rich(TextSpan(children: [
            const TextSpan(text: 'I have read and accept the loan agreement, Key Fact Statement, '),
            WidgetSpan(
              child: GestureDetector(
                onTap: () => LegalScreen.open(context, terms: true),
                child: const Text('Terms', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, fontSize: 13.5)),
              ),
            ),
            const TextSpan(text: ' and '),
            WidgetSpan(
              child: GestureDetector(
                onTap: () => LegalScreen.open(context, terms: false),
                child: const Text('Privacy Policy', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, fontSize: 13.5)),
              ),
            ),
            const TextSpan(text: '.'),
          ])),
        ),
        const SizedBox(height: 12),
        AppField(
          controller: sign,
          label: 'Type your full name to e-sign',
          helper: 'Must match: ${b['firstName']} ${b['lastName']}',
          caps: TextCapitalization.words,
          prefix: const Icon(Icons.draw_rounded),
        ),
      ]),
    );
  }
}
