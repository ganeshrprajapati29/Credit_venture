import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../widgets/common.dart';
import 'flow.dart';

const indianStates = [
  'Andaman and Nicobar Islands', 'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chandigarh', 'Chhattisgarh',
  'Dadra and Nagar Haveli and Daman and Diu', 'Delhi', 'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jammu and Kashmir',
  'Jharkhand', 'Karnataka', 'Kerala', 'Ladakh', 'Lakshadweep', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya',
  'Mizoram', 'Nagaland', 'Odisha', 'Puducherry', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura',
  'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
];

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});
  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final _form = GlobalKey<FormState>();
  final line1 = TextEditingController();
  final line2 = TextEditingController();
  final landmark = TextEditingController();
  final city = TextEditingController();
  final pin = TextEditingController();
  final years = TextEditingController();
  final permanent = TextEditingController();
  String? state;
  bool same = true, busy = false;

  @override
  void initState() {
    super.initState();
    final a = Map<String, dynamic>.from(context.read<AppState>().loan?['address'] ?? {});
    line1.text = a['line1'] ?? '';
    line2.text = a['line2'] ?? '';
    landmark.text = a['landmark'] ?? '';
    city.text = a['city'] ?? '';
    pin.text = a['pincode'] ?? '';
    years.text = a['yearsAtAddress'] != null ? '${a['yearsAtAddress']}' : '';
    permanent.text = a['permanentAddress'] ?? '';
    state = a['state'];
    same = a['sameAsPermanent'] != false;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final r = await Api.instance.put('/loans/current/address', {
        'line1': line1.text.trim(),
        'line2': line2.text.trim(),
        'landmark': landmark.text.trim(),
        'city': city.text.trim(),
        'state': state,
        'pincode': pin.text.trim(),
        if (years.text.isNotEmpty) 'yearsAtAddress': int.tryParse(years.text),
        'sameAsPermanent': same,
        if (!same) 'permanentAddress': permanent.text.trim(),
      });
      if (mounted) ApplyFlow.next(context, Map<String, dynamic>.from(r['data']['loan']), 'address');
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
        title: 'Current address',
        subtitle: 'Where do you live right now?',
        stepKey: 'address',
        bottom: PrimaryButton(label: 'Continue', icon: Icons.arrow_forward_rounded, loading: busy, onPressed: _submit),
        body: Column(children: [
          AppField(controller: line1, label: 'House / Flat no., Building, Street', caps: TextCapitalization.words, validator: (v) => Validators.required(v, 'Address')),
          AppField(controller: line2, label: 'Area / Locality (optional)', caps: TextCapitalization.words),
          AppField(controller: landmark, label: 'Landmark (optional)', caps: TextCapitalization.words),
          AppField(controller: city, label: 'City', caps: TextCapitalization.words, validator: (v) => Validators.required(v, 'City')),
          PickerField(label: 'State', options: indianStates, value: state, onChanged: (v) => state = v),
          AppField(
            controller: pin,
            label: 'PIN code',
            keyboardType: TextInputType.number,
            maxLength: 6,
            formatters: [FilteringTextInputFormatter.digitsOnly],
            validator: Validators.pattern(Validators.pincode, 'Enter a valid 6 digit PIN code'),
          ),
          AppField(controller: years, label: 'Years at this address (optional)', keyboardType: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)]),
          ConsentTile(value: same, onChanged: (v) => setState(() => same = v), text: const Text('My permanent address is the same as current address')),
          if (!same) ...[
            const SizedBox(height: 8),
            AppField(controller: permanent, label: 'Permanent address with PIN code', maxLines: 3, caps: TextCapitalization.words, validator: (v) => Validators.required(v, 'Permanent address')),
          ],
        ]),
      ),
    );
  }
}
