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
            // Key Fact Statement only after the admin approves the loan (final terms)
            if (['approved', 'disbursed', 'closed'].contains(status) && l['approved'] is Map && l['approved']['amount'] != null) ...[
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
            const Text('Application details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 10),
            _ApplicationDetails(loan: l, product: context.read<AppState>().product('${l['product']}')),
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

/// Applicant details exactly as saved on the server (admin edits show up here).
class _ApplicationDetails extends StatelessWidget {
  final Map<String, dynamic> loan;
  final Map<String, dynamic>? product;
  const _ApplicationDetails({required this.loan, this.product});

  String _v(dynamic v) => v == null || '$v'.trim().isEmpty ? '—' : '$v';

  @override
  Widget build(BuildContext context) {
    final b = Map<String, dynamic>.from(loan['basic'] ?? {});
    final p = Map<String, dynamic>.from(loan['personal'] ?? {});
    final e = Map<String, dynamic>.from(loan['employment'] ?? {});
    final a = Map<String, dynamic>.from(loan['address'] ?? {});
    final k = Map<String, dynamic>.from(loan['kyc'] ?? {});
    final bank = Map<String, dynamic>.from(loan['bank'] ?? {});
    final pd = Map<String, dynamic>.from(loan['productDetails'] ?? {});
    final fields = List<Map<String, dynamic>>.from(product?['fields'] ?? const []);
    final acc = '${bank['accountNumber'] ?? ''}';

    final sections = <(IconData, String, List<(String, String)>)>[
      (
        Icons.person_outline_rounded,
        'Personal',
        [
          ('Name', _v('${b['firstName'] ?? ''} ${b['lastName'] ?? ''}'.trim())),
          ('Date of birth', fmtDate(b['dob'])),
          ('Gender', titleCase(_v(b['gender']))),
          ('Email', _v(b['email'])),
          ('Education', _v(b['education'])),
          ('Marital status', _v(b['maritalStatus'])),
          ('Monthly income', b['monthlyIncome'] == null ? '—' : inr(asNum(b['monthlyIncome']))),
          ('Employment type', _v(b['employmentType'])),
          ("Father's name", _v(p['fatherName'])),
          ("Mother's name", _v(p['motherName'])),
          ('Residence', titleCase(_v(p['residenceType']))),
          ('Purpose', _v(p['purpose'])),
        ],
      ),
      if (pd.isNotEmpty)
        (
          productIcon('${loan['product']}'),
          '${product?['detailsTitle'] ?? ''}'.isEmpty ? 'Loan details' : '${product?['detailsTitle']}',
          [
            for (final f in fields)
              if (pd[f['key']] != null)
                ('${f['label']}'.replaceAll(RegExp(r'\s*\(.*\)$'), ''), '${f['label']}'.contains('₹') ? inr(asNum(pd[f['key']])) : _v(pd[f['key']])),
          ],
        ),
      if (e['companyName'] != null)
        (
          Icons.work_outline_rounded,
          'Employment',
          [
            ('Company', _v(e['companyName'])),
            ('Sector', _v(e['sector'])),
            ('Industry', _v(e['industryType'])),
            ('Nature of work', _v(e['natureOfWork'])),
            ('Designation', _v(e['designation'])),
            ('Company address', _v('${e['companyAddress'] ?? ''}${e['companyPincode'] != null ? ' - ${e['companyPincode']}' : ''}')),
          ],
        ),
      (
        Icons.home_outlined,
        'Address',
        [
          ('Current address', _v([a['line1'], a['line2'], a['landmark']].where((x) => x != null && '$x'.isNotEmpty).join(', '))),
          ('City / State', _v([a['city'], a['state']].where((x) => x != null).join(', '))),
          ('PIN code', _v(a['pincode'])),
          ('Permanent address', a['sameAsPermanent'] == false ? _v(a['permanentAddress']) : 'Same as current'),
        ],
      ),
      (Icons.badge_outlined, 'KYC', [('PAN', _v(k['panNumber'])), ('Aadhaar', _v(k['aadhaarNumber']))]),
      (
        Icons.account_balance_outlined,
        'Bank account',
        [
          ('Account holder', _v(bank['accountHolderName'])),
          ('Bank', _v(bank['bankName'])),
          ('Account number', acc.length > 4 ? 'XXXX${acc.substring(acc.length - 4)}' : _v(acc)),
          ('IFSC', _v(bank['ifsc'])),
          ('Account type', titleCase(_v(bank['accountType']))),
        ],
      ),
    ];

    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: i == 0,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
                  child: Icon(sections[i].$1, size: 18, color: AppColors.primary),
                ),
                title: Text(sections[i].$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                children: [for (final row in sections[i].$3) KeyValueRow(row.$1, row.$2)],
              ),
            ),
            if (i < sections.length - 1) const Divider(indent: 16, endIndent: 16),
          ],
        ],
      ),
    );
  }
}
