import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../views/check_price_screen.dart';
import '../views/pet_expert.dart';
import '../views/care_tips.dart';
import '../views/notifications_screen.dart';
import '../views/admin_dashboard.dart';
import '../views/learn_guide_screen.dart';
import '../views/pet_loan_screen.dart';
import '../views/pet_insurance_screen.dart';
import '../views/pet_discussion_screen.dart';
import '../views/play_game_screen.dart';
import '../views/pet_details.dart';
import '../models/session.dart';
import '../models/pet_catalog.dart';
import '../models/pet_data.dart';
import '../models/pet_utils.dart';
import '../models/wishlist.dart';
import '../views/wishlist_screen.dart';
import '../views/profile_screen.dart';
import '../models/plan_store.dart';
import '../widgets/pet_image.dart';
import '../tabs/sell_tab.dart';

/// Home screen. Tapping the hero cards switches the footer tabs:
/// 0=Pets, 1=Buy, 2=Sell, 3=Help
class HomeTab extends StatefulWidget {
  final ValueChanged<int> onGoToTab;
  final ValueChanged<String> onSearch;
  final VoidCallback onOpenNotifications;
  final int notificationCount;
  final VoidCallback onOpenMenu;
  const HomeTab(
      {super.key,
      required this.onGoToTab,
      required this.onSearch,
      required this.onOpenNotifications,
      required this.notificationCount,
      required this.onOpenMenu});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool get _isAdminOrOwner {
    final role = Session.currentUser.role.toLowerCase();
    return role == 'admin' || role == 'owner';
  }
  bool get _isOwner => Session.currentUser.role.toLowerCase() == 'owner';

  List<_MyPetEntry> _myPets = const [];
  bool _loadingPets = true;
  int _adminUsers = 0;
  int _adminPets = 0;
  int _adminExperts = 0;
  int _adminQueries = 0;

  bool _loadingAdminStats = true;
  late final VoidCallback _catalogListener;
  static const _defaultAdminUsers = [
    _AdminUserLite(name: 'Asha Singh', phone: '+91 90000 12345'),
    _AdminUserLite(name: 'Ravi Kumar', phone: '+91 98765 43210'),
    _AdminUserLite(name: 'Divya R', phone: '+91 93333 22211'),
  ];
  static const _defaultAdminExperts = 2;
  static const _defaultAdminQueries = 2;
  static const List<_BannerData> _banners = [
    _BannerData(
      image: 'assets/images/banner.jpg',
      title: 'Welcome to PetsApp',
      subtitle: 'Find companions, services, and trusted sellers near you.',
    ),
    _BannerData(
      image: 'assets/images/buypets.png',
      title: 'Shop happy pets',
      subtitle: 'Browse breeds, compare prices, and bring one home safely.',
    ),
    _BannerData(
      image: 'assets/images/sellpets.png',
      title: 'List your pet fast',
      subtitle: 'Post in minutes, chat with buyers, and close the deal.',
    ),
  ];
  static const Duration _bannerInterval = Duration(seconds: 3);
  late final PageController _bannerController;
  Timer? _bannerTimer;
  int _currentBanner = 0;
  final WishlistStore _wishlist = WishlistStore();
  final TextEditingController _heroSearchCtrl = TextEditingController();
  int _pointsLeft = 0;
  late final VoidCallback _planListener;
  final ScrollController _scrollController = ScrollController();
  bool _showStickyAppBar = false;

