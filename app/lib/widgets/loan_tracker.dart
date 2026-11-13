import 'package:flutter/material.dart';

import '../core/format.dart';
import '../screens/loans/fee_payment_screen.dart';
import '../theme.dart';
import 'common.dart';

enum StepState { done, current, todo }

class TrackerStep {
  final String label;
  final StepState state;
  final String? caption;
  const TrackerStep(this.label, this.state, [this.caption]);
}

/// Customer-facing status label for a loan.
String loanStatusLabel(Map<String, dynamic> loan, [Map<String, dynamic>? product]) {
  final status = '${loan['status']}';
  final fee = Map<String, dynamic>.from(loan['feePayment'] ?? {});
  switch (status) {
    case 'submitted':
      return 'Pending';
    case 'under_review':
      final steps = List<String>.from(product?['reviewSteps'] ?? const []);
      final i = (asNum(loan['stage']) ?? 0).toInt();
      return i < steps.length ? steps[i] : 'In review';
    case 'approved':
      if (fee['required'] == true) {
        return switch ('${fee['status']}') {
          'unpaid' => 'Approved · Pay fee',
          'rejected' => 'Fee payment failed',
          'submitted' => 'Verifying payment',
          _ => 'Disbursal in process',
        };
      }
      return 'Disbursal in process';
    case 'disbursed':
      return 'Active';
    default:
      return titleCase(status);
  }
}

/// Builds the dynamic timeline: Applied → product review steps → Approved → Processing fee → Disbursed.
List<TrackerStep> trackerSteps(Map<String, dynamic> loan, Map<String, dynamic>? product) {
  final status = '${loan['status']}';
  final review = List<String>.from(product?['reviewSteps'] ?? const ['Document verification']);
  final fee = Map<String, dynamic>.from(loan['feePayment'] ?? {});
  final feeRequired = fee['required'] == true || (status != 'approved' && status != 'disbursed' && status != 'closed');
  final labels = <String>[
    'Application submitted',
    ...review,
    'Loan approved',
    if (feeRequired && fee['status'] != 'waived') 'Processing fee',
    'Money disbursed',
  ];

  int current; // index of the step in progress
  switch (status) {
    case 'submitted':
      current = 1;
      break;
    case 'under_review':
      final st = (asNum(loan['stage']) ?? 0).toInt();
      current = 1 + (st < 0 ? 0 : (st >= review.length ? review.length - 1 : st));
      break;
    case 'approved':
      final feeIdx = labels.indexOf('Processing fee');
      final feeDone = ['verified', 'waived'].contains('${fee['status']}');
      current = feeIdx >= 0 && !feeDone ? feeIdx : labels.length - 1;
      break;
    case 'disbursed':
    case 'closed':
      current = labels.length; // everything done
      break;
    default:
      current = 1;
  }

  final captions = <int, String>{};
  final approvedIdx = labels.indexOf('Loan approved');
  if (current > approvedIdx && loan['approved'] is Map) {
    captions[approvedIdx] = '${inr(asNum(loan['approved']['amount']))} for ${fmtTenure(loan['approved']['tenureMonths'])}';
  }
  final feeIdx = labels.indexOf('Processing fee');
  if (feeIdx >= 0 && status == 'approved') {
    captions[feeIdx] = switch ('${fee['status']}') {
      'unpaid' => 'Pay ${inr(asNum(fee['amount']))} to continue',
      'submitted' => 'Payment received, verifying',
      'rejected' => 'Payment could not be verified',
      _ => 'Paid',
    };
  }
  if (current < labels.length && current > 0 && current <= review.length && '${loan['stageNote'] ?? ''}'.isNotEmpty) {
    captions[current] = '${loan['stageNote']}';
  }

  return [
    for (var i = 0; i < labels.length; i++)
      TrackerStep(labels[i], i < current ? StepState.done : (i == current ? StepState.current : StepState.todo), captions[i]),
  ];
}

