import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/api.dart';
import '../theme.dart';

void showSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline_rounded : Icons.check_circle_rounded, color: error ? const Color(0xFFFDA4AF) : const Color(0xFF6EE7B7)),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
    ));
}

String errorText(Object e) => e is ApiException ? e.message : 'Something went wrong. Please try again.';

class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size = 56});
  @override
  Widget build(BuildContext context) => SvgPicture.asset('assets/images/logo.svg', width: size, height: size);
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final Color? color;
  const PrimaryButton({super.key, required this.label, this.onPressed, this.loading = false, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: color != null ? ElevatedButton.styleFrom(backgroundColor: color) : null,
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(label),
              if (icon != null) ...[const SizedBox(width: 8), Icon(icon, size: 20)],
            ]),
    );
  }
}

/// Bottom area with a primary action that stays above the keyboard.
class BottomAction extends StatelessWidget {
  final Widget child;
  const BottomAction({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, -4))],
      ),
      child: child,
    );
  }
}

class AppField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? helper;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;
  final String? Function(String?)? validator;
  final int? maxLength;
  final bool obscure;
  final Widget? prefix;
  final Widget? suffix;
  final TextCapitalization caps;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;

  const AppField({
    super.key,
    this.controller,
    required this.label,
    this.helper,
    this.hint,
    this.keyboardType,
    this.formatters,
    this.validator,
    this.maxLength,
    this.obscure = false,
    this.prefix,
    this.suffix,
    this.caps = TextCapitalization.none,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: formatters,
        validator: validator,
        maxLength: maxLength,
        obscureText: obscure,
        textCapitalization: caps,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          hintText: hint,
          counterText: '',
          prefixIcon: prefix,
          suffixIcon: suffix,
        ),
      ),
    );
  }
}

/// A form field that opens a searchable bottom-sheet list (like a dropdown).
class PickerField extends FormField<String> {
  PickerField({
    super.key,
    required String label,
    required List<String> options,
    String? value,
    required ValueChanged<String> onChanged,
    bool required = true,
    String? helper,
  }) : super(
          initialValue: value,
          validator: (v) => required && (v == null || v.isEmpty) ? 'Please select $label' : null,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          builder: (state) {
            final ctx = state.context;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  FocusScope.of(ctx).unfocus();
                  final picked = await showOptionSheet(ctx, title: label, options: options, selected: state.value);
                  if (picked != null) {
                    state.didChange(picked);
                    onChanged(picked);
                  }
                },
                child: InputDecorator(
                  isEmpty: state.value == null || state.value!.isEmpty,
                  decoration: InputDecoration(
                    labelText: label,
                    helperText: helper,
                    errorText: state.errorText,
                    suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                  child: Text(state.value ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            );
          },
        );
}

Future<String?> showOptionSheet(BuildContext context, {required String title, required List<String> options, String? selected}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => _OptionSheet(title: title, options: options, selected: selected),
  );
}

class _OptionSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  final String? selected;
  const _OptionSheet({required this.title, required this.options, this.selected});
  @override
  State<_OptionSheet> createState() => _OptionSheetState();
}

class _OptionSheetState extends State<_OptionSheet> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final items = widget.options.where((o) => o.toLowerCase().contains(q.toLowerCase())).toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: widget.options.length > 8 ? 0.75 : 0.5,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => Column(children: [
        const SizedBox(height: 10),
        Container(width: 44, height: 5, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(children: [
            Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
          ]),
        ),
        if (widget.options.length > 8)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: TextField(
              onChanged: (v) => setState(() => q = v),
              decoration: const InputDecoration(hintText: 'Search', prefixIcon: Icon(Icons.search_rounded), contentPadding: EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
        Expanded(
          child: ListView.separated(
            controller: scroll,
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(indent: 20, endIndent: 20),
            itemBuilder: (_, i) {
              final sel = items[i] == widget.selected;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                title: Text(items[i], style: TextStyle(fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? AppColors.primary : AppColors.text)),
                trailing: sel ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
                onTap: () => Navigator.pop(context, items[i]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

/// Checkbox + rich text row used for consents.
class ConsentTile extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget text;
  const ConsentTile({super.key, required this.value, required this.onChanged, required this.text});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 28, height: 28, child: Checkbox(value: value, onChanged: (v) => onChanged(v ?? false))),
          const SizedBox(width: 12),
          Expanded(child: DefaultTextStyle.merge(style: const TextStyle(fontSize: 13.5, height: 1.5, color: Color(0xFF334155)), child: text)),
        ]),
      ),
    );
  }
}

/// Large selectable row (radio style).
class ChoiceTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const ChoiceTile({super.key, required this.label, required this.icon, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.6 : 1),
          ),
          child: Row(children: [
            Icon(icon, color: selected ? AppColors.primary : AppColors.textMuted),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? AppColors.primary : const Color(0xFF94A3B8)),
          ]),
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  const SectionCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEDF0F7)),
          boxShadow: const [BoxShadow(color: Color(0x0A1E293B), blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: child,
      );
}