  @override
  void initState() {
    super.initState();
    _bannerController = PageController();
    _startBannerAutoplay();
    _planListener = () => _loadPoints();
    _scrollController.addListener(_handleScroll);
    PlanStore.pointsVersion.addListener(_planListener);
    _loadPoints();
    _loadMyPets();
    _loadAdminStats();
    _catalogListener = () {
      if (!mounted) return;
      _loadMyPets();
      _loadAdminStats();
    };
    PetCatalog.version.addListener(_catalogListener);
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _heroSearchCtrl.dispose();
    PlanStore.pointsVersion.removeListener(_planListener);
    PetCatalog.version.removeListener(_catalogListener);
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _openAdminSection(BuildContext context, AdminSection section) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => AdminDashboardScreen(initialSection: section)),
    ).then((_) => _loadAdminStats());
  }

  Future<void> _loadAdminStats() async {
    const storageKey = 'admin_dashboard_state_v1';
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final usersRaw = (map['users'] as List?) ?? const [];
        final petsRaw = (map['pets'] as List?) ?? const [];
        final expertsRaw = (map['experts'] as List?) ?? const [];
        final queriesRaw = (map['queries'] as List?) ?? const [];
        final users = _mergedUserCount(_parseAdminUsers(usersRaw));
        final pets = _mergedPetCount(petsRaw);
        final experts = expertsRaw.length;
        final queries = queriesRaw.length;
        if (!mounted) return;
        setState(() {
          _adminUsers = users;
          _adminPets = pets;
          _adminExperts = experts;
          _adminQueries = queries;
          _loadingAdminStats = false;
        });
        return;
      }
    } catch (_) {
      // ignore malformed cache
    }
    if (!mounted) return;
    setState(() {
      _adminUsers = _mergedUserCount(_defaultAdminUsers);
      _adminPets = _mergedPetCount(const []);
      _adminExperts = _defaultAdminExperts;
      _adminQueries = _defaultAdminQueries;
      _loadingAdminStats = false;
    });
  }

  List<_AdminUserLite> _parseAdminUsers(List raw) {
    final users = <_AdminUserLite>[];
    for (final entry in raw) {
      if (entry is Map) {
        final name = (entry['name'] ?? '').toString().trim();
        final phone = (entry['phone'] ?? '').toString().trim();
        users.add(_AdminUserLite(name: name, phone: phone));
      }
    }
    return users;
  }

  int _mergedUserCount(List<_AdminUserLite> users) {
    final merged = <_AdminUserLite>[...users];
    for (final pet in PetCatalog.all) {
      final phone = pet.phone.trim();
      final name =
          pet.sellerName.trim().isEmpty ? 'Seller' : pet.sellerName.trim();
      final exists = merged.any((u) {
        final userPhone = u.phone.trim();
        final userName = u.name.trim();
        return userPhone == phone ||
            (userName.toLowerCase() == name.toLowerCase() && phone.isNotEmpty);
      });
      if (!exists) {
        merged.add(_AdminUserLite(name: name, phone: phone));
      }
    }
    return merged.length;
  }

  int _mergedPetCount(List rawPets) {
    final titles = <String>{};
    for (final pet in PetCatalog.all) {
      titles.add(normalizePetTitle(pet.title));
    }
    for (final entry in rawPets) {
      if (entry is Map) {
        final title = (entry['title'] ?? '').toString().trim();
        if (title.isEmpty) continue;
        titles.add(normalizePetTitle(title));
      }
    }
    return titles.length;
  }

  String _adminCountLabel(int value) =>
      _loadingAdminStats ? '--' : value.toString();

  Future<void> _loadMyPets() async {
    final current = Session.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final snapKey =
        'sell_tab_form_snapshot_${current.email.toLowerCase().replaceAll(' ', '_')}';
    _MyPetEntry? draft;
    try {
      final raw = prefs.getString(snapKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final textFields = (decoded['textFields'] as Map?)
                  ?.map((k, v) => MapEntry('$k', v.toString())) ??
              {};
          final mediaPaths = [
            ..._stringList(decoded['existingImages']),
            ..._stringList(decoded['localImages']),
          ];
          final draftImage =
              mediaPaths.isEmpty ? null : mediaPaths.first.trim();
          final price = _parsePrice(textFields['price']);
          final location = (decoded['location'] as String? ?? '').trim();
          final sub = textFields['subCategory'] ?? '';
          final breed = textFields['breed'] ?? '';
          final title =
              [sub, breed].where((e) => e.trim().isNotEmpty).join(' / ');
          draft = _MyPetEntry(
            status: 'Incomplete Information',
            cta: 'Complete information',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SellTab()),
              ).then((_) => _loadMyPets());
            },
            title: title.isEmpty ? 'Draft listing' : title,
            image: draftImage,
            price: price,
            location: location.isEmpty ? null : location,
            isDraft: true,
          );
        }
      }
    } catch (_) {
      // ignore malformed draft
    }

    final phoneDigits = current.phone.replaceAll(RegExp(r'[^0-9]'), '');
    final ownedPets = PetCatalog.all.where((p) {
      final nameMatch =
          p.sellerName.toLowerCase() == current.name.toLowerCase();
      final sellerDigits = p.phone.replaceAll(RegExp(r'[^0-9]'), '');
      final phoneMatch = phoneDigits.isNotEmpty && sellerDigits == phoneDigits;
      return nameMatch || phoneMatch;
    }).toList(growable: false);

    final ownedEntries = ownedPets.map((p) {
      return _MyPetEntry(
          status: 'Complete',
          cta: 'View / edit',
          title: normalizePetTitle(p.title),
          image: p.images.isEmpty ? null : p.images.first,
          price: p.price > 0 ? p.price : null,
          location: p.location.isNotEmpty ? p.location : null,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => SellTab(initial: p, closeOnSave: true)),
            ).then((_) => _loadMyPets());
          });
    }).toList();

    final entries = [
      if (draft != null) draft,
      ...ownedEntries,
    ];

    if (!mounted) return;
    setState(() {
      _myPets = entries;
      _loadingPets = false;
    });
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => '$e')
          .where((e) => e.trim().isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }

  int? _parsePrice(String? raw) {
    if (raw == null) return null;
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
  }

  void _startBannerAutoplay() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(_bannerInterval, (_) {
      final nextPage = (_currentBanner + 1) % _banners.length;
      _animateBannerTo(nextPage);
    });
  }

  void _onBannerPageChanged(int index) {
    if (!mounted) return;
    setState(() => _currentBanner = index);
    _startBannerAutoplay();
  }

  void _animateBannerTo(int index) {
    if (!_bannerController.hasClients) return;
    _bannerController.animateToPage(
      index,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOut,
    );
  }

  void _handleHeaderSearch(String raw) {
    FocusScope.of(context).unfocus();
    widget.onSearch(raw.trim());
  }

  _BannerCta? _bannerCtaFor(int index) {
    if (index == 1) {
      return _BannerCta(
        label: 'Buy Pets',
        icon: Icons.shopping_bag_outlined,
        onPressed: () => widget.onGoToTab(1),
      );
    }
    if (index == 2) {
      return _BannerCta(
        label: 'Sell Pets',
        icon: Icons.sell_outlined,
        onPressed: () => widget.onGoToTab(2),
      );
    }
    return null;
  }

  Widget _buildBannerItem(BuildContext context, int index) {
    final data = _banners[index];
    final cta = _bannerCtaFor(index);
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(data.image, fit: BoxFit.cover),
        if (cta != null)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.02),
                    Colors.black.withOpacity(0.24),
                  ],
                ),
              ),
            ),
          ),
        if (cta != null)
          Positioned(
            right: 14,
            bottom: 14,
            child: FilledButton.icon(
              onPressed: cta.onPressed,
              icon: Icon(cta.icon, size: 18),
              label: Text(cta.label),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: Colors.white,
                elevation: 8,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openWishlist() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WishlistScreen()),
    );
  }

  void _openPlan() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen(initialTab: 1)),
    );
  }

  void _handleScroll() {
    final show = _scrollController.hasClients &&
        _scrollController.position.pixels > 120;
    if (show != _showStickyAppBar) {
      setState(() => _showStickyAppBar = show);
    }
  }

  Future<void> _loadPoints() async {
    final status = await PlanStore().loadForUser(Session.currentUser.email);
    if (!mounted) return;
    setState(() {
      _pointsLeft = status.points;
    });
  }

  List<Widget> _buildHeaderActions({
    Color iconColor = Colors.white,
    bool showBackground = false,
    double spacing = 10,
  }) {
    return [
      ValueListenableBuilder<Set<String>>(
        valueListenable: _wishlist.ids,
        builder: (_, ids, __) => _BadgeIconButton(
          icon: Icons.favorite,
          iconColor: iconColor,
          showBackground: showBackground,
          badgeText: ids.isEmpty ? null : '${ids.length}',
          onTap: _openWishlist,
        ),
      ),
      SizedBox(width: spacing),
      _BadgeIconButton(
        icon: Icons.notifications_rounded,
        iconColor: iconColor,
        showBackground: showBackground,
        badgeText:
            widget.notificationCount > 0 ? '${widget.notificationCount}' : null,
        onTap: widget.onOpenNotifications,
      ),
      SizedBox(width: spacing),
      Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CoinButton(
              onTap: _openPlan,
              padding: const EdgeInsets.all(4),
              size: 22,
            ),
            Transform.translate(
              offset: const Offset(0, -1),
              child: Text(
                '${_pointsLeft.clamp(0, 1000000)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
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
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildHeroHeader() {
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 14),
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: PageView.builder(
                controller: _bannerController,
                onPageChanged: _onBannerPageChanged,
                itemCount: _banners.length,
                itemBuilder: (context, index) =>
                    _buildBannerItem(context, index),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(18, 12 + topInset, 18, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      _BadgeIconButton(
                        icon: Icons.menu_rounded,
                        onTap: widget.onOpenMenu,
                        iconColor: Colors.white,
                        showBackground: false,
                      ),
                      const Spacer(),
                      ..._buildHeaderActions(),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _banners.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentBanner == i ? 16 : 8,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(
                              _currentBanner == i ? 0.95 : 0.6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyAppBar(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final scheme = Theme.of(context).colorScheme;

    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: IgnorePointer(
        ignoring: !_showStickyAppBar,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: _showStickyAppBar ? 1 : 0,
          child: Container(
            padding: EdgeInsets.only(top: topInset, left: 12, right: 12),
            height: topInset + 64,
            decoration: BoxDecoration(
              color: scheme.primary,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                _BadgeIconButton(
                  icon: Icons.menu_rounded,
                  onTap: widget.onOpenMenu,
                  iconColor: Colors.white,
                  showBackground: false,
                ),
                const SizedBox(width: 10),
                const Text(
                  'PetsApp',
                  style: TextStyle(
                    color: Color.fromARGB(255, 255, 255, 255),
                    fontSize:22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                ..._buildHeaderActions(
                  iconColor: Colors.white,
                  showBackground: false,
                  spacing: 10,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scrollableContent = SingleChildScrollView(
      controller: _scrollController,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildHeroHeader(),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: TextField(
              controller: _heroSearchCtrl,
              onSubmitted: _handleHeaderSearch,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search pets or breeds nearby',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () => _handleHeaderSearch(_heroSearchCtrl.text),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        if (_isAdminOrOwner)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: _WideAdminTile(
              title: _isOwner ? 'Owner Panel' : 'Admin Panel',
              subtitle: _isOwner
                  ? 'Manage farms, aquariums, pets, and your team'
                  : 'Manage users, pets, and expert requests',
              isOwner: _isOwner,
              users: _adminCountLabel(_adminUsers),
              pets: _adminCountLabel(_adminPets),
              experts: _adminCountLabel(_adminExperts),
              queries: _adminCountLabel(_adminQueries),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminDashboardScreen(
                          initialSection: AdminSection.panel)),
                ).then((_) => _loadAdminStats());
              },
              onUsersTap: () => _openAdminSection(context,
                  _isOwner ? AdminSection.pets : AdminSection.users),
              onPetsTap: () => _openAdminSection(context, AdminSection.pets),
              onExpertsTap: () =>
                  _openAdminSection(context, AdminSection.experts),
              onQueriesTap: () => _openAdminSection(
                  context,
                  _isOwner ? AdminSection.experts : AdminSection.queries),
            ),
          ),

        // ---- Quick actions ----
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _QuickActionTile(
                      title: 'Notifications',
                      iconWidget: const _NotificationBellIcon(),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => NotificationScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickActionTile(
                      title: 'Check Rate',
                      iconWidget: const _CheckRateIcon(),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CheckPriceScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickActionTile(
                      title: 'Care Tips',
                      iconWidget: const _GlowingBulbIcon(),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CareTipsScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickActionTile(
                      title: 'Pet Expert',
                      iconWidget: const _PetExpertIcon(),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PetExpertScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ---- My Pets header ----
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            const Text('My Pets',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const Spacer(),
            TextButton(
                onPressed: _myPets.isEmpty
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  _MyPetsListScreen(entries: _myPets)),
                        ).then((_) => _loadMyPets());
                      },
                child: const Text('View All >')),
          ]),
        ),
        const SizedBox(height: 8),

        // ---- My Pets horizontal cards ----
        SizedBox(
          height: 150,
          child: _loadingPets
              ? const Center(child: CircularProgressIndicator())
              : _myPets.isEmpty
                  ? const Center(
                      child: Text('No pets yet. Start a listing from Sell.'))
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _myPets.length,
                      itemBuilder: (_, i) {
                        final entry = _myPets[i];
                        return _MyPetCard(
                          status: entry.status,
                          cta: entry.cta,
                          title: entry.title,
                          image: entry.image,
                          price: entry.price,
                          location: entry.location,
                          onTap: entry.onTap,
                        );
                      },
                    ),
        ),

        const SizedBox(height: 16),

        _DemandCarousel(),
        const SizedBox(height: 12),

        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: const [
              _LearnCard(
                title: 'How to buy pets from PetsApp?',
                subtitle: 'Search, compare, and connect with verified sellers.',
                icon: Icons.shopping_bag_outlined,
                steps: [
                  'Use search and filters to find the right pet.',
                  'Check photos, videos, price, and location.',
                  'Chat or call the seller to confirm details.',
                  'Visit in person and verify the pet before paying.',
                  'Use WhatsApp to share requirements and fix a meet-up.',
                ],
                tips: [
                  'Always meet in a safe public place.',
                  'Ask for vaccination and medical records.',
                  'Avoid advance payment without verification.',
                ],
              ),
              _LearnCard(
                title: 'Learn the right way to sell pets',
                subtitle: 'Create trust and close faster with complete info.',
                icon: Icons.sell_outlined,
                steps: [
                  'Add clear photos and a short video.',
                  'Mention breed, age, gender, and vaccination status.',
                  'Set a fair price based on local listings.',
                  'Reply quickly to chats and calls.',
                  'Schedule visits and share location details.',
                ],
                tips: [
                  'Use natural lighting for photos.',
                  'Add a short description of temperament.',
                  'Keep your listing updated.',
                ],
              ),
              _LearnCard(
                title: 'How to sell pets in 1 day?',
                subtitle: 'Boost visibility and respond fast.',
                icon: Icons.flash_on_outlined,
                steps: [
                  'Upload 5 to 6 photos with a clean background.',
                  'Write a clear title with breed and age.',
                  'Price competitively for your city.',
                  'Respond within minutes to messages.',
                  'Share your listing with local groups.',
                ],
                tips: [
                  'Post during peak hours (6-10 PM).',
                  'Offer pickup/delivery options if possible.',
                  'Be ready with vet documents.',
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ---- Pet Support Hub header ----
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('Pet Support Hub',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 8),

        // ---- Pet Support Hub list ----
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _ServiceCard(
                'Pet Loan',
                'Loan at Home',
                'assets/icons/loan.png',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PetLoanScreen()),
                  );
                },
              ),
              _ServiceCard(
                'Pet Insurance',
                'Cheap Insurance',
                'assets/icons/insurance.png',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PetInsuranceScreen()),
                  );
                },
              ),
              _ServiceCard(
                'Pet Discussion',
                'Share Knowledge',
                'assets/icons/discussion.png',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PetDiscussionScreen()),
                  );
                },
              ),
              _ServiceCard(
                'Play Game',
                'Win Coins',
                'assets/icons/game.png',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PlayGameScreen()),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ]),
    );

    return Stack(
      children: [
        scrollableContent,
        _buildStickyAppBar(context),
      ],
    );
  }
}

