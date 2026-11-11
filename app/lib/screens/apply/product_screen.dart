import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'flow.dart';

String _compactInr(dynamic v) => compactInr(v).replaceAll(' Crore', ' Cr');

/// Grid of loan categories shown on the home screen.
class ProductGrid extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  const ProductGrid({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 150),
      itemBuilder: (_, i) {
        final p = products[i];
        final c = productColor(p);
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: c.withValues(alpha: 0.10), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => ProductScreen.open(context, '${p['key']}'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 14, 6, 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Color.lerp(c, Colors.white, 0.15)!, c], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Icon(productIcon('${p['key']}'), color: Colors.white, size: 25),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${p['name']}',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, height: 1.15),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        'Up to ${_compactInr(p['maxAmount']).replaceAll(' Lakh', 'L')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, color: c, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bottom sheet to pick a loan category.
Future<void> showProductPicker(BuildContext context) async {
  final s = context.read<AppState>();
  if (s.loan != null && s.loan!['status'] == 'draft') {
    ApplyFlow.open(context);
    return;
  }
  await showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.bg,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('What do you need the loan for?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Choose a loan type to see your offer', style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 18),
            ProductGrid(products: s.products),
          ],
        ),
      ),
    ),
  );
}

/// Details of one loan category with an "Apply now" button.
class ProductScreen extends StatelessWidget {
  final String productKey;
  const ProductScreen({super.key, required this.productKey});

  static void open(BuildContext context, String key) {
    Navigator.of(context).popUntil((r) => r is! ModalBottomSheetRoute);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductScreen(productKey: key)));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = s.product(productKey) ?? {};
    final c = productColor(p);
    final tenures = List<num>.from((p['tenureOptions'] as List?)?.map((e) => asNum(e) ?? 0) ?? const []);
    final steps = List<String>.from(p['steps'] ?? const []);
    final docs = [
      'Aadhaar card (front & back)',
      'PAN card',
      'Live selfie',
      'Cancelled cheque / passbook',
      if (productKey == 'business') 'GST / Udyam certificate (if available)',
      if (productKey == 'home') 'Property papers (later, at verification)',
      if (productKey == 'education') 'Admission letter & fee structure (later)',
      if (productKey == 'vehicle') 'Vehicle quotation from dealer (later)',
      if (productKey == 'personal') 'Latest salary slip (optional)',
    ];
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 230,
            backgroundColor: c,
            foregroundColor: Colors.white,
            title: Text(
              '${p['name'] ?? ''}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color.lerp(c, Colors.white, 0.08)!, Color.lerp(c, Colors.black, 0.35)!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(right: -10, bottom: -20, child: Icon(productIcon(productKey), size: 170, color: Colors.white.withValues(alpha: 0.12))),
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 64, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${p['tagline'] ?? ''}', style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
                          const SizedBox(height: 8),
                          const Text('Get up to', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          Text(
                            _compactInr(p['maxAmount']),
                            style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            sliver: SliverList.list(
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Stat('Interest from', '${p['interestRate'] ?? '--'}% p.a.'),
                      const SizedBox(width: 10),
                      _Stat('Tenure', tenures.isEmpty ? '—' : '${fmtTenure(tenures.first)} – ${fmtTenure(tenures.last)}'),
                      const SizedBox(width: 10),
                      _Stat('Processing fee', '${p['processingFeePercent'] ?? '--'}%'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Why choose us', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                SectionCard(
                  child: Column(
                    children: [
                      _Point(Icons.bolt_rounded, 'Quick digital process', 'Apply in ${steps.isEmpty ? 8 : steps.length} simple steps from your phone'),
                      _Point(
                        Icons.currency_rupee_rounded,
                        'Amount ${_compactInr(p['minAmount'])} – ${_compactInr(p['maxAmount'])}',
                        'Choose the amount and EMI that suits you',
                      ),
                      const _Point(Icons.visibility_rounded, 'Transparent pricing', 'All charges and APR shown before you sign'),
                      const _Point(Icons.verified_user_rounded, 'Safe & secure', 'Your documents are encrypted and kept private'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Eligibility', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                SectionCard(
                  child: Column(
                    children: [
                      KeyValueRow('Age', '${s.loanConfig['minAge'] ?? 21} – ${s.loanConfig['maxAge'] ?? 58} years'),
                      KeyValueRow('Minimum ${'${p['incomeLabel'] ?? 'monthly income'}'.toLowerCase()}', inr(p['minMonthlyIncome'])),
                      const KeyValueRow('Nationality', 'Indian resident'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Documents needed', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                SectionCard(
                  child: Column(
                    children: [
                      for (final d in docs)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_rounded, size: 18, color: c),
                              const SizedBox(width: 10),
                              Expanded(child: Text(d)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAction(
        child: PrimaryButton(
          label: 'Apply now',
          icon: Icons.arrow_forward_rounded,
          onPressed: () => ApplyFlow.open(context, productKey: productKey),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String k;
  final String v;
  const _Stat(this.k, this.v);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
          const SizedBox(height: 4),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
        ],
      ),
    ),
  );
}

class _Point extends StatelessWidget {
  final IconData icon;
  final String t;
  final String s;
  const _Point(this.icon, this.t, this.s);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primarySoft,
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(s, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            ],
          ),
        ),
      ],
    ),
  );
}
