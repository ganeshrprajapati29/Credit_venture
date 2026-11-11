import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/common.dart';

class NotEligibleScreen extends StatelessWidget {
  final List<String> reasons;
  const NotEligibleScreen({super.key, required this.reasons});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(backgroundColor: AppColors.bg),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const EmptyView(
          title: 'We could not find an offer right now',
          subtitle: 'Based on the details shared, you do not meet our current eligibility criteria.',
        ),
        SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Why?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            for (final r in reasons)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(child: Text(r, style: const TextStyle(height: 1.4))),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        const InfoBanner(text: 'You can update your details and check again. Make sure your income and date of birth are entered correctly.', icon: Icons.lightbulb_outline_rounded),
      ]),
      bottomNavigationBar: BottomAction(child: PrimaryButton(label: 'Back to home', onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst))),
    );
  }
}