class _MyPetEntry {
  final String status;
  final String cta;
  final String title;
  final VoidCallback onTap;
  final String? image;
  final int? price;
  final String? location;
  final bool isDraft;

  _MyPetEntry(
      {required this.status,
      required this.cta,
      required this.title,
      required this.onTap,
      this.image,
      this.price,
      this.location,
      this.isDraft = false});

  MyPetsScreenEntry toPublic() => MyPetsScreenEntry(
      status: status,
      cta: cta,
      title: title,
      onTap: onTap,
      image: image,
      price: price,
      location: location);
}

class _AdminUserLite {
  final String name;
  final String phone;
  const _AdminUserLite({required this.name, required this.phone});
}

class _MyPetsListScreen extends StatefulWidget {
  final List<_MyPetEntry> entries;
  const _MyPetsListScreen({required this.entries});

  @override
  State<_MyPetsListScreen> createState() => _MyPetsListScreenState();
}

class _MyPetsListScreenState extends State<_MyPetsListScreen> {
  late List<_MyPetEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = List<_MyPetEntry>.from(widget.entries);
  }

  bool _isIncomplete(_MyPetEntry entry) {
    final status = entry.status.toLowerCase();
    final cta = entry.cta.toLowerCase();
    return status.contains('incomplete') || cta.contains('complete');
  }

  bool _isHistory(_MyPetEntry entry) {
    final status = entry.status.toLowerCase();
    return status.contains('sold') ||
        status.contains('history') ||
        status.contains('expired') ||
        status.contains('closed');
  }

  Future<void> _removeEntry(_MyPetEntry entry) async {
    setState(() {
      _entries.remove(entry);
    });
    if (!entry.isDraft) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final snapKey =
          'sell_tab_form_snapshot_${Session.currentUser.email.toLowerCase().replaceAll(' ', '_')}';
      await prefs.remove(snapKey);
    } catch (_) {
      // ignore cache errors
    }
  }

  Widget _buildList(BuildContext context, List<_MyPetEntry> items,
      {required String emptyMessage, bool showIncompleteActions = false}) {
    if (items.isEmpty) {
      return Center(child: Text(emptyMessage));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final entry = items[i];
        final detail =
            _composeDetails(price: entry.price, location: entry.location);
        return Card(
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: PetImage(
              source: entry.image ?? kPetPlaceholderImage,
              width: 56,
              height: 56,
              borderRadius: BorderRadius.circular(10),
            ),
            title: Text(normalizePetTitle(entry.title)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.status),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(detail,
                      style:
                          TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                ],
              ],
            ),
            trailing: showIncompleteActions
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: entry.onTap,
                        child: const Text('Edit'),
                      ),
                      TextButton(
                        onPressed: () => _removeEntry(entry),
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent),
                        child: const Text('Remove'),
                      ),
                    ],
                  )
                : TextButton(
                    onPressed: entry.onTap,
                    child: Text(entry.cta),
                  ),
            onTap: entry.onTap,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final incomplete = _entries.where(_isIncomplete).toList();
    final history = _entries.where(_isHistory).toList();
    final myPets = _entries
        .where((entry) => !_isIncomplete(entry) && !_isHistory(entry))
        .toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Pets'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'My Pets'),
              Tab(text: 'Incomplete'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildList(context, myPets, emptyMessage: 'No pets listed yet.'),
            _buildList(context, incomplete,
                emptyMessage: 'No incomplete listings.',
                showIncompleteActions: true),
            _buildList(context, history, emptyMessage: 'No history yet.'),
          ],
        ),
      ),
    );
  }
}

