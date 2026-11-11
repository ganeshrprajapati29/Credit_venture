import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../theme.dart';
import '../widgets/common.dart';

class EmiCalculatorScreen extends StatefulWidget {
  const EmiCalculatorScreen({super.key});
  @override
  State<EmiCalculatorScreen> createState() => _EmiCalculatorScreenState();
}

class _EmiCalculatorScreenState extends State<EmiCalculatorScreen> {
  late double amount, rate, months;
  late double minA, maxA;

  @override
  void initState() {
    super.initState();
    final c = context.read<AppState>().loanConfig;
    minA = (asNum(c['minAmount']) ?? 5000).toDouble();
    maxA = max(minA + 1000, (asNum(c['maxAmount']) ?? 200000).toDouble());
    amount = ((minA + maxA) / 2 / 1000).roundToDouble() * 1000;
    rate = (asNum(c['interestRate']) ?? 30).toDouble();
    months = 6;
  }

  int get emi {
    final r = rate / 12 / 100;
    if (r == 0) return (amount / months).ceil();
    return (amount * r * pow(1 + r, months) / (pow(1 + r, months) - 1)).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final total = emi * months;
    final interest = total - amount;
    return Scaffold(
      appBar: AppBar(title: const Text('EMI calculator')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(22)),
          child: Column(children: [
            const Text('Your monthly EMI', style: TextStyle(color: AppColors.onHeroMuted)),
            const SizedBox(height: 4),
            Text(inr(emi), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Row(children: [
                Expanded(flex: max(1, amount.round()), child: Container(height: 10, color: const Color(0xFF6EE7B7))),
                Expanded(flex: max(1, interest.round()), child: Container(height: 10, color: const Color(0xFFFBBF24))),
              ]),
            ),
            const SizedBox(height: 10),
            Row(children: [
              _legend(const Color(0xFF6EE7B7), 'Principal', inr(amount)),
              _legend(const Color(0xFFFBBF24), 'Interest', inr(interest)),
              _legend(Colors.white, 'Total', inr(total)),
            ]),
          ]),
        ),
        const SizedBox(height: 18),
        SectionCard(
          child: Column(children: [
            _slider('Loan amount', inr(amount), amount, minA, maxA, ((maxA - minA) / 1000).round(), (v) => setState(() => amount = v)),
            _slider('Tenure', fmtTenure(months.round()), months, 3, 60, 57, (v) => setState(() => months = v)),
            _slider('Interest rate', '${rate.toStringAsFixed(1)}% p.a.', rate, 10, 40, 60, (v) => setState(() => rate = v)),
          ]),
        ),
        const SizedBox(height: 12),
        const InfoBanner(icon: Icons.info_outline_rounded, text: 'This is an estimate. Your actual EMI depends on the offer you receive after verification.'),
      ]),
    );
  }

  Widget _legend(Color c, String k, String v) => Expanded(
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(k, style: const TextStyle(color: AppColors.onHeroMuted, fontSize: 12)),
          ]),
          Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _slider(String label, String value, double v, double min, double max, int div, ValueChanged<double> onChanged) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600))),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ]),
          Slider(value: v.clamp(min, max), min: min, max: max, divisions: div > 0 ? div : null, onChanged: onChanged),
        ]),
      );
}
