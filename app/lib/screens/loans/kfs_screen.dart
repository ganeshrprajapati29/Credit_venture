import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/kfs.dart';
import 'fee_payment_screen.dart';

/// Shown after approval: the customer reviews the final Key Fact Statement and taps
/// Continue, which records acceptance and opens the processing-fee QR.
class KfsScreen extends StatefulWidget {
  final Map<String, dynamic> loan;
  const KfsScreen({super.key, required this.loan});
  @override
  State<KfsScreen> createState() => _KfsScreenState();
}

class _KfsScreenState extends State<KfsScreen> {
  late Map<String, dynamic> loan = widget.loan;
  bool busy = false;

  Future<void> _continue() async {
    setState(() => busy = true);
    try {
      if (loan['approved']?['termsAcceptedAt'] == null) {
        final r = await Api.instance.post('/loans/${loan['_id']}/accept-terms');
        loan = Map<String, dynamic>.from(r['data']['loan']);
        if (mounted) context.read<AppState>().setLoan(loan);
      }
      if (!mounted) return;
      final fee = Map<String, dynamic>.from(loan['feePayment'] ?? {});
      if (fee['required'] == true && ['unpaid', 'rejected'].contains(fee['status'])) {
        final paid = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => FeePaymentScreen(loan: loan)));
        if (mounted && paid == true) Navigator.pop(context, true);
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final a = Map<String, dynamic>.from(loan['approved'] ?? {});
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Key Fact Statement')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(22)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your approved loan',
                  style: TextStyle(color: AppColors.onHeroMuted, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    inr(asNum(a['amount'])),
                    style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${loan['productName'] ?? 'Loan'} · ${fmtTenure(a['tenureMonths'])} · ${a['interestRate'] ?? '--'}% p.a.',
                  style: const TextStyle(color: AppColors.onHeroSoft, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: KeyFactStatement(loan: loan, lender: '${s.settings['lendingPartner'] ?? ''}'),
          ),
          if ('${a['remarks'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 12),
            InfoBanner(text: 'Note from lender: ${a['remarks']}', icon: Icons.sticky_note_2_outlined),
          ],
          const SizedBox(height: 12),
          const InfoBanner(
            text: 'By tapping Continue you confirm that you have read this Key Fact Statement and accept these loan terms.',
            icon: Icons.verified_user_outlined,
          ),
        ],
      ),
      bottomNavigationBar: BottomAction(
        child: PrimaryButton(label: 'Continue', icon: Icons.arrow_forward_rounded, loading: busy, onPressed: _continue),
      ),
    );
  }
}
