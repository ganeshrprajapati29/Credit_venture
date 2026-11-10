import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../auth/mobile_screen.dart';
import '../emi_calculator_screen.dart';
import '../legal_screen.dart';
import 'help_screen.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final u = s.user ?? {};
    final name = '${u['fullName'] ?? ''}'.trim();
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(22)),
          child: Row(children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              child: Text(name.isEmpty ? 'CV' : name.split(' ').where((e) => e.isNotEmpty).take(2).map((e) => e[0].toUpperCase()).join(),
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name.isEmpty ? 'Complete your profile' : name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                Text('+91 ${u['mobile'] ?? ''}', style: const TextStyle(color: Color(0xFFC3CBFD))),
                if ('${u['email'] ?? ''}'.isNotEmpty) Text('${u['email']}', style: const TextStyle(color: Color(0xFFC3CBFD), fontSize: 12.5)),
              ]),
            ),
            IconButton(onPressed: () => _editProfile(context, s), icon: const Icon(Icons.edit_rounded, color: Colors.white)),
          ]),
        ),
        const SizedBox(height: 18),
        _group([
          _item(Icons.calculate_outlined, 'EMI calculator', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmiCalculatorScreen()))),
          _item(Icons.lock_reset_rounded, 'Change MPIN', () => _changeMpin(context)),
          _item(Icons.privacy_tip_outlined, 'App permissions', () => openAppSettings()),
        ]),
        const SizedBox(height: 14),
        _group([
          _item(Icons.support_agent_rounded, 'Help & support', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen()))),
          _item(Icons.description_outlined, 'Terms of service', () => LegalScreen.open(context, terms: true)),
          _item(Icons.shield_outlined, 'Privacy policy', () => LegalScreen.open(context, terms: false)),
        ]),
        const SizedBox(height: 14),
        _group([
          _item(Icons.logout_rounded, 'Logout', () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Logout?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout')),
                ],
              ),
            );
            if (ok != true || !context.mounted) return;
            await s.logout();
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MobileScreen()), (_) => false);
            }
          }, color: AppColors.danger),
        ]),
        const SizedBox(height: 20),
        Center(child: Text('Credit Ventures v${s.appVersion}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12))),
      ]),
    );
  }

  Widget _group(List<Widget> children) => SectionCard(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[children[i], if (i < children.length - 1) const Divider(indent: 60)],
        ]),
      );

  Widget _item(IconData icon, String label, VoidCallback onTap, {Color? color}) => ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: (color ?? AppColors.primary).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color ?? AppColors.primary, size: 20),
        ),
        title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
      );

  Future<void> _editProfile(BuildContext context, AppState s) async {
    final name = TextEditingController(text: '${s.user?['fullName'] ?? ''}');
    final email = TextEditingController(text: '${s.user?['email'] ?? ''}');
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Edit profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          AppField(controller: name, label: 'Full name', caps: TextCapitalization.words),
          AppField(controller: email, label: 'Email', keyboardType: TextInputType.emailAddress),
          PrimaryButton(
            label: 'Save',
            onPressed: () async {
              try {
                await s.updateProfile({'fullName': name.text.trim(), 'email': email.text.trim()});
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) showSnack(ctx, errorText(e), error: true);
              }
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _changeMpin(BuildContext context) async {
    final oldPin = TextEditingController();
    final newPin = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Change MPIN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          AppField(controller: oldPin, label: 'Current MPIN', obscure: true, keyboardType: TextInputType.number, maxLength: 4, formatters: [FilteringTextInputFormatter.digitsOnly]),
          AppField(controller: newPin, label: 'New MPIN', obscure: true, keyboardType: TextInputType.number, maxLength: 4, formatters: [FilteringTextInputFormatter.digitsOnly]),
          PrimaryButton(
            label: 'Update MPIN',
            onPressed: () async {
              try {
                await Api.instance.put('/auth/mpin', {'oldMpin': oldPin.text, 'newMpin': newPin.text});
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  showSnack(context, 'MPIN updated');
                }
              } catch (e) {
                if (ctx.mounted) showSnack(ctx, errorText(e), error: true);
              }
            },
          ),
        ]),
      ),
    );
  }
}
