import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Processing fee payment after approval: scan UPI QR, then submit UTR + screenshot.
class FeePaymentScreen extends StatefulWidget {
  final Map<String, dynamic> loan;
  const FeePaymentScreen({super.key, required this.loan});
  @override
  State<FeePaymentScreen> createState() => _FeePaymentScreenState();
}

class _FeePaymentScreenState extends State<FeePaymentScreen> {
  final _form = GlobalKey<FormState>();
  final utr = TextEditingController();
  String? proof;
  bool busy = false;

  num get amount => asNum(widget.loan['feePayment']?['amount']) ?? 0;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (proof == null) return showSnack(context, 'Please upload the payment screenshot', error: true);
    setState(() => busy = true);
    try {
      final r = await Api.instance.upload(
        '/loans/${widget.loan['_id']}/fee-payment',
        method: 'POST',
        fields: {'utr': utr.text.trim(), 'mode': 'upi'},
        files: {'proof': proof!},
      );
      if (!mounted) return;
      context.read<AppState>().setLoan(r['data']['loan']);
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 52),
          title: const Text('Payment submitted'),
          content: const Text('We will verify your payment and disburse the loan to your bank account. You will get a notification once it is done.'),
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
    final s = context.watch<AppState>();
    final fp = Map<String, dynamic>.from(s.settings['feePayment'] ?? {});
    final upiId = '${fp['upiId'] ?? ''}';
    final payee = '${fp['payeeName'] ?? 'Credit Ventures'}';
    final qrImage = fp['qrImageUrl'] as String?;
    final demo = fp['demo'] == true || (upiId.isEmpty && qrImage == null);
    final loanNo = '${widget.loan['loanNumber'] ?? ''}';
    final upiUri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': upiId.isEmpty ? 'demo.creditventures@upi' : upiId,
        'pn': payee,
        'am': amount.toStringAsFixed(2),
        'cu': 'INR',
        'tn': 'Processing fee $loanNo',
      },
    ).toString();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Pay processing fee')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(22)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Processing fee', style: TextStyle(color: AppColors.onHeroMuted)),
                        Text(
                          inr(amount),
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                        ),
                        Text('${widget.loan['productName'] ?? 'Loan'} · $loanNo', style: const TextStyle(color: AppColors.onHeroSoft, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  const Icon(Icons.qr_code_2_rounded, color: Colors.white54, size: 54),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text('Step 1: Scan & pay', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            SectionCard(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE6E0EF)),
                        ),
                        child: qrImage != null
                            ? CachedNetworkImage(imageUrl: qrImage, width: 210, height: 210, fit: BoxFit.contain)
                            : QrImageView(
                                data: upiUri,
                                size: 210,
                                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.primaryDark),
                                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.primaryDark),
                              ),
                      ),
                      if (demo)
                        Transform.rotate(
                          angle: -0.35,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(8)),
                            child: const Text(
                              'DEMO QR',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(payee, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  if (upiId.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: upiId));
                        showSnack(context, 'UPI ID copied');
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            upiId,
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.copy_rounded, size: 15, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _UpiChip('GPay'),
                      SizedBox(width: 6),
                      _UpiChip('PhonePe'),
                      SizedBox(width: 6),
                      _UpiChip('Paytm'),
                      SizedBox(width: 6),
                      _UpiChip('BHIM'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${fp['instructions'] ?? ''}'.isEmpty ? 'Scan with any UPI app and pay exactly ${inr(amount)}.' : '${fp['instructions']}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.45),
                  ),
                  if (demo) ...[
                    const SizedBox(height: 10),
                    const InfoBanner(
                      text: 'Demo mode: this QR is only for testing. Do not make a real payment until the company adds its UPI details.',
                      icon: Icons.info_outline_rounded,
                      color: AppColors.warning,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text('Step 2: Share payment details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            AppField(
              controller: utr,
              label: 'UTR / UPI reference number',
              helper: '12 digit number shown in your UPI app after payment',
              caps: TextCapitalization.characters,
              formatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')), UpperCaseFormatter()],
              validator: Validators.pattern(RegExp(r'^[A-Za-z0-9]{6,30}$'), 'Enter a valid UTR / reference number'),
            ),
            DocUploadTile(
              label: 'Payment screenshot',
              hint: 'Screenshot showing amount, date and UTR',
              icon: Icons.receipt_long_rounded,
              localPath: proof,
              onPicked: (p) => setState(() => proof = p),
            ),
            const SizedBox(height: 6),
            const InfoBanner(
              text: 'Pay only to the account shown here. Our staff will never ask you to pay to a personal account.',
              icon: Icons.shield_outlined,
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAction(
        child: PrimaryButton(label: 'Submit payment', loading: busy, onPressed: _submit),
      ),
    );
  }
}

class _UpiChip extends StatelessWidget {
  final String name;
  const _UpiChip(this.name);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(20)),
    child: Text(
      name,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
    ),
  );
}
