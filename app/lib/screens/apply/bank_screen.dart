import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'flow.dart';

/// Manual bank details – the loan is disbursed to this account and EMIs are paid from it.
class BankScreen extends StatefulWidget {
  const BankScreen({super.key});
  @override
  State<BankScreen> createState() => _BankScreenState();
}

class _BankScreenState extends State<BankScreen> {
  final _form = GlobalKey<FormState>();
  final holder = TextEditingController();
  final account = TextEditingController();
  final confirm = TextEditingController();
  final ifsc = TextEditingController();
  final bankName = TextEditingController();
  final branch = TextEditingController();
  String accountType = 'savings';
  bool autoDebit = true, busy = false, hideAccount = true;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    final b = Map<String, dynamic>.from(s.loan?['bank'] ?? {});
    final basic = Map<String, dynamic>.from(s.loan?['basic'] ?? {});
    holder.text = b['accountHolderName'] ?? '${basic['firstName'] ?? ''} ${basic['lastName'] ?? ''}'.trim();
    account.text = b['accountNumber'] ?? '';
    confirm.text = b['accountNumber'] ?? '';
    ifsc.text = b['ifsc'] ?? '';
    bankName.text = b['bankName'] ?? '';
    branch.text = b['branch'] ?? '';
    accountType = b['accountType'] ?? 'savings';
    autoDebit = b['autoDebitConsent'] ?? true;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final r = await Api.instance.upload(
        '/loans/current/bank',
        fields: {
          'accountHolderName': holder.text.trim(),
          'accountNumber': account.text.trim(),
          'confirmAccountNumber': confirm.text.trim(),
          'ifsc': ifsc.text.trim().toUpperCase(),
          'bankName': bankName.text.trim(),
          'branch': branch.text.trim(),
          'accountType': accountType,
          'autoDebitConsent': autoDebit,
        },
      );
      if (mounted) ApplyFlow.next(context, Map<String, dynamic>.from(r['data']['loan']), 'bank');
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: StepScaffold(
        title: 'Add bank account',
        subtitle: 'Loan amount will be credited to this account',
        stepKey: 'bank',
        bottom: PrimaryButton(label: 'Save & continue', loading: busy, onPressed: _submit),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppField(
              controller: holder,
              label: 'Account holder name',
              helper: 'As per bank records',
              caps: TextCapitalization.words,
              validator: (v) => Validators.required(v, 'Account holder name'),
            ),
            AppField(
              controller: account,
              label: 'Account number',
              obscure: hideAccount,
              keyboardType: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(18)],
              suffix: IconButton(
                icon: Icon(hideAccount ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => hideAccount = !hideAccount),
              ),
              validator: Validators.pattern(Validators.account, 'Account number must be 9 to 18 digits'),
            ),
            AppField(
              controller: confirm,
              label: 'Re-enter account number',
              keyboardType: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(18)],
              validator: (v) => v != account.text ? 'Account numbers do not match' : null,
            ),
            AppField(
              controller: ifsc,
              label: 'IFSC code',
              helper: '11 characters, e.g. SBIN0001234 (printed on cheque book)',
              maxLength: 11,
              caps: TextCapitalization.characters,
              formatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')), UpperCaseFormatter()],
              validator: Validators.pattern(Validators.ifsc, 'Enter a valid IFSC code'),
            ),
            AppField(controller: bankName, label: 'Bank name', caps: TextCapitalization.words, validator: (v) => Validators.required(v, 'Bank name')),
            AppField(controller: branch, label: 'Branch (optional)', caps: TextCapitalization.words),
            const Text('Account type', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ChoiceTile(
                    label: 'Savings',
                    icon: Icons.savings_outlined,
                    selected: accountType == 'savings',
                    onTap: () => setState(() => accountType = 'savings'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceTile(
                    label: 'Current',
                    icon: Icons.business_center_outlined,
                    selected: accountType == 'current',
                    onTap: () => setState(() => accountType = 'current'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ConsentTile(
              value: autoDebit,
              onChanged: (v) => setState(() => autoDebit = v),
              text: const Text('I agree to set up EMI auto-debit (NACH/e-mandate) on this account once the loan is approved.'),
            ),
            const SizedBox(height: 8),
            const InfoBanner(
              text: 'Make sure the account belongs to you. Loans are never disbursed to third-party accounts.',
              icon: Icons.verified_user_outlined,
              color: AppColors.accentDark,
            ),
          ],
        ),
      ),
    );
  }
}
