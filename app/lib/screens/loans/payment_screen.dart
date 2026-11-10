import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Manual EMI payment: user pays via UPI / bank transfer and uploads proof + UTR.
class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> loan;
  final Map<String, dynamic> installment;
  const PaymentScreen({super.key, required this.loan, required this.installment});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _form = GlobalKey<FormState>();
  late final amount = TextEditingController(text: '${widget.installment['amount'] ?? ''}');
  final utr = TextEditingController();
  String mode = 'UPI';
  String? proof;
  bool busy = false;

  void _copy(String label, String v) {
    if (v.isEmpty) return;
    Clipboard.setData(ClipboardData(text: v));
    showSnack(context, '$label copied');
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (proof == null) return showSnack(context, 'Please upload the payment screenshot', error: true);
    setState(() => busy = true);
    try {
      await Api.instance.upload(
        '/loans/${widget.loan['_id']}/payments',
        method: 'POST',
        fields: {'amount': amount.text, 'utr': utr.text.trim(), 'mode': mode.toLowerCase(), 'installmentNo': widget.installment['installmentNo']},
        files: {'proof': proof!},
      );
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 48),
          title: const Text('Payment submitted'),
          content: const Text('We will verify your payment with the bank and update your EMI status, usually within 24 hours.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<AppState>().repayment;
    final rows = [
      ('UPI ID', '${rp['upiId'] ?? ''}'),
      ('Account name', '${rp['accountName'] ?? ''}'),
      ('Account number', '${rp['accountNumber'] ?? ''}'),
      ('IFSC', '${rp['ifsc'] ?? ''}'),
      ('Bank', '${rp['bankName'] ?? ''}'),
    ].where((r) => r.$2.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(title: Text('Pay EMI ${widget.installment['installmentNo']}')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(22)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Amount due', style: TextStyle(color: Color(0xFFC3CBFD))),
              Text(inr(widget.installment['amount']), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
              Text('Due on ${fmtDate(widget.installment['dueDate'])} · Loan ${widget.loan['loanNumber']}', style: const TextStyle(color: Color(0xFFDFE4FF))),
            ]),
          ),
          const SizedBox(height: 18),
          const Text('Step 1: Pay to this account', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 10),
          SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if ('${rp['instructions'] ?? ''}'.isNotEmpty) ...[
                Text('${rp['instructions']}', style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.45)),
                const SizedBox(height: 8),
              ],
              if (rows.isEmpty) const Text('Payment details will be shared by our support team.', style: TextStyle(color: AppColors.textMuted)),
              for (final r in rows)
                InkWell(
                  onTap: () => _copy(r.$1, r.$2),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Expanded(child: Text(r.$1, style: const TextStyle(color: AppColors.textMuted))),
                      Text(r.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      const Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
                    ]),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 18),
          const Text('Step 2: Share payment details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            for (final m in const ['UPI', 'IMPS', 'NEFT', 'Other'])
              ChoiceChip(
                label: Text(m),
                selected: mode == m,
                onSelected: (_) => setState(() => mode = m),
                selectedColor: AppColors.primarySoft,
                labelStyle: TextStyle(fontWeight: FontWeight.w700, color: mode == m ? AppColors.primary : AppColors.text),
              ),
          ]),
          const SizedBox(height: 14),
          AppField(
            controller: amount,
            label: 'Amount paid',
            keyboardType: TextInputType.number,
            formatters: [FilteringTextInputFormatter.digitsOnly],
            prefix: const Padding(padding: EdgeInsets.all(14), child: Text('₹', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter the amount paid' : null,
          ),
          AppField(
            controller: utr,
            label: 'UTR / Transaction ID',
            helper: '12 digit UPI reference or bank UTR number',
            caps: TextCapitalization.characters,
            formatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')), UpperCaseFormatter()],
            validator: Validators.pattern(RegExp(r'^[A-Za-z0-9]{6,30}$'), 'Enter a valid UTR / transaction ID'),
          ),
          DocUploadTile(
            label: 'Payment screenshot',
            hint: 'Screenshot showing amount, date and UTR',
            icon: Icons.receipt_long_rounded,
            localPath: proof,
            onPicked: (p) => setState(() => proof = p),
          ),
        ]),
      ),
      bottomNavigationBar: BottomAction(child: PrimaryButton(label: 'Submit payment', loading: busy, onPressed: _submit)),
    );
  }
}