/// App bar used in the application flow with a step progress indicator.
class StepScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int step;
  final int totalSteps;
  final Widget body;
  final Widget? bottom;
  const StepScaffold({super.key, required this.title, this.subtitle, required this.step, this.totalSteps = 7, required this.body, this.bottom});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.maybePop(context)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text('Step $step of $totalSteps', style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 13))),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: step / totalSteps,
            minHeight: 4,
            backgroundColor: const Color(0xFFEDEFF7),
            valueColor: const AlwaysStoppedAnimation(AppColors.accent),
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.2)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
            ],
            const SizedBox(height: 24),
            body,
          ],
        ),
      ),
      bottomNavigationBar: bottom == null ? null : BottomAction(child: bottom!),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator(color: AppColors.primary));
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorView({super.key, required this.message, this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SvgPicture.asset('assets/images/no_connection.svg', height: 150),
            const SizedBox(height: 20),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: AppColors.textMuted)),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              SizedBox(width: 160, child: OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry'))),
            ],
          ]),
        ),
      );
}

class EmptyView extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String asset;
  final Widget? action;
  const EmptyView({super.key, required this.title, this.subtitle, this.asset = 'assets/images/empty.svg', this.action});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SvgPicture.asset(asset, height: 160),
          const SizedBox(height: 20),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ]),
      );
}

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});

  static const _map = {
    'draft': ('In progress', Color(0xFF64748B), Color(0xFFF1F5F9)),
    'submitted': ('Submitted', Color(0xFF1D4ED8), Color(0xFFEFF6FF)),
    'under_review': ('Under review', Color(0xFFB45309), Color(0xFFFFFBEB)),
    'approved': ('Approved', Color(0xFF047857), Color(0xFFECFDF5)),
    'rejected': ('Rejected', Color(0xFFBE123C), Color(0xFFFFF1F2)),
    'disbursed': ('Active', Color(0xFF4338CA), Color(0xFFEEF2FF)),
    'closed': ('Closed', Color(0xFF0F766E), Color(0xFFF0FDFA)),
    'cancelled': ('Cancelled', Color(0xFF64748B), Color(0xFFF1F5F9)),
    'pending': ('Pending', Color(0xFFB45309), Color(0xFFFFFBEB)),
    'paid': ('Paid', Color(0xFF047857), Color(0xFFECFDF5)),
    'verified': ('Verified', Color(0xFF047857), Color(0xFFECFDF5)),
    'overdue': ('Overdue', Color(0xFFBE123C), Color(0xFFFFF1F2)),
  };

  @override
  Widget build(BuildContext context) {
    final m = _map[status] ?? (status, AppColors.textMuted, const Color(0xFFF1F5F9));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: m.$3, borderRadius: BorderRadius.circular(20)),
      child: Text(m.$1, style: TextStyle(color: m.$2, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

/// Tile that lets the user capture or pick a document photo.
class DocUploadTile extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final String? localPath;
  final String? remoteName; // already uploaded file name
  final ValueChanged<String> onPicked;
  final bool cameraOnly;
  final bool frontCamera;

  const DocUploadTile({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.onPicked,
    this.localPath,
    this.remoteName,
    this.cameraOnly = false,
    this.frontCamera = false,
  });

  Future<void> _pick(BuildContext context) async {
    ImageSource? src = ImageSource.camera;
    if (!cameraOnly) {
      src = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Upload $label', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(backgroundColor: AppColors.primarySoft, child: Icon(Icons.photo_camera_rounded, color: AppColors.primary)),
                title: const Text('Take a photo', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: AppColors.accentSoft, child: Icon(Icons.photo_library_rounded, color: AppColors.accentDark)),
                title: const Text('Choose from gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ]),
          ),
        ),
      );
    }
    if (src == null || !context.mounted) return;
    if (src == ImageSource.camera) {
      final st = await Permission.camera.request();
      if (!st.isGranted) {
        if (context.mounted) {
          showSnack(context, 'Camera permission is needed to capture documents. Enable it in Settings.', error: true);
        }
        if (st.isPermanentlyDenied) openAppSettings();
        return;
      }
    }
    try {
      final x = await ImagePicker().pickImage(
        source: src,
        imageQuality: 72,
        maxWidth: 1800,
        preferredCameraDevice: frontCamera ? CameraDevice.front : CameraDevice.rear,
      );
      if (x != null) onPicked(x.path);
    } catch (e) {
      if (context.mounted) showSnack(context, 'Could not open camera/gallery', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = localPath != null || remoteName != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _pick(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: done ? AppColors.accentSoft.withValues(alpha: 0.5) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: done ? AppColors.accent : AppColors.border, width: done ? 1.4 : 1),
          ),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 64,
                height: 64,
                color: AppColors.primarySoft,
                child: localPath != null
                    ? Image.file(File(localPath!), fit: BoxFit.cover)
                    : remoteName != null
                        ? Image.network(Api.instance.fileUrl(remoteName!), headers: Api.instance.authHeaders, fit: BoxFit.cover, errorBuilder: (_, _, _) => Icon(icon, color: AppColors.primary))
                        : Icon(icon, color: AppColors.primary, size: 28),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 3),
                Text(done ? 'Tap to replace' : hint, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
              ]),
            ),
            Icon(done ? Icons.check_circle_rounded : Icons.add_a_photo_rounded, color: done ? AppColors.accent : AppColors.primary),
          ]),
        ),
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const InfoBanner({super.key, required this.text, this.icon = Icons.lock_rounded, this.color = AppColors.primary});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, height: 1.45, color: color.withValues(alpha: 0.95)))),
        ]),
      );
}

class KeyValueRow extends StatelessWidget {
  final String k;
  final String v;
  final bool bold;
  const KeyValueRow(this.k, this.v, {super.key, this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(k, style: const TextStyle(color: AppColors.textMuted, fontSize: 14))),
          const SizedBox(width: 12),
          Flexible(child: Text(v, textAlign: TextAlign.right, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: bold ? 16 : 14))),
        ]),
      );
}

class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
