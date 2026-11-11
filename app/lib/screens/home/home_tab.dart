import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../apply/flow.dart';
import '../apply/product_screen.dart';
import '../emi_calculator_screen.dart';
import '../loans/loan_detail_screen.dart';
import '../loans/payment_screen.dart';
import '../notifications_screen.dart';
import '../profile/help_screen.dart';

class HomeTab extends StatefulWidget {
  final VoidCallback onOpenLoans;
  const HomeTab({super.key, required this.onOpenLoans});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Future<void> _refresh() async {
    final s = context.read<AppState>();
    try {
      await Future.wait([s.loadConfig(), s.refreshLoan(), s.refreshUnread()]);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final name = '${s.user?['fullName'] ?? ''}'.split(' ').first;
    final cfg = s.loanConfig;
    final tenures = [for (final p in s.products) ...List<num>.from((p['tenureOptions'] as List?)?.map((e) => asNum(e) ?? 0) ?? const [])];
    final maxTen = tenures.isEmpty ? (cfg['tenureOptions'] as List?)?.last ?? 12 : tenures.reduce((a, b) => a > b ? a : b);
    final maxAmt = s.products.fold<num>(asNum(cfg['maxAmount']) ?? 0, (m, p) => (asNum(p['maxAmount']) ?? 0) > m ? asNum(p['maxAmount'])! : m);
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primary,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            // header, card and content live in one Column so the card (painted later) overlaps the header
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 14, 12, 90),
                  decoration: const BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                  ),
                  child: Row(
                    children: [
                      const BrandLogo(size: 42),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? 'Hello there 👋' : 'Hi, $name 👋',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            const Text('Welcome to Credit Ventures', style: TextStyle(color: AppColors.onHeroMuted, fontSize: 12.5)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen())),
                        icon: const Icon(Icons.headset_mic_rounded, color: Colors.white),
                      ),
                      IconButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())).then((_) => s.refreshUnread()),
                        icon: Badge(
                          isLabelVisible: s.unread > 0,
                          label: Text('${s.unread}'),
                          child: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -74),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _LoanCard(state: s, onOpenLoans: widget.onOpenLoans),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -56),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (s.products.isNotEmpty) ...[
                        _sectionTitle('Choose your loan'),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: ProductGrid(products: s.products)),
                        const SizedBox(height: 24),
                      ],
                      if (s.banners.isNotEmpty) _BannerCarousel(banners: s.banners),
                      const SizedBox(height: 22),
                      _sectionTitle('Why Credit Ventures'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.55,
                          children: [
                            _Feature(Icons.currency_rupee_rounded, 'Up to ${compactInr(maxAmt)}', 'Loan amount', const Color(0xFF0F4F3C)),
                            _Feature(
                              Icons.calendar_month_rounded,
                              'Up to ${fmtTenure(maxTen)}',
                              'Flexible tenure',
                              const Color(0xFF059669),
                            ),
                            const _Feature(Icons.description_outlined, 'Paperless', 'Digital KYC', Color(0xFF7C3AED)),
                            const _Feature(Icons.verified_user_outlined, 'Secure', 'Encrypted data', Color(0xFFEA580C)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _sectionTitle('How it works'),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _HowItWorks()),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _ActionTile(
                          icon: Icons.calculate_rounded,
                          title: 'EMI Calculator',
                          subtitle: 'Plan your loan before you apply',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmiCalculatorScreen())),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _ActionTile(
                          icon: Icons.support_agent_rounded,
                          title: 'Need help?',
                          subtitle: '${s.support['hours'] ?? 'We are here for you'}',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen())),
                        ),
                      ),
                      if ('${s.settings['lendingPartner'] ?? ''}'.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Loans are provided by our lending partner ${s.settings['lendingPartner']}${'${s.settings['nbfcRegistration'] ?? ''}'.isNotEmpty ? ' (Reg. ${s.settings['nbfcRegistration']})' : ''}.',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
  );
}

/* ----------------------------------------------------------------- main loan card */

class _LoanCard extends StatelessWidget {
  final AppState state;
  final VoidCallback onOpenLoans;
  const _LoanCard({required this.state, required this.onOpenLoans});

  @override
  Widget build(BuildContext context) {
    final loan = state.loan;
    final status = '${loan?['status'] ?? ''}';
    if (loan == null) return _applyCard(context);
    if (status == 'draft') return _draftCard(context, loan);
    if (status == 'disbursed') return _activeCard(context, loan);
    return _trackCard(context, loan);
  }

