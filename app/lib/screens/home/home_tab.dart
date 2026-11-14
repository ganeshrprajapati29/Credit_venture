import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/loan_tracker.dart';
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

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final fullName = '${s.user?['fullName'] ?? ''}'.trim();
    final name = fullName.split(' ').first;
    final initials = fullName.isEmpty ? 'CV' : fullName.split(' ').where((e) => e.isNotEmpty).take(2).map((e) => e[0].toUpperCase()).join();
    final cfg = s.loanConfig;
    final tenures = [for (final p in s.products) ...List<num>.from((p['tenureOptions'] as List?)?.map((e) => asNum(e) ?? 0) ?? const [])];
    final maxTen = tenures.isEmpty ? (cfg['tenureOptions'] as List?)?.last ?? 12 : tenures.reduce((a, b) => a > b ? a : b);
    final maxAmt = s.products.fold<num>(asNum(cfg['maxAmount']) ?? 0, (m, p) => (asNum(p['maxAmount']) ?? 0) > m ? asNum(p['maxAmount'])! : m);
    final rates = [for (final p in s.products) asNum(p['interestRate']) ?? 0].where((r) => r > 0).toList();
    final minRate = rates.isEmpty ? asNum(cfg['interestRate']) : rates.reduce((a, b) => a < b ? a : b);
    final top = MediaQuery.of(context).padding.top;

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primary,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            // header, card and content share one Column so later children paint over the header
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                  child: Container(
                    decoration: const BoxDecoration(gradient: AppColors.heroGradient),
                    child: Stack(
                      children: [
                        Positioned(right: -60, top: -40, child: _Bubble(size: 200, opacity: 0.07)),
                        Positioned(left: -50, bottom: -70, child: _Bubble(size: 180, opacity: 0.05)),
                        Positioned(right: 30, bottom: 70, child: _Bubble(size: 60, opacity: 0.06)),
                        Padding(
                          padding: EdgeInsets.fromLTRB(20, top + 14, 10, 104),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                                    ),
                                    child: Text(
                                      initials,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _greeting,
                                          style: const TextStyle(color: AppColors.onHeroMuted, fontSize: 12.5, fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          name.isEmpty ? 'Welcome 👋' : '$name 👋',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _HeaderIcon(
                                    icon: Icons.headset_mic_rounded,
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen())),
                                  ),
                                  _HeaderIcon(
                                    icon: Icons.notifications_none_rounded,
                                    badge: s.unread,
                                    onTap: () =>
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())).then((_) => s.refreshUnread()),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Get instant loans up to',
                                style: TextStyle(color: AppColors.onHeroMuted, fontSize: 13.5, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                compactInr(maxAmt),
                                style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.15),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (minRate != null) _HeroChip(Icons.percent_rounded, 'Interest from $minRate% p.a.'),
                                  _HeroChip(Icons.schedule_rounded, 'Up to ${fmtTenure(maxTen)}'),
                                  const _HeroChip(Icons.bolt_rounded, '100% digital'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -78),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _LoanCard(state: s, onOpenLoans: widget.onOpenLoans),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -60),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SectionCard(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                          child: Row(
                            children: [
                              _QuickAction(Icons.flash_on_rounded, 'Check\neligibility', const Color(0xFF0F4F3C), () => showProductPicker(context)),
                              _QuickAction(
                                Icons.calculate_rounded,
                                'EMI\ncalculator',
                                const Color(0xFF7C3AED),
                                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmiCalculatorScreen())),
                              ),
                              _QuickAction(Icons.receipt_long_rounded, 'My\nloans', const Color(0xFF0369A1), widget.onOpenLoans),
                              _QuickAction(
                                Icons.support_agent_rounded,
                                'Help &\nsupport',
                                const Color(0xFFEA580C),
                                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen())),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      if (s.products.isNotEmpty) ...[
                        _sectionTitle('Choose your loan', 'Pick what you need, we will do the rest'),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ProductGrid(products: s.products),
                        ),
                        const SizedBox(height: 26),
                      ],
                      if (s.banners.isNotEmpty) ...[_BannerCarousel(banners: s.banners), const SizedBox(height: 26)],
                      _sectionTitle('Why Credit Ventures', 'Simple, transparent and secure'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.3,
                          children: [
                            _Feature(Icons.currency_rupee_rounded, 'Up to ${compactInr(maxAmt)}', 'Loan amount', const Color(0xFF0F4F3C)),
                            _Feature(Icons.calendar_month_rounded, 'Up to ${fmtTenure(maxTen)}', 'Flexible tenure', const Color(0xFF0369A1)),
                            const _Feature(Icons.description_outlined, 'Paperless', 'Digital KYC', Color(0xFF7C3AED)),
                            const _Feature(Icons.visibility_outlined, 'No hidden fees', 'APR shown upfront', Color(0xFFEA580C)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                      _sectionTitle('How it works', 'Get your loan in 4 easy steps'),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _HowItWorks()),
                      const SizedBox(height: 26),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _TrustCard()),
                      const SizedBox(height: 22),
                      Center(
                        child: Column(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const BrandLogo(size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  '${s.settings['companyName'] ?? 'Credit Ventures'}',
                                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text('Made with ❤ in India', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      if ('${s.settings['lendingPartner'] ?? ''}'.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'Loans are provided by our lending partner ${s.settings['lendingPartner']}${'${s.settings['nbfcRegistration'] ?? ''}'.isNotEmpty ? ' (Reg. ${s.settings['nbfcRegistration']})' : ''}.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
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

  Widget _sectionTitle(String t, [String? sub]) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
        if (sub != null) ...[const SizedBox(height: 2), Text(sub, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted))],
      ],
    ),
  );
}

/* ----------------------------------------------------------------- header bits */

class _Bubble extends StatelessWidget {
  final double size;
  final double opacity;
  const _Bubble({required this.size, required this.opacity});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity),
    ),
  );
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int badge;
  const _HeaderIcon({required this.icon, required this.onTap, this.badge = 0});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 6),
    child: Material(
      color: Colors.white.withValues(alpha: 0.14),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Center(
            child: Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              child: Icon(icon, color: Colors.white, size: 21),
            ),
          ),
        ),
      ),
    ),
  );
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HeroChip(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(30)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFFFDE68A)),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(this.icon, this.label, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 23),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.2),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TrustCard extends StatelessWidget {
  const _TrustCard();
  @override
  Widget build(BuildContext context) {
    const items = [(Icons.lock_rounded, 'Encrypted'), (Icons.verified_user_rounded, 'Data private'), (Icons.gavel_rounded, 'Fair practices')];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFE6F4EE), Color(0xFFF4FAF7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCFE7DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your data is safe with us', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    SizedBox(height: 2),
                    Text('We never access your contacts, SMS or gallery.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final it in items)
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(it.$1, size: 15, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          it.$2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
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
      boxShadow: const [BoxShadow(color: Color(0x220A3A2C), blurRadius: 30, offset: Offset(0, 12))],
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(20)),
                      child: const Text(
                        'PRE-APPROVED OFFERS',
                        style: TextStyle(color: AppColors.accentDark, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Your loan is just\na few taps away', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.25)),
                    const SizedBox(height: 6),
                    const Text(
                      'Check your eligibility in 2 minutes. No paperwork, no branch visit.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SvgPicture.asset('assets/images/onboard_1.svg', width: 96, height: 96),
            ],
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
              Icon(Icons.lock_rounded, size: 13, color: AppColors.textMuted),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Checking your offer will not affect your credit score',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
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
    final product = state.product('${loan['product']}');
    final approved = status == 'approved';
    final label = loanStatusLabel(loan, product);
    return _shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: productColor(product).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(productIcon('${loan['product']}'), color: productColor(product), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        inr(dig(loan, 'approved.amount') ?? dig(loan, 'offer.amount')),
                        maxLines: 1,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primaryDark, height: 1.1),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${loan['productName'] ?? 'Loan'} · ${loan['loanNumber']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _LabelChip(label: label, approved: approved),
            ],
          ),
          const SizedBox(height: 18),
          if (approved) ...[ApprovedOfferCard(loan: loan, onPaid: () => state.refreshLoan()), const SizedBox(height: 16)],
          LoanTracker(loan: loan, product: product, compact: true),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => LoanDetailScreen(loanId: '${loan['_id']}'))).then((_) => state.refreshLoan()),
            child: const Text('View full details'),
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
            Text(
              'Due on ${fmtDate(next['dueDate'])} · EMI ${next['installmentNo']} of ${schedule.length}',
              style: const TextStyle(color: AppColors.onHeroSoft),
            ),
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
          height: 176,
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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${b['title'] ?? ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, height: 1.2),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 230,
              child: Text(
                '${b['subtitle'] ?? ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5, height: 1.35),
              ),
            ),
            if ('${b['ctaText'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 10),
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
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
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

class _LabelChip extends StatelessWidget {
  final String label;
  final bool approved;
  const _LabelChip({required this.label, required this.approved});
  @override
  Widget build(BuildContext context) {
    final fg = approved ? AppColors.accentDark : const Color(0xFFB45309);
    final bg = approved ? AppColors.accentSoft : const Color(0xFFFFF7E6);
    return Container(
      constraints: const BoxConstraints(maxWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        maxLines: 2,
        textAlign: TextAlign.center,
        style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}
