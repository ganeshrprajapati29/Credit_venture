import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../widgets/common.dart';
import 'flow.dart';

class PersonalScreen extends StatefulWidget {
  const PersonalScreen({super.key});
  @override
  State<PersonalScreen> createState() => _PersonalScreenState();
}

class _PersonalScreenState extends State<PersonalScreen> {
  final _form = GlobalKey<FormState>();
  final father = TextEditingController();
  final mother = TextEditingController();
  String? residence, purpose, language;
  bool pep = true, busy = false;

  @override
  void initState() {
    super.initState();
    final p = Map<String, dynamic>.from(context.read<AppState>().loan?['personal'] ?? {});
    father.text = p['fatherName'] ?? '';
    mother.text = p['motherName'] ?? '';
    residence = p['residenceType'];
    purpose = p['purpose'];
    language = p['language'] ?? 'English';
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (residence == null) return showSnack(context, 'Please tell us where you live', error: true);
    if (!pep) return showSnack(context, 'Please confirm the PEP declaration', error: true);
    setState(() => busy = true);
    try {
      final r = await Api.instance.put('/loans/current/personal', {
        'fatherName': father.text.trim(),
        'motherName': mother.text.trim(),
        'residenceType': residence,
        'purpose': purpose,
        'language': language,
        'pepDeclaration': pep,
      });
      if (mounted) ApplyFlow.next(context, Map<String, dynamic>.from(r['data']['loan']), 'personal');
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
    return Form(
      key: _form,
      child: StepScaffold(
        title: 'A little more about you',
        subtitle: 'Provide a few basic details',
        step: 3,
        totalSteps: ApplyFlow.totalSteps,
        bottom: PrimaryButton(label: 'Continue', icon: Icons.arrow_forward_rounded, loading: busy, onPressed: _submit),
        body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AppField(controller: father, label: "Father's name", caps: TextCapitalization.words, validator: nameRule),
          AppField(controller: mother, label: "Mother's name", caps: TextCapitalization.words, validator: nameRule),
          const Text('Where do you live?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 10),
          ChoiceTile(label: 'Owned house', icon: Icons.home_outlined, selected: residence == 'owned', onTap: () => setState(() => residence = 'owned')),
          ChoiceTile(label: 'Rented house', icon: Icons.house_siding_rounded, selected: residence == 'rented', onTap: () => setState(() => residence = 'rented')),
          ChoiceTile(label: 'Living with family', icon: Icons.family_restroom_rounded, selected: residence == 'family', onTap: () => setState(() => residence = 'family')),
          ChoiceTile(label: 'PG / Hostel', icon: Icons.apartment_rounded, selected: residence == 'pg', onTap: () => setState(() => residence = 'pg')),
          const SizedBox(height: 10),
          PickerField(label: 'Purpose of loan', options: s.options('loanPurpose'), value: purpose, onChanged: (v) => purpose = v),
          PickerField(label: 'Language preference', options: s.options('language'), value: language, onChanged: (v) => language = v),
          ConsentTile(
            value: pep,
            onChanged: (v) => setState(() => pep = v),
            text: const Text('I confirm that I am not a politically exposed person (PEP) or a close relative of one.'),
          ),
        ]),
      ),
    );
  }
}