  Widget _shell({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [BoxShadow(color: Color(0x1F141C5C), blurRadius: 30, offset: Offset(0, 12))],
    ),
    padding: const EdgeInsets.all(20),
    child: child,
  );

  Widget _applyCard(BuildContext context) {
    final cfg = state.loanConfig;
    final accepting = cfg['acceptingApplications'] != false;
    return _shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(20)),
                child: const Text(
                  'LOANS FOR EVERY NEED',
                  style: TextStyle(color: AppColors.accentDark, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Get a loan of up to', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
          const SizedBox(height: 2),
          Text(
            compactInr(state.products.fold<num>(asNum(cfg['maxAmount']) ?? 0, (m, p) => (asNum(p['maxAmount']) ?? 0) > m ? asNum(p['maxAmount'])! : m)),
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.primaryDark, letterSpacing: -1),
          ),
          const SizedBox(height: 4),
          Text(
            'Personal, business, home, gold, vehicle & education loans',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: accepting ? 'Check my offer' : 'Applications paused',
            icon: accepting ? Icons.arrow_forward_rounded : null,
            onPressed: accepting ? () => showProductPicker(context) : null,
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_rounded, size: 14, color: AppColors.textMuted),
              SizedBox(width: 6),
              Text('Checking your offer will not affect your credit score', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _draftCard(BuildContext context, Map<String, dynamic> loan) {
    final steps = List<String>.from(loan['steps'] ?? StepScaffold.defaultSteps);
    final total = steps.length;
    final step = ApplyFlow.stepNumber(steps, '${loan['currentStep']}');
    final amount = dig(loan, 'offer.amount');
    return _shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Complete your application', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              const StatusChip('draft'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            amount != null
                ? 'Your ${loan['productName'] ?? 'loan'} offer of ${inr(amount)} is waiting for you'
                : 'Your ${loan['productName'] ?? 'loan'} application is just a few steps away',
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (step - 1) / total,
              minHeight: 8,
              backgroundColor: const Color(0xFFE4DDEE),
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${step - 1} of $total steps completed',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Continue application', icon: Icons.arrow_forward_rounded, onPressed: () => ApplyFlow.open(context)),
        ],
      ),
    );
  }

  Widget _trackCard(BuildContext context, Map<String, dynamic> loan) {
    final status = '${loan['status']}';
    const steps = ['submitted', 'under_review', 'approved', 'disbursed'];
    final idx = steps.indexOf(status);
    final labels = ['Submitted', 'Verification', 'Approved', 'Disbursed'];
    final msg = {
      'submitted': 'We have received your application. Our team will start verification shortly.',
      'under_review': 'Our team is verifying your documents. This usually takes a few hours.',
      'approved': 'Congratulations! Your loan of ${inr(dig(loan, 'approved.amount'))} is approved and will be credited to your bank soon.',
    }[status];
    return _shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  inr(dig(loan, 'approved.amount') ?? dig(loan, 'offer.amount')),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                ),
              ),
              StatusChip(status),
            ],
          ),
          Text('Application ${loan['loanNumber']}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          const SizedBox(height: 18),
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                Column(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: i <= idx ? AppColors.accent : const Color(0xFFE2E8F0),
                      child: Icon(i <= idx ? Icons.check_rounded : Icons.circle, size: i <= idx ? 16 : 8, color: i <= idx ? Colors.white : Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[i],
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: i <= idx ? AppColors.text : AppColors.textMuted),
                    ),
                  ],
                ),
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(height: 3, margin: const EdgeInsets.only(bottom: 20), color: i < idx ? AppColors.accent : const Color(0xFFE2E8F0)),
                  ),
              ],
            ],
          ),
          if (msg != null) ...[const SizedBox(height: 14), InfoBanner(text: msg, icon: Icons.info_outline_rounded)],
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoanDetailScreen(loanId: '${loan['_id']}'))),
            child: const Text('View details'),
          ),
        ],
      ),
    );
  }

  Widget _activeCard(BuildContext context, Map<String, dynamic> loan) {
    final schedule = List<Map<String, dynamic>>.from(loan['schedule'] ?? []);
    final next = schedule.cast<Map<String, dynamic>?>().firstWhere((e) => e?['status'] != 'paid', orElse: () => null);
    final paid = schedule.where((e) => e['status'] == 'paid').length;
    final due = next == null ? null : DateTime.tryParse('${next['dueDate']}');
    final overdue = due != null && due.isBefore(DateTime.now());
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x40141C5C), blurRadius: 30, offset: Offset(0, 12))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Next EMI',
                  style: TextStyle(color: AppColors.onHeroMuted, fontWeight: FontWeight.w600),
                ),
              ),
              if (overdue)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFFFE4E6), borderRadius: BorderRadius.circular(20)),
                  child: const Text(
                    'Overdue',
                    style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            next == null ? 'All paid 🎉' : inr(next['amount']),
            style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800),
          ),
          if (next != null)
            Text('Due on ${fmtDate(next['dueDate'])} · EMI ${next['installmentNo']} of ${schedule.length}', style: const TextStyle(color: AppColors.onHeroSoft)),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: schedule.isEmpty ? 0 : paid / schedule.length,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF6EE7B7)),
            ),
          ),
          const SizedBox(height: 6),
          Text('$paid of ${schedule.length} EMIs paid · Loan ${loan['loanNumber']}', style: const TextStyle(color: AppColors.onHeroMuted, fontSize: 12)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, minimumSize: const Size.fromHeight(50)),
                  onPressed: next == null
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PaymentScreen(loan: loan, installment: next),
                          ),
                        ),
                  child: const Text('Pay EMI'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoanDetailScreen(loanId: '${loan['_id']}'))),
                  child: const Text('Details'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ----------------------------------------------------------------- banners */

class _BannerCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> banners;
  const _BannerCarousel({required this.banners});
  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final _pc = PageController(viewportFraction: 0.92);
  int page = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_pc.hasClients || widget.banners.length < 2) return;
      final next = (page + 1) % widget.banners.length;
      _pc.animateToPage(next, duration: const Duration(milliseconds: 450), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  Color _hex(String? h) {
    final v = int.tryParse((h ?? '').replaceFirst('#', ''), radix: 16);
    return v == null ? AppColors.primaryDeep : Color(0xFF000000 | v);
  }

  void _tap(Map<String, dynamic> b) {
    final action = '${b['ctaAction'] ?? 'apply'}';
    if (action == 'link' && '${b['link'] ?? ''}'.startsWith('http')) {
      launchUrl(Uri.parse('${b['link']}'), mode: LaunchMode.externalApplication);
    } else if (action == 'apply') {
      final s = context.read<AppState>();
      if (s.loan == null || s.loan!['status'] == 'draft') showProductPicker(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _pc,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => page = i),
            itemBuilder: (_, i) {
              final b = widget.banners[i];
              final color = _hex(b['bgColor']);
              final img = b['imageUrl'];
              return GestureDetector(
                onTap: () => _tap(b),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.35)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: img != null ? CachedNetworkImage(imageUrl: '$img', fit: BoxFit.cover, errorWidget: (_, _, _) => _textBanner(b)) : _textBanner(b),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.banners.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == page ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(color: i == page ? AppColors.primary : AppColors.border, borderRadius: BorderRadius.circular(6)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _textBanner(Map<String, dynamic> b) => Stack(
    children: [
      Positioned(right: -30, top: -30, child: CircleAvatar(radius: 70, backgroundColor: Colors.white.withValues(alpha: 0.08))),
      Positioned(right: 30, bottom: -40, child: CircleAvatar(radius: 50, backgroundColor: Colors.white.withValues(alpha: 0.06))),
      Positioned(right: 18, top: 0, bottom: 0, child: Icon(Icons.currency_rupee_rounded, size: 84, color: Colors.white.withValues(alpha: 0.16))),
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${b['title'] ?? ''}',
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, height: 1.2),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 220,
              child: Text('${b['subtitle'] ?? ''}', maxLines: 2, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
            ),
            if ('${b['ctaText'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '${b['ctaText']}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.primaryDark),
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

/* ----------------------------------------------------------------- small widgets */

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _Feature(this.icon, this.title, this.subtitle, this.color);
  @override
  Widget build(BuildContext context) => SectionCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
            ),
            Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      ],
    ),
  );
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();
  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.person_outline_rounded, 'Share basic details', 'Name, income and employment'),
      (Icons.local_offer_outlined, 'Get your offer', 'Choose amount and EMI tenure'),
      (Icons.badge_outlined, 'Upload KYC', 'Aadhaar, PAN, selfie & bank proof'),
      (Icons.account_balance_outlined, 'Money in your bank', 'After verification & e-sign'),
    ];
    return SectionCard(
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primarySoft,
                      child: Icon(steps[i].$1, size: 18, color: AppColors.primary),
                    ),
                    if (i < steps.length - 1) Container(width: 2, height: 26, color: AppColors.primarySoft),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(steps[i].$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(steps[i].$3, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: SectionCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    ),
  );
}
