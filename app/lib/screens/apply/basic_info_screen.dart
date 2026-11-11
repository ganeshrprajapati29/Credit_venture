import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../legal_screen.dart';
import 'flow.dart';
import 'not_eligible_screen.dart';

class BasicInfoScreen extends StatefulWidget {
  final String? productKey;
  const BasicInfoScreen({super.key, this.productKey});
  @override
  State<BasicInfoScreen> createState() => _BasicInfoScreenState();
}

class _BasicInfoScreenState extends State<BasicInfoScreen> {
  final _form = GlobalKey<FormState>();
  final first = TextEditingController();
  final last = TextEditingController();
  final email = TextEditingController();
  final dobCtrl = TextEditingController();
  final amount = TextEditingController();
  final income = TextEditingController();
  DateTime? dob;
  String? gender, education, marital, employment, salaryMode;
  bool cBureau = false, cCkyc = false, cIncome = false, cDisability = false;
  bool busy = false;
  late String productKey;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    productKey = widget.productKey ?? '${s.loan?['product'] ?? s.product(null)?['key'] ?? 'personal'}';
    final b = Map<String, dynamic>.from(s.loan?['basic'] ?? {});
    first.text = b['firstName'] ?? '';
    last.text = b['lastName'] ?? '';
    email.text = b['email'] ?? s.user?['email'] ?? '';
    dob = DateTime.tryParse('${b['dob'] ?? ''}');
    if (dob != null) dobCtrl.text = fmtDate(dob);
    gender = b['gender'];
    education = b['education'];
    marital = b['maritalStatus'];
    employment = b['employmentType'];
    salaryMode = b['salaryMode'];
    if (b['preferredAmount'] != null) amount.text = '${b['preferredAmount']}';
    if (b['monthlyIncome'] != null) income.text = '${b['monthlyIncome']}';
    final c = Map<String, dynamic>.from(b['consents'] ?? {});
    cBureau = c['creditBureau'] == true;
    cCkyc = c['ckyc'] == true;
    cIncome = c['incomeDeclaration'] == true;
    cDisability = c['disabilityDeclaration'] == true;
  }

  Future<void> _pickDob() async {
    final s = context.read<AppState>();
    final now = DateTime.now();
    final maxAge = (s.loanConfig['maxAge'] ?? 60) as num;
    final minAge = (s.loanConfig['minAge'] ?? 21) as num;
    final picked = await showDatePicker(
      context: context,
      initialDate: dob ?? DateTime(now.year - 28, 1, 1),
      firstDate: DateTime(now.year - maxAge.toInt() - 1),
      lastDate: DateTime(now.year - minAge.toInt(), now.month, now.day),
      helpText: 'Date of birth (as per PAN)',
    );
    if (picked != null) {
      setState(() {
        dob = picked;
        dobCtrl.text = fmtDate(picked);
      });
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (gender == null) return showSnack(context, 'Please select your gender', error: true);
    if (!cBureau || !cCkyc) return showSnack(context, 'Please accept the credit bureau and CKYC consent', error: true);
    setState(() => busy = true);
    try {
      final r = await Api.instance.put('/loans/current/basic', {
        'product': productKey,
        'firstName': first.text.trim(),
        'lastName': last.text.trim(),
        'dob': dob!.toIso8601String().substring(0, 10),
        'gender': gender,
        'email': email.text.trim(),
        'education': education,
        'maritalStatus': marital,
        'employmentType': employment,
        'salaryMode': salaryMode,
        'monthlyIncome': int.tryParse(income.text.replaceAll(',', '')),
        'preferredAmount': int.tryParse(amount.text.replaceAll(',', '')),
        'consents': {'creditBureau': cBureau, 'ckyc': cCkyc, 'incomeDeclaration': cIncome, 'disabilityDeclaration': cDisability},
      });
      if (!mounted) return;
      final data = r['data'];
      if (data['eligible'] != true) {
        context.read<AppState>().setLoan(data['loan']);
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => NotEligibleScreen(reasons: List<String>.from(data['reasons'] ?? []))));
        return;
      }
      ApplyFlow.next(context, Map<String, dynamic>.from(data['loan']), 'basic');
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final nameRule = Validators.pattern(Validators.name, 'Enter a valid name');
    final product = s.product(productKey) ?? {};
    return Form(
      key: _form,
      child: StepScaffold(
        title: 'Tell us about yourself',
        subtitle: 'Provide a few basic details to check your offer',
        stepKey: 'basic',
        productKey: productKey,
        bottom: PrimaryButton(label: 'Get my offer', loading: busy, onPressed: _submit),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product['name'] != null) ...[ProductChip(product: product), const SizedBox(height: 18)],
            AppField(controller: first, label: 'First name', helper: 'As per PAN card', caps: TextCapitalization.words, validator: nameRule),
            AppField(controller: last, label: 'Last name', helper: 'As per PAN card', caps: TextCapitalization.words, validator: nameRule),
            AppField(
              controller: dobCtrl,
              label: 'Date of birth',
              readOnly: true,
              onTap: _pickDob,
              suffix: const Icon(Icons.calendar_today_rounded, size: 20),
              validator: (_) => dob == null ? 'Please select your date of birth' : null,
            ),
            const Text(
              'Gender',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final g in const [
                  ('male', 'Male', Icons.male_rounded),
                  ('female', 'Female', Icons.female_rounded),
                  ('other', 'Other', Icons.transgender_rounded),
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: gender == g.$1,
                        onSelected: (_) => setState(() => gender = g.$1),
                        avatar: Icon(g.$3, size: 18, color: gender == g.$1 ? Colors.white : AppColors.textMuted),
                        label: SizedBox(width: double.infinity, child: Text(g.$2)),
                        showCheckmark: false,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(fontWeight: FontWeight.w600, color: gender == g.$1 ? Colors.white : AppColors.text),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: gender == g.$1 ? AppColors.primary : AppColors.border),
                        ),
                        backgroundColor: AppColors.bg,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            AppField(
              controller: email,
              label: 'Email address',
              keyboardType: TextInputType.emailAddress,
              validator: Validators.pattern(Validators.email, 'Enter a valid email'),
            ),
            PickerField(label: 'Education', options: s.options('education'), value: education, onChanged: (v) => education = v),
            PickerField(label: 'Marital status', options: s.options('maritalStatus'), value: marital, onChanged: (v) => marital = v),
            AppField(
              controller: amount,
              label: 'Preferred loan amount (optional)',
              keyboardType: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
              prefix: const Padding(
                padding: EdgeInsets.all(14),
                child: Text('₹', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ),
            PickerField(label: 'Your employment type', options: s.options('employmentType'), value: employment, onChanged: (v) => employment = v),
            AppField(
              controller: income,
              label: '${product['incomeLabel'] ?? 'Monthly income (in-hand)'}',
              keyboardType: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
              prefix: const Padding(
                padding: EdgeInsets.all(14),
                child: Text('₹', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter your monthly income' : null,
            ),
            PickerField(label: 'How do you get your salary?', options: s.options('salaryMode'), value: salaryMode, onChanged: (v) => salaryMode = v),
            const SizedBox(height: 4),
            ConsentTile(
              value: cBureau,
              onChanged: (v) => setState(() => cBureau = v),
              text: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'I agree to the T&Cs of CIBIL, Equifax, Experian and CRIF (credit bureaus) and consent to Credit Ventures and its lending partner fetching my credit information to evaluate this application. ',
                    ),
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: () => LegalScreen.open(context, terms: true),
                        child: const Text(
                          'Read terms',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, fontSize: 13.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ConsentTile(
              value: cCkyc,
              onChanged: (v) => setState(() => cCkyc = v),
              text: const Text(
                "I authorise Credit Ventures' lending partner to download my KYC records from the CKYC Registry and update them if I provide changes in this application.",
              ),
            ),
            ConsentTile(
              value: cIncome,
              onChanged: (v) => setState(() => cIncome = v),
              text: const Text('I confirm that my household income is above ₹3,00,000 per annum.'),
            ),
            ConsentTile(
              value: cDisability,
              onChanged: (v) => setState(() => cDisability = v),
              text: const Text('I declare that I do not have any disability that requires special assistance for this application.'),
            ),
          ],
        ),
      ),
    );
  }
}
