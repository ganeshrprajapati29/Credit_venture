import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'flow.dart';

/// Manual KYC: user types Aadhaar & PAN and uploads document photos + selfie.
class KycScreen extends StatefulWidget {
  const KycScreen({super.key});
  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _form = GlobalKey<FormState>();
  final aadhaar = TextEditingController();
  final pan = TextEditingController();
  final Map<String, String> picked = {};
  Map<String, dynamic> existing = {};
  bool busy = false;
  double progress = 0;

  @override
  void initState() {
    super.initState();
    existing = Map<String, dynamic>.from(context.read<AppState>().loan?['kyc'] ?? {});
    pan.text = existing['panNumber'] ?? '';
  }

  String? _remote(String f) => existing[f] is Map ? existing[f]['filename'] : null;
  bool get hasAadhaar => '${existing['aadhaarNumber'] ?? ''}'.isNotEmpty;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    const required = {'aadhaarFront': 'Aadhaar front', 'aadhaarBack': 'Aadhaar back', 'panCard': 'PAN card', 'selfie': 'Selfie'};
    final missing = required.entries.where((e) => picked[e.key] == null && _remote(e.key) == null).map((e) => e.value).toList();
    if (missing.isNotEmpty) return showSnack(context, 'Please upload: ${missing.join(', ')}', error: true);
    setState(() {
      busy = true;
      progress = 0;
    });
    try {
      final r = await Api.instance.upload(
        '/loans/current/kyc',
        fields: {
          if (aadhaar.text.isNotEmpty) 'aadhaarNumber': aadhaar.text.replaceAll(' ', ''),
          'panNumber': pan.text.trim().toUpperCase(),
        },
        files: picked,
        onProgress: (p) => setState(() => progress = p),
      );
      if (mounted) ApplyFlow.next(context, Map<String, dynamic>.from(r['data']['loan']), 'kyc');
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _tile(String key, String label, String hint, IconData icon, {bool camera = false, bool front = false, bool optional = false}) => DocUploadTile(
        label: optional ? '$label (optional)' : label,
        hint: hint,
        icon: icon,
        localPath: picked[key],
        remoteName: _remote(key),
        cameraOnly: camera,
        frontCamera: front,
        onPicked: (p) => setState(() => picked[key] = p),
      );

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: StepScaffold(
        title: 'Submit your KYC',
        subtitle: 'Enter your Aadhaar & PAN details and upload clear photos',
        stepKey: 'kyc',
        bottom: Column(mainAxisSize: MainAxisSize.min, children: [
          if (busy) ...[
            ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: progress, minHeight: 5)),
            const SizedBox(height: 8),
            Text('Uploading securely… ${(progress * 100).round()}%', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 8),
          ],
          PrimaryButton(label: 'Upload & continue', loading: busy, onPressed: _submit),
        ]),
        body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AppField(
            controller: aadhaar,
            label: hasAadhaar ? 'Aadhaar number (saved: ${existing['aadhaarNumber']})' : 'Aadhaar number',
            helper: hasAadhaar ? 'Leave empty to keep the saved number' : '12 digit number on your Aadhaar card',
            keyboardType: TextInputType.number,
            maxLength: 14,
            formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12), _AadhaarFormatter()],
            validator: (v) {
              final n = (v ?? '').replaceAll(' ', '');
              if (n.isEmpty) return hasAadhaar ? null : 'Aadhaar number is required';
              return Validators.aadhaar(n) ? null : 'Enter a valid Aadhaar number';
            },
          ),
          AppField(
            controller: pan,
            label: 'PAN number',
            helper: 'e.g. ABCDE1234F',
            maxLength: 10,
            caps: TextCapitalization.characters,
            formatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')), UpperCaseFormatter()],
            validator: Validators.pattern(Validators.pan, 'Enter a valid PAN'),
          ),
          const SizedBox(height: 4),
          const Text('Aadhaar card', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 10),
          _tile('aadhaarFront', 'Aadhaar – front side', 'Photo with your name & photo visible', Icons.badge_outlined),
          _tile('aadhaarBack', 'Aadhaar – back side', 'Photo with your address visible', Icons.flip_rounded),
          const SizedBox(height: 8),
          const Text('PAN & selfie', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 10),
          _tile('panCard', 'PAN card', 'Original PAN card, not a photocopy', Icons.credit_card_rounded),
          _tile('selfie', 'Live selfie', 'Face the camera in good light, no glasses', Icons.face_retouching_natural_rounded, camera: true, front: true),
          _tile('salarySlip', 'Latest salary slip', 'Helps faster approval', Icons.receipt_long_rounded, optional: true),
          const SizedBox(height: 8),
          const InfoBanner(text: 'Your documents are encrypted in transit and stored privately. They are used only to verify your identity for this loan.'),
          const SizedBox(height: 12),
          const _Tips(),
        ]),
      ),
    );
  }
}

class _Tips extends StatelessWidget {
  const _Tips();
  @override
  Widget build(BuildContext context) {
    const tips = ['Keep the full card inside the frame', 'Avoid glare and shadows', 'Make sure text is readable', 'Upload original documents only'];
    return SectionCard(
      color: const Color(0xFFFFFBEB),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.tips_and_updates_rounded, color: AppColors.warning, size: 20),
          SizedBox(width: 8),
          Text('Photo tips', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        for (final t in tips)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              const Icon(Icons.check_rounded, size: 16, color: AppColors.accentDark),
              const SizedBox(width: 8),
              Text(t, style: const TextStyle(fontSize: 13)),
            ]),
          ),
      ]),
    );
  }
}

class _AadhaarFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(' ', '');
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) b.write(' ');
      b.write(digits[i]);
    }
    final s = b.toString();
    return TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}
