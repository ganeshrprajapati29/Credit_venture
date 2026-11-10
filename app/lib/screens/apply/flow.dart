import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import 'address_screen.dart';
import 'bank_screen.dart';
import 'basic_info_screen.dart';
import 'employment_screen.dart';
import 'kyc_screen.dart';
import 'offer_screen.dart';
import 'personal_screen.dart';
import 'review_screen.dart';

/// Central navigation for the step-wise loan application.
class ApplyFlow {
  static const steps = ['basic', 'offer', 'personal', 'employment', 'address', 'kyc', 'bank', 'review'];
  static int get totalSteps => steps.length;

  static int stepNumber(String step) {
    final i = steps.indexOf(step);
    return i < 0 ? 1 : i + 1;
  }

  static Widget screenFor(String step) {
    switch (step) {
      case 'offer':
        return const OfferScreen();
      case 'personal':
        return const PersonalScreen();
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
        return const BasicInfoScreen();
    }
  }

  /// Opens the screen where the user left off.
  static void open(BuildContext context) {
    final loan = context.read<AppState>().loan;
    final step = loan == null ? 'basic' : '${loan['currentStep'] ?? 'basic'}';
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screenFor(step)));
  }

  /// Saves the latest loan in state and moves to the step after [from].
  static void next(BuildContext context, Map<String, dynamic> loan, String from) {
    context.read<AppState>().setLoan(loan);
    final i = steps.indexOf(from);
    final nextStep = i >= 0 && i < steps.length - 1 ? steps[i + 1] : 'review';
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screenFor(nextStep)));
  }
}
