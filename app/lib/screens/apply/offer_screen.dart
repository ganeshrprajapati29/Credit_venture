import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'flow.dart';

class OfferScreen extends StatefulWidget {
  const OfferScreen({super.key});
  @override
  State<OfferScreen> createState() => _OfferScreenState();
}

class _OfferScreenState extends State<OfferScreen> {
  late num minA, maxA, step;
  late double amount;
  int? tenure;
  List<Map<String, dynamic>> tenures = [];
  Map<String, dynamic>? quote;
  bool loadingQuote = false, busy = false, showAll = false;
  String promo = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    final o = Map<String, dynamic>.from(s.loan?['offer'] ?? {});
    minA = asNum(o['minAmount']) ?? asNum(s.loanConfig['minAmount']) ?? 5000;
    maxA = asNum(o['maxAmount']) ?? minA;
    step = asNum(s.loanConfig['amountStep']) ?? 1000;
    amount = (asNum(o['amount']) ?? maxA).toDouble().clamp(minA.toDouble(), maxA.toDouble());
    tenure = (o['tenureMonths'] as num?)?.toInt();
    promo = '${o['promoCode'] ?? ''}';
    _fetch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onAmount(double v) {
    setState(() => amount = v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _fetch);
  }

  Future<void> _fetch() async {
    setState(() => loadingQuote = true);
    try {
      final r = await Api.instance.get('/loans/quote', query: {'amount': amount.round(), if (tenure != null) 'tenure': tenure});
      if (!mounted) return;
      setState(() {
        tenures = List<Map<String, dynamic>>.from(r['data']['tenures']);
        tenure ??= tenures.isNotEmpty ? (tenures.first['months'] as num).toInt() : null;
        quote = Map<String, dynamic>.from(r['data']['quote']);
        if (quote!['tenureMonths'] != tenure) _fetchQuoteOnly();
      });
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => loadingQuote = false);
    }
  }

  Future<void> _fetchQuoteOnly() async {
    try {
      final r = await Api.instance.get('/loans/quote', query: {'amount': amount.round(), 'tenure': tenure});
      if (mounted) setState(() => quote = Map<String, dynamic>.from(r['data']['quote']));
    } catch (_) {}
  }

  Future<void> _promo() async {
    final ctrl = TextEditingController(text: promo);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Promo / referral code'),
        content: TextField(controller: ctrl, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: 'Enter code')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Apply')),
        ],
      ),
    );
    if (v != null) setState(() => promo = v);
  }

  Future<void> _confirm() async {
    if (tenure == null) return;
    setState(() => busy = true);
    try {
      final r = await Api.instance.put('/loans/current/offer', {'amount': amount.round(), 'tenureMonths': tenure, if (promo.isNotEmpty) 'promoCode': promo});
      if (!mounted) return;
      final loan = Map<String, dynamic>.from(r['data']['loan']);
      context.read<AppState>().setLoan(loan);
      final go = await showModalBottomSheet<bool>(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => const _StepsSheet(),
      );
      if (go == true && mounted) ApplyFlow.next(context, loan, 'offer');
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final divisions = ((maxA - minA) / step).round();
    final visible = showAll ? tenures : tenures.take(2).toList();
    return StepScaffold(
      title: 'Your loan offer',
      subtitle: 'Choose the amount and EMI that suits you',
      stepKey: 'offer',
      bottom: PrimaryButton(label: 'Confirm and proceed', icon: Icons.arrow_forward_rounded, loading: busy, onPressed: quote == null ? null : _confirm),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(24)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Choose your loan amount', style: TextStyle(color: AppColors.onHeroMuted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(inr(amount.round()), style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1)),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF6EE7B7),
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: Colors.white24,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              ),
              child: Slider(
                min: minA.toDouble(),
                max: maxA.toDouble() <= minA.toDouble() ? minA.toDouble() + 1 : maxA.toDouble(),
                divisions: divisions > 0 ? divisions : null,
                value: amount,
                onChanged: maxA <= minA ? null : _onAmount,
              ),
            ),
            Row(children: [
              Text('Min ${inr(minA)}', style: const TextStyle(color: AppColors.onHeroMuted, fontSize: 12.5)),
              const Spacer(),
              Text('Max ${inr(maxA)}', style: const TextStyle(color: AppColors.onHeroMuted, fontSize: 12.5)),
            ]),
          ]),
        ),
        const SizedBox(height: 22),
        Row(children: [
          const Expanded(child: Text('Loan tenure', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          const Text('EMI', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          if (loadingQuote) const Padding(padding: EdgeInsets.only(left: 8), child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))),
        ]),
        const SizedBox(height: 12),
        for (final t in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() => tenure = (t['months'] as num).toInt());
                _fetchQuoteOnly();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: tenure == t['months'] ? AppColors.primarySoft : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: tenure == t['months'] ? AppColors.primaryDeep : AppColors.border, width: tenure == t['months'] ? 2 : 1),
                ),
                child: Row(children: [
                  Icon(tenure == t['months'] ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: tenure == t['months'] ? AppColors.primaryDeep : AppColors.textMuted),
                  const SizedBox(width: 12),
                  Expanded(child: Text(fmtTenure(t['months']), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                  Text(inr(t['emi']), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ),
        if (tenures.length > 2)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => showAll = !showAll),
              icon: Icon(showAll ? Icons.expand_less_rounded : Icons.expand_more_rounded),
              label: Text(showAll ? 'Show less' : 'See ${tenures.length - 2} more'),
            ),
          ),
        if (quote != null) ...[
          const SizedBox(height: 8),
          SectionCard(
            child: Column(children: [
              KeyValueRow('Loan amount', inr(quote!['amount'])),
              KeyValueRow('Interest rate', '${quote!['interestRate']}% p.a. (reducing)'),
              KeyValueRow('Total interest', inr(quote!['totalInterest'])),
              KeyValueRow('Processing fee', inr(quote!['processingFee'])),
              KeyValueRow('GST on fee', inr(quote!['gstOnFee'])),
              const Divider(height: 18),
              KeyValueRow('Amount you receive', inr(quote!['disbursalAmount']), bold: true),
              KeyValueRow('Total repayable', inr(quote!['totalPayable']), bold: true),
            ]),
          ),
        ],
        const SizedBox(height: 6),
        TextButton(
          onPressed: _promo,
          child: Text(promo.isEmpty ? 'Have a promo/referral code?' : 'Promo code: $promo (change)', style: const TextStyle(decoration: TextDecoration.underline)),
        ),
        const InfoBanner(
          icon: Icons.info_outline_rounded,
          text: 'The loan amount and EMI shown are indicative. The final offer is confirmed after document verification and shown in your loan agreement before you sign.',
        ),
      ]),
    );
  }
}

class _StepsSheet extends StatelessWidget {
  const _StepsSheet();
  @override
  Widget build(BuildContext context) {
    const steps = ['Basic information', 'Submit KYC', 'Add bank account', 'Review and sign agreement'];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
            child: const Icon(Icons.rocket_launch_rounded, color: AppColors.primary, size: 34),
          ),
          const SizedBox(height: 18),
          const Text('Great! You are just 4 steps away from getting the loan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.3)),
          const SizedBox(height: 18),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                CircleAvatar(radius: 14, backgroundColor: const Color(0xFFF1F5F9), child: Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text))),
                const SizedBox(width: 14),
                Text(steps[i], style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
              ]),
            ),
          const SizedBox(height: 18),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Let's go")),
        ]),
      ),
    );
  }
}
