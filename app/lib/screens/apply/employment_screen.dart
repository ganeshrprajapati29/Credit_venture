import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../widgets/common.dart';
import 'flow.dart';

class EmploymentScreen extends StatefulWidget {
  const EmploymentScreen({super.key});
  @override
  State<EmploymentScreen> createState() => _EmploymentScreenState();
}

class _EmploymentScreenState extends State<EmploymentScreen> {
  final _form = GlobalKey<FormState>();
  final company = TextEditingController();
  final designation = TextEditingController();
  final officeEmail = TextEditingController();
  final address = TextEditingController();
  final pin = TextEditingController();
  final experience = TextEditingController();
  String? sector, industry, nature;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final e = Map<String, dynamic>.from(context.read<AppState>().loan?['employment'] ?? {});
    company.text = e['companyName'] ?? '';
    designation.text = e['designation'] ?? '';
    officeEmail.text = e['officeEmail'] ?? '';
    address.text = e['companyAddress'] ?? '';
    pin.text = e['companyPincode'] ?? '';
    experience.text = e['workExperienceMonths'] != null ? '${e['workExperienceMonths']}' : '';
    sector = e['sector'];
    industry = e['industryType'];
    nature = e['natureOfWork'];
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final r = await Api.instance.put('/loans/current/employment', {
        'companyName': company.text.trim(),
        'sector': sector,
        'industryType': industry,
        'natureOfWork': nature,
        'designation': designation.text.trim(),
        if (officeEmail.text.trim().isNotEmpty) 'officeEmail': officeEmail.text.trim(),
        'companyAddress': address.text.trim(),
        'companyPincode': pin.text.trim(),
        if (experience.text.isNotEmpty) 'workExperienceMonths': int.tryParse(experience.text),
      });
      if (mounted) ApplyFlow.next(context, Map<String, dynamic>.from(r['data']['loan']), 'employment');
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final selfEmployed = '${s.loan?['basic']?['employmentType'] ?? ''}'.toLowerCase().contains('self');
    return Form(
      key: _form,
      child: StepScaffold(
        title: selfEmployed ? 'About your business' : 'About your company',
        subtitle: selfEmployed ? 'Tell us about the business you run' : 'Enter information about the company you work for',
        step: 4,
        totalSteps: ApplyFlow.totalSteps,
        bottom: PrimaryButton(label: 'Continue', icon: Icons.arrow_forward_rounded, loading: busy, onPressed: _submit),
        body: Column(children: [
          AppField(controller: company, label: selfEmployed ? 'Business name' : 'Company name', caps: TextCapitalization.words, validator: (v) => Validators.required(v, 'Company name')),
          PickerField(label: 'Sector', options: s.options('sector'), value: sector, onChanged: (v) => sector = v),
          PickerField(label: 'Industry type', options: s.options('industryType'), value: industry, onChanged: (v) => industry = v),
          PickerField(label: 'Nature of work', options: s.options('natureOfWork'), value: nature, onChanged: (v) => nature = v),
          AppField(controller: designation, label: 'Designation (optional)', caps: TextCapitalization.words),
          AppField(controller: officeEmail, label: 'Official email (optional)', keyboardType: TextInputType.emailAddress, validator: Validators.pattern(Validators.email, 'Enter a valid email', optional: true)),
          AppField(controller: experience, label: 'Total work experience (months)', keyboardType: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)]),
          AppField(controller: address, label: selfEmployed ? 'Business address' : 'Company address', maxLines: 2, caps: TextCapitalization.sentences, validator: (v) => Validators.required(v, 'Address')),
          AppField(
            controller: pin,
            label: 'PIN code',
            helper: selfEmployed ? 'Business address' : 'Company address',
            keyboardType: TextInputType.number,
            maxLength: 6,
            formatters: [FilteringTextInputFormatter.digitsOnly],
            validator: Validators.pattern(Validators.pincode, 'Enter a valid 6 digit PIN code'),
          ),
        ]),
      ),
    );
  }
}
