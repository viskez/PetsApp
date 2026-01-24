// lib/app_shell.dart
import 'package:flutter/material.dart';
import 'tabs/home_tab.dart';
import 'tabs/buy_tab.dart';
import 'tabs/sell_tab.dart';
import 'tabs/help_tab.dart';
import 'models/session.dart';
import 'widgets/side_app_menu.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  String _buySearchQuery = '';
  int _notificationCount = 0;
  late double _dragStartX;
  
  void _goToTab(int i) => setState(() => _index = i);
  
  void _handleHorizontalSwipe(double dx) {
    const threshold = 50.0;
    if (dx.abs() < threshold) return;
    
    if (dx > 0 && _index > 0) {
      // Swiped right, go to previous tab
      _goToTab(_index - 1);
    } else if (dx < 0 && _index < 3) {
      // Swiped left, go to next tab
      _goToTab(_index + 1);
    }
  }

  void _handleHomeSearch(String value) {
    final query = value.trim();
    setState(() {
      _buySearchQuery = query;
      _index = 1;
    });
  }

  void _openNotifications() {
    // No notification screen in this lightweight shell; reset badge.
    if (_notificationCount != 0) {
      setState(() => _notificationCount = 0);
    }
  }

  List<SideMenuItem<String>> _menuItems() => const [
        SideMenuItem(
          icon: Icons.home_rounded,
          label: 'Home',
          value: 'home',
        ),
        SideMenuItem(
          icon: Icons.shopping_bag_outlined,
          label: 'Buy',
          value: 'buy',
        ),
        SideMenuItem(
          icon: Icons.sell_outlined,
          label: 'Sell',
          value: 'sell',
        ),
        SideMenuItem(
          icon: Icons.help_outline,
          label: 'Help',
          value: 'help',
        ),
      ];

  Future<void> _openMenu() async {
    final user = Session.currentUser;
    final choice = await showSideAppMenu<String>(
      context: context,
      items: _menuItems(),
      headline: user.name.isEmpty ? 'Guest User' : user.name,
      subtitle: user.role.isEmpty ? 'Traveller' : user.role,
      caption: user.email,
      avatarImage: const AssetImage('assets/icons/app_icon.png'),
    );
    switch (choice) {
      case 'home':
        _goToTab(0);
        break;
      case 'buy':
        _goToTab(1);
        break;
      case 'sell':
        _goToTab(2);
        break;
      case 'help':
        _goToTab(3);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeTab(
        onGoToTab: _goToTab,
        onSearch: _handleHomeSearch,
        onOpenNotifications: _openNotifications,
        notificationCount: _notificationCount,
        onOpenMenu: _openMenu,
      ),
      BuyTab(searchQuery: _buySearchQuery),
      SellTab(),
      const HelpTab(),
    ];

    return Scaffold(
      body: GestureDetector(
        onHorizontalDragStart: (details) => _dragStartX = details.globalPosition.dx,
        onHorizontalDragEnd: (details) {
          final dx = details.velocity.pixelsPerSecond.dx;
          _handleHorizontalSwipe(dx);
        },
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.shopping_bag_outlined), label: 'Buy'),
          NavigationDestination(icon: Icon(Icons.sell_outlined), label: 'Sell'),
          NavigationDestination(icon: Icon(Icons.help_outline), label: 'Help'),
        ],
      ),
    );
  }
}
