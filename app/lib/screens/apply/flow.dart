import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../widgets/common.dart';
import 'address_screen.dart';
import 'bank_screen.dart';
import 'basic_info_screen.dart';
import 'employment_screen.dart';
import 'kyc_screen.dart';
import 'offer_screen.dart';
import 'personal_screen.dart';
import 'product_details_screen.dart';
import 'review_screen.dart';

/// Central navigation for the step-wise, category specific loan application.
class ApplyFlow {
  static List<String> stepsOf(BuildContext context, [String? productKey]) => StepScaffold.stepsFor(context.read<AppState>(), productKey);

  /// 1-based position of [step] for the loan in progress.
  static int stepNumber(List<String> steps, String step) {
    final i = steps.indexOf(step);
    return i < 0 ? 1 : i + 1;
  }

  static Widget screenFor(String step, {String? productKey}) {
    switch (step) {
      case 'offer':
        return const OfferScreen();
      case 'personal':
        return const PersonalScreen();
      case 'product':
        return const ProductDetailsScreen();
      case 'employment':
        return const EmploymentScreen();
      case 'address':
        return const AddressScreen();
      case 'kyc':
        return const KycScreen();
      case 'bank':
        return const BankScreen();
      case 'review':
        return const ReviewScreen();
      default:
        return BasicInfoScreen(productKey: productKey);
    }
  }

  /// Opens the application. With [productKey] it starts / continues that loan type;
  /// without it, resumes the draft where the user left off.
  static Future<void> open(BuildContext context, {String? productKey}) async {
    final s = context.read<AppState>();
    final loan = s.loan;
    final nav = Navigator.of(context);
    if (loan != null && loan['status'] != 'draft') {
      showSnack(context, 'You already have an active application (${loan['loanNumber']}).', error: true);
      return;
    }
    if (loan == null) {
      nav.push(MaterialPageRoute(builder: (_) => BasicInfoScreen(productKey: productKey)));
      return;
    }
    final draftProduct = '${loan['product'] ?? 'personal'}';
    if (productKey != null && productKey != draftProduct) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Application in progress'),
          content: Text(
            'You have an incomplete ${loan['productName'] ?? 'loan'} application. Continue it, or start a ${s.product(productKey)?['name'] ?? 'new'} application instead?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, 'new'), child: const Text('Start new')),
            TextButton(onPressed: () => Navigator.pop(ctx, 'continue'), child: const Text('Continue')),
          ],
        ),
      );
      if (choice == null) return;
      if (choice == 'new') {
        nav.push(MaterialPageRoute(builder: (_) => BasicInfoScreen(productKey: productKey)));
        return;
      }
    }
    final step = '${loan['currentStep'] ?? 'basic'}';
    nav.push(MaterialPageRoute(builder: (_) => screenFor(step, productKey: draftProduct)));
  }

  /// Saves the latest loan in state and moves to the step after [from].
  static void next(BuildContext context, Map<String, dynamic> loan, String from) {
    context.read<AppState>().setLoan(loan);
    final steps = List<String>.from(loan['steps'] ?? StepScaffold.defaultSteps);
    final i = steps.indexOf(from);
    final nextStep = i >= 0 && i < steps.length - 1 ? steps[i + 1] : 'review';
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screenFor(nextStep, productKey: '${loan['product']}')));
  }
}
