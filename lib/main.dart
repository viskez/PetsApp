import 'package:flutter/material.dart';

// Tabs
import 'tabs/home_tab.dart';
import 'tabs/buy_tab.dart';
import 'tabs/sell_tab.dart';
import 'tabs/help_tab.dart';

// Widgets
import 'widgets/rounded_footer_nav.dart';

// Wishlist + catalog + data + details
import 'models/wishlist.dart';
import 'models/pet_catalog.dart';
import 'models/pet_data.dart';
import 'views/profile_screen.dart';
import 'views/profile_settings_screen.dart';
import 'views/plan_screen.dart';
import 'views/splash_screen.dart';
import 'views/login_screen.dart';
import 'views/notifications_screen.dart';
import 'views/wishlist_screen.dart';
import 'models/session.dart';
import 'models/theme_store.dart';
import 'models/plan_store.dart';
import 'widgets/side_app_menu.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeStore.init();
  await PetCatalog.initWithLocalOverrides(PET_CATALOG);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeOption>(
      valueListenable: ThemeStore.current,
      builder: (_, themeOpt, __) {
        return MaterialApp(
          title: 'PetsApp',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: themeOpt.color),
            scaffoldBackgroundColor: const Color(0xFFF4F7F5),
          ),
          home: SplashScreen(
            loginBuilder: (_) => LoginScreen(
              onLoginSuccess: (ctx, role, name) {
                Navigator.pushReplacement(
                  ctx,
                  MaterialPageRoute(builder: (_) => const RootScaffold()),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key});
  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

enum AppMenuAction {
  buy,
  sell,
  help,
  myProfile,
  myPlan,
  profileSettings,
  information,
  version,
  logout
}

class _RootScaffoldState extends State<RootScaffold> {
  final wishlist = WishlistStore();

  int _index = 0;
  int _notificationCount = 1;
  int _pointsLeft = 0;
  late final VoidCallback _planListener;
  void _goTo(int i) => setState(() => _index = i);

  final TextEditingController _searchCtrl = TextEditingController();
  bool _showSearch = false;
  String _buySearchQuery = '';

  @override
  void initState() {
    super.initState();
    _planListener = () => _loadPoints();
    PlanStore.pointsVersion.addListener(_planListener);
    _loadPoints();
  }

  @override
  void dispose() {
    PlanStore.pointsVersion.removeListener(_planListener);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    if (_showSearch) {
      _searchCtrl.clear();
      FocusScope.of(context).unfocus();
      setState(() {
        _showSearch = false;
        _buySearchQuery = '';
      });
      return;
    }

    if (_index != 1) {
      _goTo(1);
    }
    setState(() => _showSearch = true);
  }

  void _onSearchChanged(String value) {
    setState(() {
      _buySearchQuery = value.trim();
    });
  }

  void _onHomeSearch(String value) {
    final query = value.trim();
    setState(() {
      _buySearchQuery = query;
      _showSearch = false;
    });
    _goTo(1);
  }

  List<SideMenuItem<AppMenuAction>> _menuItems() => const [
        SideMenuItem(
          icon: Icons.shopping_bag_outlined,
          label: 'Buy',
          value: AppMenuAction.buy,
        ),
        SideMenuItem(
          icon: Icons.sell_outlined,
          label: 'Sell',
          value: AppMenuAction.sell,
        ),
        SideMenuItem(
          icon: Icons.help_outline,
          label: 'Help',
          value: AppMenuAction.help,
        ),
        SideMenuItem(
          icon: Icons.person_outline,
          label: 'My Profile',
          value: AppMenuAction.myProfile,
        ),
        SideMenuItem(
          icon: Icons.workspace_premium_outlined,
          label: 'My Plan',
          value: AppMenuAction.myPlan,
        ),
        SideMenuItem(
          icon: Icons.settings_outlined,
          label: 'Profile Settings',
          value: AppMenuAction.profileSettings,
        ),
        SideMenuItem(
          icon: Icons.info_outline,
          label: 'Information',
          value: AppMenuAction.information,
        ),
        SideMenuItem(
          icon: Icons.system_update_alt_outlined,
          label: 'Version / Update',
          value: AppMenuAction.version,
        ),
        SideMenuItem(
          icon: Icons.logout,
          label: 'Logout',
          value: AppMenuAction.logout,
          iconColor: Colors.white,
        ),
      ];

  void _handleMenuAction(AppMenuAction action) {
    switch (action) {
      case AppMenuAction.buy:
        _goTo(1);
        break;
      case AppMenuAction.sell:
        _goTo(2);
        break;
      case AppMenuAction.help:
        _goTo(3);
        break;
      case AppMenuAction.myProfile:
        _goTo(4);
        break;
      case AppMenuAction.myPlan:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PlanScreen()),
        );
        break;
      case AppMenuAction.profileSettings:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
        );
        break;
      case AppMenuAction.information:
        showAboutDialog(
          context: context,
          applicationName: 'PetsApp',
          applicationVersion: 'v1.0.0',
          applicationIcon: const Icon(Icons.info_outline, color: Colors.teal),
          children: const [
            Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Browse and sell pets, track your plan usage, and reach out via Help whenever you need support.',
              ),
            ),
          ],
        );
        break;
      case AppMenuAction.version:
        showAboutDialog(
          context: context,
          applicationName: 'PetsApp',
          applicationVersion: 'v1.0.0',
          applicationIcon: const Icon(Icons.pets, color: Colors.teal),
        );
        break;
      case AppMenuAction.logout:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => LoginScreen(
              onLoginSuccess: (ctx, role, name) {
                Navigator.pushReplacement(
                  ctx,
                  MaterialPageRoute(builder: (_) => const RootScaffold()),
                );
              },
            ),
          ),
          (route) => false,
        );
        break;
    }
  }

  void _openMenu() {
    final user = Session.currentUser;
    showSideAppMenu<AppMenuAction>(
      context: context,
      items: _menuItems(),
      headline: user.name.isEmpty ? 'Guest User' : user.name,
      subtitle: user.role.isEmpty ? 'Traveller' : user.role,
      caption: user.email,
      avatarImage: const AssetImage('assets/icons/app_icon.png'),
    ).then((action) {
      if (action != null) _handleMenuAction(action);
    });
  }

  Widget _buildSearchField() {
    return SizedBox(
      key: const ValueKey('searchField'),
      height: kToolbarHeight - 10,
      child: TextField(
        controller: _searchCtrl,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search pets or breeds',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchCtrl.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    _onSearchChanged('');
                  },
                ),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pages = <Widget>[
      HomeTab(
        onGoToTab: _goTo,
        onSearch: _onHomeSearch,
        onOpenNotifications: _openNotifications,
        notificationCount: _notificationCount,
        onOpenMenu: _openMenu,
      ),
      BuyTab(searchQuery: _buySearchQuery),
      SellTab(),
      const HelpTab(),
      const ProfileScreen(),
    ];
    final profileLabel = _profileTabLabel();
    final showAppBar = _index != 0;

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              elevation: 0,
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              titleSpacing: 0,
              leadingWidth: 64,
              leading: IconButton(
                tooltip: 'Menu',
                icon: Icon(Icons.menu_rounded, color: scheme.onPrimary),
                onPressed: _openMenu,
              ),
              title: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _showSearch
                    ? _buildSearchField()
                    : Text('PetsApp',
                        key: const ValueKey('title'),
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: scheme.onPrimary)),
              ),
              actions: [
                // Heart with badge; opens wishlist popup
                ValueListenableBuilder<Set<String>>(
                  valueListenable: wishlist.ids,
                  builder: (_, ids, __) {
                    final count = ids.length;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          tooltip: 'Wishlist',
                          icon: const Icon(Icons.favorite_border),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const WishlistScreen()),
                            );
                          },
                        ),
                        if (count > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: 'Notifications',
                      icon: const Icon(Icons.notifications_none),
                      onPressed: _openNotifications,
                    ),
                    if (_notificationCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$_notificationCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Plan & points',
                        icon: Image.asset(
                          'assets/icons/coin.png',
                          width: 22,
                          height: 22,
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    const ProfileScreen(initialTab: 1)),
                          );
                        },
                      ),
                      Text(
                        '${_pointsLeft.clamp(0, 1000000)}',
                        style: TextStyle(
                          color: scheme.onPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : null,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: RoundedFooterNav(
        currentIndex: _index,
        onTap: _goTo,
        profileLabel: profileLabel,
      ),
    );
  }

  String _profileTabLabel() {
    final name = Session.currentUser.name.trim();
    if (name.isEmpty) return 'Profile';
    return name.length > 10 ? '${name.substring(0, 10)}…' : name;
  }

  void _openNotifications() {
    if (_notificationCount != 0) {
      setState(() => _notificationCount = 0);
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NotificationScreen()),
    );
  }

  Future<void> _loadPoints() async {
    final status = await PlanStore().loadForUser(Session.currentUser.email);
    if (!mounted) return;
    setState(() {
      _pointsLeft = status.points;
    });
  }
}
