import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../apply/flow.dart';
import 'loan_detail_screen.dart';

class LoansTab extends StatefulWidget {
  const LoansTab({super.key});
  @override
  State<LoansTab> createState() => _LoansTabState();
}

class _LoansTabState extends State<LoansTab> {
  List<Map<String, dynamic>>? loans;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.instance.get('/loans');
      if (mounted) {
        setState(() {
          loans = List<Map<String, dynamic>>.from(r['data']['loans']);
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final draft = s.loan != null && s.loan!['status'] == 'draft';
    return Scaffold(
      appBar: AppBar(title: const Text('My Loans')),
      body: RefreshIndicator(
        onRefresh: () async {
          await _load();
          await s.refreshLoan();
        },
        child: error != null
            ? ListView(children: [SizedBox(height: 480, child: ErrorView(message: error!, onRetry: _load))])
            : loans == null
                ? const LoadingView()
                : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                    if (draft)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => ApplyFlow.open(context),
                          borderRadius: BorderRadius.circular(20),
                          child: SectionCard(
                            color: AppColors.primarySoft,
                            child: Row(children: [
                              const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 30),
                              const SizedBox(width: 12),
                              const Expanded(child: Text('You have an incomplete application. Tap to continue.', style: TextStyle(fontWeight: FontWeight.w700))),
                              const Icon(Icons.chevron_right_rounded),
                            ]),
                          ),
                        ),
                      ),
                    if (loans!.isEmpty && !draft)
                      EmptyView(
                        title: 'No loans yet',
                        subtitle: 'Apply for your first loan in a few minutes',
                        action: SizedBox(width: 200, child: PrimaryButton(label: 'Apply now', onPressed: () => ApplyFlow.open(context))),
                      ),
                    for (final l in loans!)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoanDetailScreen(loanId: '${l['_id']}'))).then((_) => _load()),
                          child: SectionCard(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
                                  child: Icon(productIcon('${l['product']}'), color: AppColors.primary),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(inr(dig(l, 'approved.amount') ?? dig(l, 'offer.amount')), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                                    Text('${l['productName'] ?? 'Personal Loan'} · ${l['loanNumber']}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                                  ]),
                                ),
                                StatusChip('${l['status']}'),
                              ]),
                              const Divider(height: 24),
                              Row(children: [
                                _mini('Tenure', fmtTenure(dig(l, 'approved.tenureMonths') ?? dig(l, 'offer.tenureMonths'))),
                                _mini('EMI', inr(dig(l, 'approved.emi') ?? dig(l, 'offer.emi'))),
                                _mini('Applied', fmtDate(l['submittedAt'] ?? l['createdAt'])),
                              ]),
                            ]),
                          ),
                        ),
                      ),
                  ]),
      ),
    );
  }

  Widget _mini(String k, String v) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 2),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
}