class MyPetsScreenEntry {
  final String status;
  final String cta;
  final String title;
  final VoidCallback onTap;
  final String? image;
  final int? price;
  final String? location;
  const MyPetsScreenEntry(
      {required this.status,
      required this.cta,
      required this.title,
      required this.onTap,
      this.image,
      this.price,
      this.location});
}

String? _formatPriceCompact(int? price) {
  if (price == null || price <= 0) return null;
  final formatter =
      NumberFormat.compactCurrency(symbol: 'Rs ', decimalDigits: 0);
  return formatter.format(price);
}

String? _composeDetails({int? price, String? location}) {
  final parts = <String>[];
  final priceText = _formatPriceCompact(price);
  if (priceText != null) parts.add('Buy at $priceText');
  final loc = (location ?? '').trim();
  if (loc.isNotEmpty) parts.add(loc);
  if (parts.isEmpty) return null;
  return parts.join(' • ');
}

class _BannerData {
  final String image;
  final String title;
  final String subtitle;
  const _BannerData(
      {required this.image, required this.title, required this.subtitle});
}

class _BannerCta {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _BannerCta(
      {required this.label, required this.icon, required this.onPressed});
}

class _BadgeIconButton extends StatelessWidget {
  final IconData icon;
  final String? badgeText;
  final VoidCallback onTap;
  final Color iconColor;
  final bool showBackground;
  final Color backgroundColor;
  final double iconSize;

