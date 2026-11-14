import 'dart:math';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../theme.dart';
import 'common.dart';

/// Annual percentage rate (IRR of the cash flows, including the processing fee).
double aprOf({required num amount, required num fee, required num emi, required int months}) {
  final net = amount - fee;
  if (net <= 0 || emi <= 0 || months <= 0) return 0;
  double r = 0.02;
  for (var i = 0; i < 100; i++) {
    double f = -net.toDouble(), d = 0;
    for (var k = 1; k <= months; k++) {
      f += emi / pow(1 + r, k);
      d += -k * emi / pow(1 + r, k + 1);
    }
    if (d == 0) break;
    final nr = r - f / d;
    if ((nr - r).abs() < 1e-9) {
      r = nr;
      break;
    }
    r = nr;
  }
  return r.isFinite && r > 0 ? r * 12 * 100 : 0;
}

/// Key Fact Statement built from the lender-approved terms (or the indicative offer before approval).
class KeyFactStatement extends StatelessWidget {
  final Map<String, dynamic> loan;
  final String? lender;
  const KeyFactStatement({super.key, required this.loan, this.lender});

  bool get approved => loan['approved'] is Map && loan['approved']['amount'] != null;

  @override
  Widget build(BuildContext context) {
    final t = Map<String, dynamic>.from(approved ? loan['approved'] : (loan['offer'] ?? {}));
    final fee = approved ? (asNum(loan['feePayment']?['amount']) ?? asNum(t['processingFee']) ?? 0) : (asNum(t['totalFee']) ?? 0);
    final amount = asNum(t['amount']) ?? 0;
    final months = (asNum(t['tenureMonths']) ?? 0).toInt();
    final emi = asNum(t['emi']) ?? 0;
    final total = asNum(t['totalPayable']) ?? emi * months;
    final interest = total - amount;
    // after approval the fee is paid separately, so the full sanctioned amount is disbursed
    final disbursal = approved ? amount : (asNum(t['disbursalAmount']) ?? amount - fee);
    final apr = aprOf(amount: amount, fee: fee, emi: emi, months: months);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: approved ? AppColors.accentSoft : const Color(0xFFFFF7E6), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Icon(approved ? Icons.verified_rounded : Icons.info_outline_rounded, size: 16, color: approved ? AppColors.accentDark : const Color(0xFFB45309)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  approved ? 'Final terms approved by the lender' : 'Indicative terms – final terms are shared after approval',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: approved ? AppColors.accentDark : const Color(0xFFB45309)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        KeyValueRow('Sanctioned loan amount', inr(amount), bold: true),
        KeyValueRow('Amount disbursed to your bank', inr(disbursal), bold: true),
        KeyValueRow('Interest rate (reducing)', '${t['interestRate'] ?? '--'}% p.a.'),
        KeyValueRow('Tenure', fmtTenure(months)),
        KeyValueRow('Monthly EMI', inr(emi)),
        KeyValueRow('Processing fee (incl. GST)', fee > 0 ? inr(fee) : 'Nil'),
        if (approved && fee > 0) const KeyValueRow('Fee payment', 'By UPI, before disbursal'),
        KeyValueRow('Total interest', inr(interest)),
        KeyValueRow('Total amount repayable', inr(total), bold: true),
        KeyValueRow('APR (incl. fee)', '${apr.toStringAsFixed(2)}%', bold: true),
        const KeyValueRow('Cooling-off period', '3 days'),
        if ((lender ?? '').isNotEmpty) KeyValueRow('Lender', lender!),
        if (approved && loan['approved']['termsAcceptedAt'] != null) KeyValueRow('Accepted on', fmtDateTime(loan['approved']['termsAcceptedAt'])),
      ],
    );
  }
}
