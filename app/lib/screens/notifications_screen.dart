import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../theme.dart';
import '../widgets/common.dart';

class NotificationsScreen extends StatefulWidget {
  final bool embedded;
  const NotificationsScreen({super.key, this.embedded = false});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>>? items;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.instance.get('/notifications');
      if (!mounted) return;
      setState(() {
        items = List<Map<String, dynamic>>.from(r['data']['notifications']);
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    }
  }

  Future<void> _readAll() async {
    try {
      await Api.instance.put('/notifications/all/read');
      if (!mounted) return;
      await context.read<AppState>().refreshUnread();
      _load();
    } catch (_) {}
  }

  IconData _icon(String t) => switch (t) {
        'loan' => Icons.account_balance_wallet_rounded,
        'payment' => Icons.payments_rounded,
        'offer' => Icons.local_offer_rounded,
        _ => Icons.notifications_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        automaticallyImplyLeading: !widget.embedded,
        actions: [if ((items ?? []).any((n) => n['read'] != true)) TextButton(onPressed: _readAll, child: const Text('Mark all read'))],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: error != null
            ? ListView(children: [SizedBox(height: 480, child: ErrorView(message: error!, onRetry: _load))])
            : items == null
                ? const LoadingView()
                : items!.isEmpty
                    ? ListView(children: const [EmptyView(title: 'No notifications', subtitle: 'Updates about your loan will appear here')])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: items!.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final n = items![i];
                          final unread = n['read'] != true;
                          return SectionCard(
                            color: unread ? const Color(0xFFF7F8FF) : Colors.white,
                            padding: const EdgeInsets.all(14),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              CircleAvatar(backgroundColor: AppColors.primarySoft, child: Icon(_icon('${n['type']}'), color: AppColors.primary, size: 20)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Expanded(child: Text('${n['title']}', style: const TextStyle(fontWeight: FontWeight.w800))),
                                    if (unread) Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
                                  ]),
                                  const SizedBox(height: 3),
                                  Text('${n['body']}', style: const TextStyle(color: Color(0xFF334155), height: 1.4)),
                                  const SizedBox(height: 6),
                                  Text(fmtDateTime(n['createdAt']), style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                                ]),
                              ),
                            ]),
                          );
                        },
                      ),
      ),
    );
  }
}