  const _BadgeIconButton(
      {required this.icon,
      this.badgeText,
      required this.onTap,
      this.iconColor = Colors.white,
      this.showBackground = true,
      this.backgroundColor = const Color(0x99000000),
      this.iconSize = 22});

  @override
  Widget build(BuildContext context) {
    final baseButton = Material(
      color: showBackground ? backgroundColor : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(showBackground ? 10 : 4),
          child: Icon(
            icon,
            color: iconColor,
            size: iconSize,
          ),
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (showBackground)
          Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: baseButton,
          )
        else
          baseButton,
        if (badgeText != null)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orangeAccent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                badgeText!,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}

class _CoinButton extends StatelessWidget {
  final VoidCallback onTap;
  final EdgeInsets padding;
  final double size;
  const _CoinButton({
    required this.onTap,
    this.padding = const EdgeInsets.all(4),
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Image.asset(
            'assets/icons/coin.png',
            width: size,
            height: size,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

/* ====== Quick actions & misc cards ====== */
class _QuickActionTile extends StatelessWidget {
  final String title;
  final String? _iconAsset;
  final Widget? iconWidget;
  final VoidCallback? onTap;

  const _QuickActionTile({
    required this.title,
    String? icon,
    String? iconAsset,
    this.iconWidget,
    this.onTap,
  })  : _iconAsset = iconAsset ?? icon,
        assert(
          iconAsset != null || icon != null || iconWidget != null,
          'Provide either an icon asset or a custom icon widget.',
        );

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: 74,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                iconWidget ??
                    ImageIcon(
                      AssetImage(_iconAsset!),
                      size: 22,
                      color: Colors.black87,
                    ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WideAdminTile extends StatelessWidget {
  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final bool isOwner;
  final String users;
  final String pets;
  final String experts;
  final String queries;
  final VoidCallback onUsersTap;
  final VoidCallback onPetsTap;
  final VoidCallback onExpertsTap;
  final VoidCallback onQueriesTap;

  const _WideAdminTile({
    required this.onTap,
    required this.title,
    required this.subtitle,
    required this.isOwner,
    required this.users,
    required this.pets,
    required this.experts,
    required this.queries,
    required this.onUsersTap,
    required this.onPetsTap,
    required this.onExpertsTap,
    required this.onQueriesTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: primary.withOpacity(0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          height: 120,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.dashboard_customize, color: primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(subtitle,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: primary),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _statChip(isOwner ? 'Farm' : 'Users', users, onUsersTap),
                    const SizedBox(width: 8),
                    _statChip(isOwner ? 'Orders' : 'Pets', pets, onPetsTap),
                    const SizedBox(width: 8),
                    _statChip(isOwner ? 'Expense Trackers' : 'Experts', experts,
                        onExpertsTap),
                    const SizedBox(width: 8),
                    _statChip(isOwner ? 'Transport' : 'Queries', queries,
                        onQueriesTap),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statChip(String label, String value, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(fontSize: 10, color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowingBulbIcon extends StatelessWidget {
  const _GlowingBulbIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4C1), Color(0xFFFFC94C), Color(0xFFFFA726)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFC94C).withOpacity(0.6),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.lightbulb, color: Color(0xFF744400), size: 22),
    );
  }
}

class _NotificationBellIcon extends StatelessWidget {
  const _NotificationBellIcon();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF0EA49D), Color(0xFF4ED4C7)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0EA49D).withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.notifications, color: Colors.white, size: 20),
        ),
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.orangeAccent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _CheckRateIcon extends StatelessWidget {
  const _CheckRateIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF5B8DEF), Color(0xFF36C2FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B8DEF).withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.rate_review, color: Colors.white, size: 20),
    );
  }
}

class _PetExpertIcon extends StatelessWidget {
  const _PetExpertIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFFA8A8), Color(0xFFFF7C5F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7C5F).withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.support_agent, color: Colors.white, size: 20),
    );
  }
}

