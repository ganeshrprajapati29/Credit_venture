import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/app_state.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  final state = AppState();
  await state.init();
  runApp(ChangeNotifierProvider.value(value: state, child: const CreditVenturesApp()));
}

class CreditVenturesApp extends StatelessWidget {
  const CreditVenturesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Credit Ventures',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        // keep layouts stable on devices with very large font scaling
        data: MediaQuery.of(context).copyWith(
          textScaler: MediaQuery.of(context).textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.2),
        ),
        child: child!,
      ),
      home: const SplashScreen(),
    );
  }
}