/// Vertical timeline.
class LoanTracker extends StatelessWidget {
  final Map<String, dynamic> loan;
  final Map<String, dynamic>? product;
  final bool compact;
  const LoanTracker({super.key, required this.loan, this.product, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final steps = trackerSteps(loan, product);
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 26,
                  child: Column(
                    children: [
                      _dot(steps[i].state),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            color: steps[i].state == StepState.done ? AppColors.accent : const Color(0xFFE2DCEB),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: i < steps.length - 1 ? (compact ? 10 : 14) : 0, top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: steps[i].state == StepState.current ? FontWeight.w800 : FontWeight.w600,
                            color: steps[i].state == StepState.todo ? AppColors.textMuted : AppColors.text,
                          ),
                        ),
                        if (steps[i].caption != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            steps[i].caption!,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: steps[i].state == StepState.current ? AppColors.primary : AppColors.textMuted,
                              fontWeight: steps[i].state == StepState.current ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dot(StepState s) => switch (s) {
    StepState.done => const CircleAvatar(radius: 12, backgroundColor: AppColors.accent, child: Icon(Icons.check_rounded, size: 15, color: Colors.white)),
    StepState.current => Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: AppColors.primary, width: 6),
      ),
    ),
    StepState.todo => Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: const Color(0xFFD6CFE1), width: 2)),
    ),
  };
}

/// Approved terms + processing-fee call to action. Shown while status == approved.
class ApprovedOfferCard extends StatelessWidget {
  final Map<String, dynamic> loan;
  final VoidCallback? onPaid;
  const ApprovedOfferCard({super.key, required this.loan, this.onPaid});

  @override
  Widget build(BuildContext context) {
    final a = Map<String, dynamic>.from(loan['approved'] ?? {});
    final fee = Map<String, dynamic>.from(loan['feePayment'] ?? {});
    final feeStatus = '${fee['status'] ?? ''}';
    final needsPay = fee['required'] == true && (feeStatus == 'unpaid' || feeStatus == 'rejected');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFE6F4EE), Color(0xFFF4FAF7)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCFE7DC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified_rounded, color: AppColors.accentDark, size: 18),
                  SizedBox(width: 6),
                  Text('Your approved loan', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.accentDark)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _term('Amount', inr(asNum(a['amount']))),
                  _term('Tenure', fmtTenure(a['tenureMonths'])),
                  _term('EMI', inr(asNum(a['emi']))),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _term('Interest', '${a['interestRate'] ?? '-'}% p.a.'),
                  _term('Processing fee', fee['required'] == true ? inr(asNum(fee['amount'])) : 'Nil'),
                  _term('You get', inr(asNum(a['amount']))),
                ],
              ),
              if ('${a['remarks'] ?? ''}'.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Note: ${a['remarks']}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ],
          ),
        ),
        if (fee['required'] == true) ...[
          const SizedBox(height: 12),
          if (feeStatus == 'rejected' && '${fee['remarks'] ?? ''}'.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InfoBanner(text: 'Payment not verified: ${fee['remarks']}', icon: Icons.error_outline_rounded, color: AppColors.danger),
            ),
          if (needsPay)
            PrimaryButton(
              label: feeStatus == 'rejected' ? 'Pay processing fee again' : 'Pay ${inr(asNum(fee['amount']))} processing fee',
              icon: Icons.qr_code_2_rounded,
              onPressed: () async {
                final paid = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => FeePaymentScreen(loan: loan)));
                if (paid == true) onPaid?.call();
              },
            )
          else if (feeStatus == 'submitted')
            const InfoBanner(text: 'We received your payment details. Our team will verify it and disburse your loan shortly.', icon: Icons.hourglass_top_rounded)
          else
            const InfoBanner(
              text: 'Processing fee received. Your loan is being disbursed to your bank account.',
              icon: Icons.check_circle_outline_rounded,
              color: AppColors.accentDark,
            ),
        ],
      ],
    );
  }

  Widget _term(String k, String v) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(v, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

/// Small amber/green pill with the customer-facing status text.
class StatusLabel extends StatelessWidget {
  final String text;
  const StatusLabel({super.key, required this.text});
  @override
  Widget build(BuildContext context) {
    final good = text == 'Active' || text.startsWith('Disbursal');
    return Container(
      constraints: const BoxConstraints(maxWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: good ? AppColors.accentSoft : const Color(0xFFFFF7E6), borderRadius: BorderRadius.circular(20)),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: good ? AppColors.accentDark : const Color(0xFFB45309)),
      ),
    );
  }
}