class _MyPetCard extends StatelessWidget {
  final String status;
  final String cta;
  final String? title;
  final String? image;
  final int? price;
  final String? location;
  final VoidCallback? onTap;
  const _MyPetCard(
      {required this.status,
      required this.cta,
      this.title,
      this.image,
      this.price,
      this.location,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final detail = _composeDetails(price: price, location: location);
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 240,
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _PetThumb(image: image),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child:
                            Text(status, style: const TextStyle(fontSize: 11)),
                      ),
                      if (title != null && title!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(title!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                      if (detail != null) ...[
                        const SizedBox(height: 4),
                        Text(detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.grey.shade700, fontSize: 12)),
                      ],
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
                          onPressed: onTap,
                          style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10)),
                          child: Text(cta,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PetThumb extends StatelessWidget {
  final String? image;
  const _PetThumb({this.image});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: PetImage(
        source: image ?? kPetPlaceholderImage,
        width: 72,
        height: 72,
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String icon;
  final VoidCallback? onTap;
  const _ServiceCard(this.title, this.subtitle, this.icon, {this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 220,
            child: ListTile(
              leading: ImageIcon(AssetImage(icon),
                  color: Theme.of(context).colorScheme.primary, size: 28),
              title: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(subtitle),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        ),
      );
}

/* ====== Demand carousel, info, learn ====== */
class _DemandCarousel extends StatefulWidget {
  @override
  State<_DemandCarousel> createState() => _DemandCarouselState();
}

class _DemandCarouselState extends State<_DemandCarousel> {
  int _index = 0;

  static const _cards = [
    _DemandCardData(
        price: '\u20B95,000 - \u20B925,000',
        location: 'BENGALURU URBAN, Karnataka',
        category: PetCategory.animals),
    _DemandCardData(
        price: '\u20B910,000 - \u20B930,000',
        location: 'MYSURU, Karnataka',
        category: PetCategory.birds),
    _DemandCardData(
        price: '\u20B98,000 - \u20B922,000',
        location: 'HUBLI, Karnataka',
        category: PetCategory.fish),
  ];

  List<PetCatalogItem> get _catalog =>
      PetCatalog.all.isNotEmpty ? PetCatalog.all : PET_CATALOG;

  List<_DemandCard> _buildCards() {
    final catalog = _catalog;
    return _cards
        .map((data) => _DemandCard(
              title: _titleForCategory(data.category),
              price: data.price,
              loc: data.location,
              thumbs: _demandThumbsFor(data.location, data.category, catalog),
            ))
        .toList();
  }

  List<_DemandThumbData> _demandThumbsFor(
      String location, PetCategory category, List<PetCatalogItem> catalog) {
    final nearby =
        catalog.where((item) => _isNearby(item.location, location)).toList();
    final used = <String>{};
    final thumbs = <_DemandThumbData>[];

    void addMatches(
        List<PetCatalogItem> source, bool Function(PetCatalogItem) matches) {
      for (final item in source) {
        if (thumbs.length >= 4) return;
        if (!matches(item)) continue;
        final key = normalizePetTitle(item.title);
        if (used.contains(key)) continue;
        used.add(key);
        thumbs.add(_DemandThumbData(image: item.primaryImage, item: item));
      }
    }

    addMatches(nearby, (item) => item.category == category);
    addMatches(catalog, (item) => item.category == category);

    while (thumbs.length < 4) {
      thumbs.add(const _DemandThumbData(image: kPetPlaceholderImage));
    }
    return thumbs;
  }

  bool _isNearby(String itemLocation, String target) {
    final item = _normalizeLocation(itemLocation);
    final wanted = _normalizeLocation(target);
    return item.isNotEmpty && (item.contains(wanted) || wanted.contains(item));
  }

  String _normalizeLocation(String value) {
    final base = value.split(',').first.toLowerCase();
    return base.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  String _titleForCategory(PetCategory category) {
    switch (category) {
      case PetCategory.animals:
        return 'Top Animals in near your area';
      case PetCategory.birds:
        return 'Top Birds in near your area';
      case PetCategory.fish:
        return 'Top Fish in near your area';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = _buildCards();
    return Column(children: [
      SizedBox(
        height: 150,
        child: PageView.builder(
          itemCount: cards.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => cards[i],
        ),
      ),
      const SizedBox(height: 6),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          cards.length,
          (i) => Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i == _index
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    ]);
  }
}

class _DemandCardData {
  final String price;
  final String location;
  final PetCategory category;
  const _DemandCardData(
      {required this.price, required this.location, required this.category});
}

class _DemandThumbData {
  final String image;
  final PetCatalogItem? item;
  const _DemandThumbData({required this.image, this.item});
}

class _DemandCard extends StatelessWidget {
  final String title;
  final String price;
  final String loc;
  final List<_DemandThumbData> thumbs;
  const _DemandCard(
      {required this.title,
      required this.price,
      required this.loc,
      required this.thumbs});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.whatshot, color: Colors.orange),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                4,
                (index) => _DemandThumb(
                  data: index < thumbs.length
                      ? thumbs[index]
                      : const _DemandThumbData(image: kPetPlaceholderImage),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(price, style: const TextStyle(fontWeight: FontWeight.bold)),
            Row(children: [
              const Icon(Icons.location_on, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text(loc,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          ]),
        ),
      );
}

class _DemandThumb extends StatelessWidget {
  final _DemandThumbData data;
  const _DemandThumb({required this.data});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: data.item == null ? null : () => _openDetails(context),
          child: PetImage(
            source: data.image,
            width: 52,
            height: 52,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  void _openDetails(BuildContext context) {
    final item = data.item;
    if (item == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PetDetailsScreen(item: item.toItem())),
    );
  }
}

class _LearnCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> steps;
  final List<String> tips;
  final IconData icon;

  const _LearnCard({
    required this.title,
    required this.subtitle,
    required this.steps,
    required this.tips,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        borderRadius: radius,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LearnGuideScreen(
                title: title,
                subtitle: subtitle,
                steps: steps,
                tips: tips,
              ),
            ),
          );
        },
        child: Container(
          width: 230,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1FBFA9), Color(0xFF0D8B84)],
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    height: 1.3),
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Text('View guide',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11)),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
