import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../theme.dart';
import '../loans/loans_tab.dart';
import '../notifications_screen.dart';
import '../profile/profile_tab.dart';
import 'home_tab.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final pages = [
      HomeTab(onOpenLoans: () => setState(() => index = 1)),
      const LoansTab(),
      const NotificationsScreen(embedded: true),
      const ProfileTab(),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: AppColors.primarySoft,
          labelTextStyle: WidgetStateProperty.resolveWith((st) => TextStyle(
                fontSize: 12,
                fontWeight: st.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
                color: st.contains(WidgetState.selected) ? AppColors.primary : AppColors.textMuted,
              )),
          iconTheme: WidgetStateProperty.resolveWith((st) => IconThemeData(color: st.contains(WidgetState.selected) ? AppColors.primary : AppColors.textMuted)),
        ),
        child: NavigationBar(
          selectedIndex: index,
          height: 68,
          elevation: 8,
          shadowColor: Colors.black26,
          onDestinationSelected: (i) {
            setState(() => index = i);
            if (i == 2) s.refreshUnread();
          },
          destinations: [
            const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
            const NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'My Loans'),
            NavigationDestination(
              icon: Badge(isLabelVisible: s.unread > 0, label: Text('${s.unread}'), child: const Icon(Icons.notifications_outlined)),
              selectedIcon: const Icon(Icons.notifications_rounded),
              label: 'Alerts',
            ),
            const NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
