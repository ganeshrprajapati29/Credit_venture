import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/kfs.dart';
import '../../widgets/loan_tracker.dart';
import 'payment_screen.dart';

class LoanDetailScreen extends StatefulWidget {
  final String loanId;
  const LoanDetailScreen({super.key, required this.loanId});
  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
  Map<String, dynamic>? loan;
  List<Map<String, dynamic>> payments = [];
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.instance.get('/loans/${widget.loanId}');
      if (!mounted) return;
      setState(() {
        loan = Map<String, dynamic>.from(r['data']['loan']);
        payments = List<Map<String, dynamic>>.from(r['data']['payments'] ?? []);
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel application?'),
        content: const Text('Your application will be withdrawn. You can apply again later.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, cancel', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await Api.instance.post('/loans/${widget.loanId}/cancel', {'reason': 'Cancelled by customer'});
      if (!mounted) return;
      await context.read<AppState>().refreshLoan();
      if (mounted) {
        showSnack(context, 'Application cancelled');
        _load();
      }
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorView(message: error!, onRetry: _load),
      );
    }
    if (loan == null) return Scaffold(appBar: AppBar(), body: const LoadingView());
    final l = loan!;
    final status = '${l['status']}';
    final schedule = List<Map<String, dynamic>>.from(l['schedule'] ?? []);
    final approved = l['approved'] is Map && l['approved']['amount'] != null;
    final terms = Map<String, dynamic>.from(approved ? l['approved'] : (l['offer'] ?? {}));
    final history = List<Map<String, dynamic>>.from(l['history'] ?? []).reversed.toList();
    final pendingProofs = payments.where((p) => p['status'] == 'pending').map((p) => p['installmentNo']).toSet();

    return Scaffold(
      appBar: AppBar(title: Text('${l['productName'] ?? 'Loan'} · ${l['loanNumber']}')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(22)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(approved ? 'Approved amount' : 'Requested amount', style: const TextStyle(color: AppColors.onHeroMuted)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                        child: StatusChip(status),
                      ),
                    ],
                  ),
                  Text(
                    inr(terms['amount']),
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _hero('Tenure', fmtTenure(terms['tenureMonths'])),
                      _hero('EMI', inr(terms['emi'])),
                      _hero('Interest', '${terms['interestRate'] ?? '-'}% p.a.'),
                    ],
                  ),
                ],
              ),
            ),
            if (status == 'rejected' && l['rejectionReason'] != null) ...[
              const SizedBox(height: 14),
              InfoBanner(text: 'Reason: ${l['rejectionReason']}', icon: Icons.info_outline_rounded, color: AppColors.danger),
            ],
            if (status == 'approved') ...[
              const SizedBox(height: 16),
              SectionCard(
                child: ApprovedOfferCard(loan: l, onPaid: _load),
              ),
            ],
            if (['submitted', 'under_review', 'approved', 'disbursed'].contains(status)) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text('Application status', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  ),
                  StatusLabel(text: loanStatusLabel(l, context.read<AppState>().product('${l['product']}'))),
                ],
              ),
              const SizedBox(height: 10),
              SectionCard(
                child: LoanTracker(loan: l, product: context.read<AppState>().product('${l['product']}')),
              ),
            ],
            if (['submitted', 'under_review', 'disbursed', 'closed'].contains(status) ||
                (status == 'approved' && l['approved']?['termsAcceptedAt'] != null)) ...[
              const SizedBox(height: 18),
              const Text('Key Fact Statement', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 10),
              SectionCard(
                child: KeyFactStatement(loan: l, lender: '${context.read<AppState>().settings['lendingPartner'] ?? ''}'),
              ),
            ],
            if (l['disbursal'] is Map && l['disbursal']['utr'] != null) ...[
              const SizedBox(height: 16),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Disbursal', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 6),
                    KeyValueRow('Amount credited', inr(dig(l, 'disbursal.amount'))),
                    KeyValueRow('UTR', '${dig(l, 'disbursal.utr')}'),
                    KeyValueRow('Date', fmtDate(dig(l, 'disbursal.date'))),
                  ],
                ),
              ),
            ],
            if (schedule.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text('Repayment schedule', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 10),
              SectionCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    for (final i in schedule)
                      Builder(
                        builder: (_) {
                          final due = DateTime.tryParse('${i['dueDate']}');
                          final overdue = i['status'] != 'paid' && due != null && due.isBefore(DateTime.now());
                          final underReview = pendingProofs.contains(i['installmentNo']);
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: i['status'] == 'paid' ? AppColors.accentSoft : AppColors.primarySoft,
                              child: Text(
                                '${i['installmentNo']}',
                                style: TextStyle(fontWeight: FontWeight.w800, color: i['status'] == 'paid' ? AppColors.accentDark : AppColors.primary),
                              ),
                            ),
                            title: Text(inr(i['amount']), style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text(i['status'] == 'paid' ? 'Paid on ${fmtDate(i['paidAt'])}' : 'Due ${fmtDate(i['dueDate'])}'),
                            trailing: i['status'] == 'paid'
                                ? const StatusChip('paid')
                                : underReview
                                ? const StatusChip('pending')
                                : status == 'disbursed'
                                ? TextButton(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PaymentScreen(loan: l, installment: i),
                                      ),
                                    ).then((_) => _load()),
                                    child: Text(overdue ? 'Pay now' : 'Pay', style: TextStyle(color: overdue ? AppColors.danger : AppColors.primary)),
                                  )
                                : const StatusChip('pending'),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
            if (payments.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text('Payments submitted', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 10),
              SectionCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    for (final p in payments)
                      ListTile(
                        title: Text(inr(p['amount']), style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('UTR ${p['utr']} · ${fmtDate(p['createdAt'])}${p['remarks'] != null ? '\n${p['remarks']}' : ''}'),
                        trailing: StatusChip('${p['status']}'),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            const Text('Timeline', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 10),
            SectionCard(
              child: Column(
                children: [
                  for (var i = 0; i < history.length; i++)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(color: i == 0 ? AppColors.accent : AppColors.primary, shape: BoxShape.circle),
                            ),
                            if (i < history.length - 1) Container(width: 2, height: 40, color: AppColors.border),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(titleCase('${history[i]['status']}'), style: const TextStyle(fontWeight: FontWeight.w700)),
                                if (history[i]['remarks'] != null && history[i]['by'] != 'system')
                                  Text('${history[i]['remarks']}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                                Text(fmtDateTime(history[i]['at']), style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (status == 'submitted') ...[
              const SizedBox(height: 18),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: _cancel,
                child: const Text('Cancel application'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _hero(String k, String v) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(color: AppColors.onHeroMuted, fontSize: 12)),
        Text(
          v,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
