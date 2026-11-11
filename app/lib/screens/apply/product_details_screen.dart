import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../widgets/common.dart';
import 'flow.dart';

/// Category specific form (business / property / gold / vehicle / course details).
/// Fields come from the admin-configurable product definition, so the form is fully dynamic.
class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({super.key});
  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> ctrls = {};
  final Map<String, String?> selects = {};
  Map<String, String?> serverErrors = {};
  bool busy = false;

  late final AppState s = context.read<AppState>();
  late final Map<String, dynamic> product = s.product('${s.loan?['product']}') ?? {};
  late final List<Map<String, dynamic>> fields = List<Map<String, dynamic>>.from(product['fields'] ?? const []);

  @override
  void initState() {
    super.initState();
    final saved = Map<String, dynamic>.from(s.loan?['productDetails'] ?? {});
    for (final f in fields) {
      final k = '${f['key']}';
      if (f['type'] == 'select') {
        selects[k] = saved[k]?.toString();
      } else {
        ctrls[k] = TextEditingController(text: saved[k]?.toString() ?? '');
      }
    }
  }

  @override
  void dispose() {
    for (final c in ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => serverErrors = {});
    if (!_form.currentState!.validate()) return;
    final body = <String, dynamic>{};
    for (final f in fields) {
      final k = '${f['key']}';
      if (f['type'] == 'select') {
        if (selects[k] != null) body[k] = selects[k];
      } else {
        final v = ctrls[k]!.text.trim();
        if (v.isNotEmpty) body[k] = f['type'] == 'number' ? num.tryParse(v.replaceAll(',', '')) : v;
      }
    }
    setState(() => busy = true);
    try {
      final r = await Api.instance.put('/loans/current/product', body);
      if (mounted) ApplyFlow.next(context, Map<String, dynamic>.from(r['data']['loan']), 'product');
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.details != null) {
        setState(() => serverErrors = e.details!.map((k, v) => MapEntry(k, '$v')));
        _form.currentState!.validate();
      }
      showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _field(Map<String, dynamic> f) {
    final k = '${f['key']}';
    final label = '${f['label']}';
    final required = f['required'] == true;
    final type = '${f['type']}';
    if (type == 'select') {
      return PickerField(
        label: label,
        options: List<String>.from(f['options'] ?? const []),
        value: selects[k],
        required: required,
        onChanged: (v) => selects[k] = v,
      );
    }
    final isNum = type == 'number' || type == 'pincode';
    return AppField(
      controller: ctrls[k],
      label: label,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      maxLength: type == 'pincode' ? 6 : null,
      caps: isNum ? TextCapitalization.none : (f['pattern'] != null ? TextCapitalization.characters : TextCapitalization.words),
      formatters: isNum ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(type == 'pincode' ? 6 : 12)] : null,
      prefix: label.contains('₹') ? const Padding(padding: EdgeInsets.all(14), child: Text('₹', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))) : null,
      validator: (v) {
        if (serverErrors[k] != null) return serverErrors[k];
        final t = (v ?? '').trim();
        if (t.isEmpty) return required ? '${label.replaceAll(RegExp(r'\s*\(.*\)$'), '')} is required' : null;
        if (type == 'pincode' && !RegExp(r'^[1-9]\d{5}$').hasMatch(t)) return 'Enter a valid 6 digit PIN code';
        if (f['pattern'] != null && !RegExp('${f['pattern']}').hasMatch(t.toUpperCase())) return '${f['patternMsg'] ?? 'Invalid $label'}';
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = '${product['detailsTitle'] ?? ''}'.isEmpty ? 'Loan details' : '${product['detailsTitle']}';
    return Form(
      key: _form,
      child: StepScaffold(
        title: title,
        subtitle: 'A few details about your ${product['name'] ?? 'loan'} requirement',
        stepKey: 'product',
        bottom: PrimaryButton(label: 'Continue', icon: Icons.arrow_forward_rounded, loading: busy, onPressed: _submit),
        body: Column(children: [for (final f in fields) _field(f)]),
      ),
    );
  }
}
