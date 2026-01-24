import 'dart:math' as math;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/call_stats_store.dart';
import '../models/message_stats_store.dart';
import '../models/notification_store.dart';
import '../models/pet_catalog.dart';
import '../models/pet_data.dart';
import '../models/pet_utils.dart';
import '../models/session.dart';
import '../models/plan_store.dart';
import '../models/user_profile.dart';
import '../models/user_profile_store.dart';
import '../models/wishlist.dart';
import '../views/notifications_screen.dart';
import '../views/pet_details.dart';
import '../views/location_picker_screen.dart';
import '../views/wishlist_screen.dart';
import '../widgets/pet_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _PointsRange { day, week, month, year }

class ProfileScreen extends StatefulWidget {
  final int initialTab;
  const ProfileScreen({super.key, this.initialTab = 0});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile _profile = Session.currentUser;
  final WishlistStore _wishlist = WishlistStore();
  final TextEditingController _idCtrl = TextEditingController();
  _PointsRange _pointsRange = _PointsRange.day;
  late final VoidCallback _planListener;
  late final VoidCallback _callStatsListener;
  late final VoidCallback _messageStatsListener;
  PlanStatus? _planStatus;
  bool _loadingPlan = true;
  bool _showCalls = true;
  bool _showMessages = true;
  bool _showPets = true;
  bool _showWhatsApp = true;
  int _callsMade = 0;
  int _callsReceived = 0;
  int _messagesSent = 0;
  int _messagesReceived = 0;
  bool _loadingStats = true;
  int _availablePoints = 0;
  int _spentPoints = 0;

  @override
  void initState() {
    super.initState();
    _planListener = () {
      _refreshPlanUsage();
    };
    PlanStore.pointsVersion.addListener(_planListener);
    _callStatsListener = () => _loadStats();
    _messageStatsListener = () => _loadStats();
    CallStatsStore.version.addListener(_callStatsListener);
    MessageStatsStore.version.addListener(_messageStatsListener);
    _loadProfileAndStats();
  }

  Future<void> _loadProfileAndStats() async {
    final store = UserProfileStore();
    final merged = await store.load(_profile);
    if (!mounted) return;
    setState(() {
      _profile = merged;
    });
    await Session.setUser(merged);
    await _loadProfileId();
    await Future.wait([_loadStats(), _loadPlanPoints()]);
  }

  Future<void> _loadProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _idPrefsKey(_profile.email);
    final existing = prefs.getString(key);
    final id = existing ?? _generateProfileId();
    if (existing == null) {
      await prefs.setString(key, id);
    }
    if (!mounted) return;
    setState(() {
      _idCtrl.text = id;
    });
  }

  Future<void> _loadStats() async {
    final email = _profile.email;
    final callsMade = await CallStatsStore().loadCallsMade(email);
    final callsReceived = (await NotificationStore().loadForUser(email)).length;
    final messageStore = MessageStatsStore();
    final messagesSent = await messageStore.loadSent(email);
    final messagesReceived = await messageStore.loadReceived(email);
    if (!mounted) return;
    setState(() {
      _callsMade = callsMade;
      _callsReceived = callsReceived;
      _messagesSent = messagesSent;
      _messagesReceived = messagesReceived;
      _loadingStats = false;
    });
  }

  Future<void> _loadPlanPoints() async {
    final store = PlanStore();
    final status = await store.loadForUser(_profile.email);
    final spent = await store.loadSpent(_profile.email);
    if (!mounted) return;
    setState(() {
      _availablePoints = status.points;
      _spentPoints = spent;
      _planStatus = status;
      _loadingPlan = false;
    });
  }

  Future<void> _refreshPlanUsage() async {
    await Future.wait([_loadStats(), _loadPlanPoints()]);
  }

  String _idPrefsKey(String email) =>
      'profile_id_${email.toLowerCase().replaceAll(' ', '_')}';

  String _generateProfileId() {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final rand = math.Random();
    final a = letters[rand.nextInt(letters.length)];
    final b = letters[rand.nextInt(letters.length)];
    final digits = rand.nextInt(10000).toString().padLeft(4, '0');
    return '$a$b$digits';
  }

  Future<void> _saveProfileIdIfValid(String value) async {
    final id = value.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{2}[0-9]{4}$').hasMatch(id)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_idPrefsKey(_profile.email), id);
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<LocationSelectionResult?>(
      context,
      LocationPickerScreen.route(),
    );
    if (result == null) return;
    final city = (result.city ?? result.formattedAddress).trim();
    if (city.isEmpty) return;
    final updated = _profile.copyWith(city: city);
    setState(() {
      _profile = updated;
    });
    await UserProfileStore().save(updated);
    await Session.setUser(updated);
  }

  @override
  void dispose() {
    PlanStore.pointsVersion.removeListener(_planListener);
    CallStatsStore.version.removeListener(_callStatsListener);
    MessageStatsStore.version.removeListener(_messageStatsListener);
    _idCtrl.dispose();
    super.dispose();
  }

  List<PetCatalogItem> _ownedPets() {
    final phoneDigits = _profile.phone.replaceAll(RegExp(r'[^0-9]'), '');
    final matches = PetCatalog.all.where((pet) {
      final nameMatch =
          pet.sellerName.toLowerCase() == _profile.name.toLowerCase();
      final sellerDigits = pet.phone.replaceAll(RegExp(r'[^0-9]'), '');
      final phoneMatch = phoneDigits.isNotEmpty && sellerDigits == phoneDigits;
      return nameMatch || phoneMatch;
    }).toList(growable: false);

    return matches;
  }

  DateTime? _parseMemberSince(String text) {
    final match = RegExp(r'(\d{4})').firstMatch(text);
    if (match != null) {
      final year = int.tryParse(match.group(1) ?? '');
      if (year != null) return DateTime(year, 1, 1);
    }
    return DateTime.tryParse(text);
  }

  String _journeyText() {
    final start = _parseMemberSince(_profile.memberSince) ?? DateTime.now();
    final now = DateTime.now();
    if (start.isAfter(now)) return 'Journey starts soon on Pets';
    final months = (now.year - start.year) * 12 + (now.month - start.month);
    final anchor = DateTime(start.year, start.month + months, start.day);
    final days = now.difference(anchor).inDays;
    final monthText = months == 1 ? '1 month' : '$months months';
    final dayText = days == 1 ? '1 day' : '$days days';
    return 'Journey of $monthText $dayText on Pets';
  }

  String _countLabel(int value) => _loadingStats ? '-' : '$value';

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label coming soon')),
    );
  }

  void _openOwnedPets(List<PetCatalogItem> pets) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => _OwnedPetsScreen(pets: pets, title: 'My Pets')),
    );
  }

  void _openPurchasedPets(List<PetCatalogItem> pets) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              _OwnedPetsScreen(pets: pets, title: 'Purchased Pets')),
    );
  }

  List<PetCatalogItem> _purchasedPets() {
    // Mirror the admin "buy" list so it stays consistent.
    final pets = PetCatalog.all.isNotEmpty ? PetCatalog.all : PET_CATALOG;
    if (pets.isEmpty) return const [];

    final ownedKeys = _ownedPets()
        .map((p) => normalizePetTitle(p.title).toLowerCase())
        .toSet();

    int seedForName(String name) {
      final lower = name.toLowerCase();
      if (lower.contains('asha')) return 0;
      if (lower.contains('ravi')) return 1;
      if (lower.contains('divya')) return 2;
      if (lower.contains('kiran')) return 3;
      if (lower.contains('sana')) return 4;
      if (lower.contains('mo ji')) return 5;
      return 6;
    }

    final seed = seedForName(_profile.name);
    final maxCount = math.min(5, pets.length);
    final List<PetCatalogItem> purchased = [];
    var idx = seed % pets.length;

    while (purchased.length < maxCount) {
      final pet = pets[idx];
      final key = normalizePetTitle(pet.title).toLowerCase();
      if (!ownedKeys.contains(key)) {
        purchased.add(pet);
      }
      idx = (idx + 1) % pets.length;
      if (purchased.length < maxCount && idx == seed % pets.length) break;
    }

    // Fallback to owned if everything filtered out
    if (purchased.isEmpty) {
      purchased.addAll(_ownedPets());
    }
    return purchased;
  }

  @override
  Widget build(BuildContext context) {
    final pets = _ownedPets();
    final purchased = _purchasedPets();
    final journey = _journeyText();
    final initialTab =
        widget.initialTab.clamp(0, 3); // 4 tabs: Profile, Plan, Sell, Buy

    final primary = Theme.of(context).colorScheme.primary;

    return DefaultTabController(
      length: 4,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(title: const Text('My Profile')),
        body: Column(
          children: [
            _tabSwitcher(primary),
            Expanded(
              child: TabBarView(
                children: [
                  _profileTab(journey, pets),
                  _planTab(pets.length),
                  _sellingTab(pets),
                  _buyingTab(purchased),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabSwitcher(Color primary) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.center,
        labelColor: primary,
        unselectedLabelColor: Colors.black54,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        labelPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(width: 3, color: primary),
          insets: const EdgeInsets.only(left: 6, right: 6, bottom: 4),
        ),
        indicatorSize: TabBarIndicatorSize.label,
        overlayColor: MaterialStateProperty.all(Colors.transparent),
        tabs: const [
          Tab(text: 'Profile'),
          Tab(text: 'Plan'),
          Tab(text: 'Sell'),
          Tab(text: 'Buy'),
        ],
      ),
    );
  }

  Widget _profileTab(String journey, List<PetCatalogItem> pets) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _profileCard(),
        const SizedBox(height: 12),
        Text(
          journey,
          style: const TextStyle(
              fontWeight: FontWeight.w600, color: Color(0xFF4F6D68)),
        ),
        const SizedBox(height: 12),
        _statsGrid([
          _statCard(
            icon: Icons.pets,
            label: 'Pets Listed',
            value: '${pets.length}',
          ),
          _statCard(
            icon: Icons.call_made,
            label: 'Calls Made',
            value: _countLabel(_callsMade),
          ),
          _statCard(
            icon: Icons.call_received,
            label: 'Calls Received',
            value: _countLabel(_callsReceived),
          ),
          _statCard(
            icon: Icons.chat_outlined,
            label: 'Messages Sent',
            value: _countLabel(_messagesSent),
          ),
          _statCard(
            icon: Icons.chat_bubble_outline,
            label: 'Messages Received',
            value: _countLabel(_messagesReceived),
          ),
        ]),
      ],
    );
  }

  Widget _planTab(int petsCount) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _loadingPlan
            ? const Center(child: CircularProgressIndicator())
            : _planSection(petsCount),
        const SizedBox(height: 16),
        _pointsUsedCard(petsCount),
      ],
    );
  }

  Widget _sellingTab(List<PetCatalogItem> pets) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Sell'),
        _sectionCard(
          [
            _menuTile(
              icon: Icons.pets,
              title: 'Pets (${pets.length})',
              onTap: () => _openOwnedPets(pets),
            ),
            _menuTile(
              icon: Icons.call_received,
              title: 'Calls Received (${_countLabel(_callsReceived)})',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationScreen()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buyingTab(List<PetCatalogItem> purchased) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Buy'),
        _sectionCard(
          [
            _menuTile(
              icon: Icons.pets,
              title: 'Pets (${purchased.length})',
              onTap: () => _openPurchasedPets(purchased),
            ),
            _menuTile(
              icon: Icons.call_made,
              title: 'Calls Made (${_countLabel(_callsMade)})',
              onTap: () => _showComingSoon('Calls Made'),
            ),
            ValueListenableBuilder<Set<String>>(
              valueListenable: _wishlist.ids,
              builder: (context, ids, _) {
                return _menuTile(
                  icon: Icons.favorite_border,
                  title: 'Wishlist (${ids.length})',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WishlistScreen()),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _profileCard() {
    final primary = Theme.of(context).colorScheme.primary;
    final isVerified = _profile.isVerified;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE1F4F0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: primary.withOpacity(0.2)),
                      ),
                      child: Icon(Icons.person, size: 28, color: primary),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Text('ID:',
                            style:
                                TextStyle(fontSize: 12, color: Colors.black54)),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 70,
                          child: TextField(
                            controller: _idCtrl,
                            maxLength: 6,
                            onChanged: _saveProfileIdIfValid,
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp('[A-Za-z0-9]')),
                              _UpperCaseTextFormatter(),
                            ],
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black87),
                            decoration: const InputDecoration(
                              isDense: true,
                              counterText: '',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  if (isVerified)
                      _verifiedChip(label: 'Verified', color: primary)
                    else
                      _verifiedChip(
                          label: 'Not verified', color: Colors.orange),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(_profile.name,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                          _profile.city.isEmpty ? 'Unknown' : _profile.city,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Change location',
                        onPressed: _pickLocation,
                        icon: const Icon(Icons.location_on, size: 18),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                      const SizedBox(height: 4),
                      Text(_profile.email,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                      const SizedBox(height: 2),
                      Text(_profile.phone,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _verifiedChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _statsGrid(List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final width = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children:
              cards.map((card) => SizedBox(width: width, child: card)).toList(),
        );
      },
    );
  }

  Widget _statCard(
      {required IconData icon, required String label, required String value}) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Color(0xFF2E766C)),
          ),
        ],
      ),
    );
  }

  Widget _pointsUsedCard(int petsCount) {
    final totalCalls = _callsMade + _callsReceived;
    final callPts = totalCalls * PlanStore.callCost;
    final msgPts = (_messagesSent + _messagesReceived) * PlanStore.chatCost;
    final listPts = petsCount * PlanStore.addPetCost;
    final chartUsed = callPts + msgPts + listPts;
    final pointsLeft = _availablePoints.clamp(0, 1000000);

  final xLabels = _xLabelsForRange(_pointsRange);
    final primary = Theme.of(context).colorScheme.primary;
    final series = _seriesFromPoints(
      callPts,
      msgPts,
      listPts,
      (_messagesSent + _messagesReceived) * PlanStore.whatsappCost,
      _pointsRange,
      xLabels.length,
      primary: primary,
      showCalls: _showCalls,
      showMessages: _showMessages,
      showPets: _showPets,
      showWhatsApp: _showWhatsApp,
    );

    return Card(
      elevation: 0,
      color: const Color(0xFFF4F9F8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Points used',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 10),
            _metricSelector(),
            const SizedBox(height: 8),
            SizedBox(
              height: 190,
              width: double.infinity,
              child: _PointsAreaGraph(
                series: series,
                xLabels: xLabels,
              ),
            ),
            const SizedBox(height: 8),
            _graphLegend(series),
            const SizedBox(height: 12),
            _summaryRow('Total used', '${_spentPoints} pts',
                primary: primary),
            _summaryRow('Points left', '$pointsLeft pts',
                primary: primary, emphasize: true),
            const SizedBox(height: 6),
            _summaryRow('Chart est. used', '$chartUsed pts',
                primary: primary),
          ],
        ),
      ),
    );
  }

  Widget _metricSelector() {
    final callsColor = Theme.of(context).colorScheme.primary;
    const messagesColor = Color(0xFF6175F8);
    const petsColor = Color(0xFFF4A261);
    const waColor = Color(0xFF2A9DF4);

    Widget checkbox({
      required bool selected,
      required IconData icon,
      required Color activeColor,
      required VoidCallback onTap,
    }) {
      final borderColor = selected ? activeColor : Colors.grey.shade400;
      final fillColor =
          selected ? activeColor.withOpacity(0.12) : Colors.transparent;
      final iconColor = selected ? activeColor : Colors.black54;

      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: borderColor, width: 1.6),
                ),
                child: selected
                    ? Icon(Icons.check, size: 16, color: activeColor)
                    : null,
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 18, color: iconColor),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 18,
      runSpacing: 6,
      children: [
        checkbox(
          selected: _showCalls,
          icon: Icons.call_made,
          activeColor: callsColor,
          onTap: () => setState(() => _showCalls = !_showCalls),
        ),
        checkbox(
          selected: _showMessages,
          icon: Icons.chat_bubble_outline,
          activeColor: messagesColor,
          onTap: () => setState(() => _showMessages = !_showMessages),
        ),
        checkbox(
          selected: _showPets,
          icon: Icons.pets,
          activeColor: petsColor,
          onTap: () => setState(() => _showPets = !_showPets),
        ),
        checkbox(
          selected: _showWhatsApp,
          icon: Icons.chat,
          activeColor: waColor,
          onTap: () => setState(() => _showWhatsApp = !_showWhatsApp),
        ),
      ],
    );
  }

  List<String> _xLabelsForRange(_PointsRange range) {
    switch (range) {
      case _PointsRange.day:
        return ['0h', '4h', '8h', '12h', '16h', '20h'];
      case _PointsRange.week:
        return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      case _PointsRange.month:
        return ['W1', 'W2', 'W3', 'W4'];
      case _PointsRange.year:
        return ['Q1', 'Q2', 'Q3', 'Q4'];
    }
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3B5C57))),
      );

  Widget _sectionCard(List<Widget> tiles) {
    final items = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      items.add(tiles[i]);
      if (i != tiles.length - 1) {
        items.add(const Divider(height: 1));
      }
    }
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(children: items),
    );
  }

  Widget _menuTile(
      {required IconData icon,
      required String title,
      VoidCallback? onTap,
      bool highlight = false}) {
    final primary = Theme.of(context).colorScheme.primary;
    final bg = highlight ? const Color(0xFFE4F4F1) : Colors.transparent;
    final borderColor =
        highlight ? primary.withOpacity(0.25) : Colors.grey.shade300;
    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: highlight ? Colors.white : primary.withOpacity(0.08),
        child: Icon(icon, size: 18, color: primary),
      ),
      title: Text(title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right, size: 18),
      tileColor: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      onTap: onTap,
    );
  }

  Widget _planSection(int petsCount) {
    final status = _planStatus;
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _planCurrentCard(status, petsCount),
        const SizedBox(height: 16),
        const Text('Plans',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        for (final plan in PlanStore.plans) ...[
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              title: Text(plan.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                '${plan.points} points • ${plan.durationDays} days',
              ),
              trailing: _pricePill(plan.priceLabel),
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 16),
        const Text('Point usage',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _usageRow('Call', PlanStore.costFor(PlanAction.call), primary),
        _usageRow('Chat', PlanStore.costFor(PlanAction.chat), primary),
        _usageRow(
            'WhatsApp', PlanStore.costFor(PlanAction.whatsapp), primary),
        _usageRow(
            'Add pet (after 5)', PlanStore.costFor(PlanAction.addPet), primary),
      ],
    );
  }

  Widget _planCurrentCard(PlanStatus? status, int petsCount) {
    final totalUsed = _spentPoints;
    final pointsLeft = _availablePoints.clamp(0, 1000000);
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Current plan',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    status?.planName ?? 'Welcome Bonus',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    status?.expiresAt == null
                        ? 'No expiry'
                        : 'Valid until ${DateFormat('dd MMM yyyy').format(status!.expiresAt!)}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _planPill(
                          label: 'Points',
                          value:
                              '${status?.points ?? PlanStore.welcomePoints}'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _planStat(label: 'Total used', value: '$totalUsed pts'),
                const SizedBox(height: 8),
                _planStat(
                  label: 'Points left',
                  value: '$pointsLeft pts',
                  valueColor: primary,
                  emphasize: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pricePill(String label) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700)),
    );
  }

  Widget _usageRow(String label, int cost, Color primary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text('$cost pts',
              style:
                  TextStyle(fontWeight: FontWeight.w600, color: primary)),
        ],
      ),
    );
  }

  Widget _planPill({required String label, required String value}) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ',
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Text(value,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _planStat(
      {required String label,
      required String value,
      Color? valueColor,
      bool emphasize = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700,
                color: valueColor ?? Colors.black87)),
      ],
    );
  }
}

class _GraphSeries {
  final String label;
  final List<double> data;
  final Color color;
  final Color? fillColor;
  final int points;
  final bool filled;
  const _GraphSeries({
    required this.label,
    required this.data,
    required this.color,
    this.fillColor,
    this.points = 0,
    this.filled = false,
  });
}

List<_GraphSeries> _seriesFromPoints(
  int calls,
  int msgs,
  int listings,
  int whatsapp,
  _PointsRange range,
  int length, {
  required Color primary,
  required bool showCalls,
  required bool showMessages,
  required bool showPets,
  required bool showWhatsApp,
}) {
  double wave(double base, double factor, int i) =>
      (base * (0.6 + math.sin(i * 0.8) * 0.15) + factor * i)
          .clamp(0, double.infinity);

  List<double> buildWave(int seed, int points, double taper, int length) {
    final list = <double>[];
    for (var i = 0; i < length; i++) {
      list.add(wave(points.toDouble(), seed * 0.4, i) * (0.8 + taper));
    }
    return list;
  }

  final len = length.clamp(2, 24);

  final callsWave = buildWave(1, calls, 0.1, len);
  final msgsWave = buildWave(2, msgs, 0.0, len);
  final listWave = buildWave(3, listings, -0.05, len);
  final waWave = buildWave(4, whatsapp, 0.02, len);

  final result = <_GraphSeries>[];
  if (showCalls) {
    result.add(_GraphSeries(
      label: 'Calls',
      data: callsWave,
      color: primary,
      fillColor: primary,
      points: calls,
      filled: true,
    ));
  }
  if (showMessages) {
    result.add(_GraphSeries(
      label: 'Messages',
      data: msgsWave,
      color: const Color(0xFF6175F8),
      points: msgs,
      filled: false,
    ));
  }
  if (showPets) {
    result.add(_GraphSeries(
      label: 'Pets listed',
      data: listWave,
      color: const Color(0xFFF4A261),
      points: listings,
      filled: false,
    ));
  }
  if (showWhatsApp) {
    result.add(_GraphSeries(
      label: 'WhatsApp',
      data: waWave,
      color: const Color(0xFF2A9DF4),
      points: whatsapp,
      filled: false,
    ));
  }

  return result;
}

class _PointsAreaGraph extends StatelessWidget {
  final List<_GraphSeries> series;
  final List<String> xLabels;
  const _PointsAreaGraph({required this.series, required this.xLabels});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          painter: _AreaGraphPainter(series: series, xLabels: xLabels),
          size: Size(constraints.maxWidth, constraints.maxHeight),
        );
      },
    );
  }
}

class _AreaGraphPainter extends CustomPainter {
  final List<_GraphSeries> series;
  final List<String> xLabels;
  _AreaGraphPainter({required this.series, required this.xLabels});

  @override
  void paint(Canvas canvas, Size size) {
    final allValues = series.expand((s) => s.data);
    final maxVal = allValues.fold<double>(0, (m, v) => math.max(m, v));
    if (maxVal <= 0) return;

    const axisPadding = 34.0;
    const sidePadding = 34.0;
    const bottomPadding = 16.0;
    final chartHeight = size.height - bottomPadding;
    final chartWidth = size.width - axisPadding - sidePadding;
    if (chartWidth <= 0 || chartHeight <= 0) return;

    double yFor(double v) {
      final norm = v / maxVal;
      return chartHeight - (norm * (chartHeight * 0.85)) - chartHeight * 0.05;
    }

    // Grid + Y labels
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1;
    const gridCount = 4;
    final textStyle = const TextStyle(
        color: Colors.black54, fontSize: 10, fontWeight: FontWeight.w500);
    final tp = TextPainter(textDirection: ui.TextDirection.ltr);
    for (var i = 0; i <= gridCount; i++) {
      final ratio = i / gridCount;
      final y = yFor(maxVal * ratio);
      canvas.drawLine(Offset(axisPadding, y),
          Offset(size.width - sidePadding, y), gridPaint);
      final labelVal = (maxVal * ratio).round();
      tp.text = TextSpan(text: '$labelVal', style: textStyle);
      tp.layout();
      tp.paint(canvas, Offset(axisPadding - tp.width - 6, y - tp.height / 2));
    }

    void drawSeries(_GraphSeries s) {
      final data = s.data;
      final step =
          data.length == 1 ? chartWidth : chartWidth / (data.length - 1);

      if (s.filled && s.fillColor != null) {
        final path = Path()..moveTo(axisPadding, chartHeight);
        for (var i = 0; i < data.length; i++) {
          final x = axisPadding + step * i;
          final y = yFor(data[i]);
          path.lineTo(x, y);
        }
        path.lineTo(axisPadding + chartWidth, chartHeight);
        path.close();
        final paint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              s.fillColor!.withOpacity(0.25),
              s.fillColor!.withOpacity(0.03),
            ],
          ).createShader(Rect.fromLTWH(0, 0, chartWidth, chartHeight));
        canvas.drawPath(path, paint);
      }

      final stroke = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      final linePath = Path();
      for (var i = 0; i < data.length; i++) {
        final x = axisPadding + step * i;
        final y = yFor(data[i]);
        if (i == 0) {
          linePath.moveTo(x, y);
        } else {
          linePath.lineTo(x, y);
        }
      }
      canvas.drawPath(linePath, stroke);

      final dotPaint = Paint()
        ..color = s.color
        ..style = PaintingStyle.fill;
      for (var i = 0; i < data.length; i++) {
        final x = axisPadding + step * i;
        final y = yFor(data[i]);
        canvas.drawCircle(Offset(x, y), 3, dotPaint);
      }
    }

    // Draw non-filled series first, then filled on top for visibility.
    for (final s in series.where((s) => !s.filled)) {
      drawSeries(s);
    }
    for (final s in series.where((s) => s.filled)) {
      drawSeries(s);
    }

    // X-axis labels
    final labels = xLabels.isEmpty ? [''] : xLabels;
    for (var i = 0; i < labels.length; i++) {
      final x = axisPadding +
          chartWidth * (labels.length == 1 ? 0 : i / (labels.length - 1));
      tp.text = TextSpan(text: labels[i], style: textStyle);
      tp.layout();
      tp.paint(
        canvas,
        Offset(x - tp.width / 2, chartHeight + 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AreaGraphPainter oldDelegate) {
    return oldDelegate.series != series;
  }
}

Widget _graphLegend(List<_GraphSeries> series) {
  return Wrap(
    spacing: 12,
    runSpacing: 6,
    children: series
        .map(
          (s) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: s.color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${s.label}: ${s.points} pts',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
              ),
            ],
          ),
        )
        .toList(),
  );
}

Widget _summaryRow(String label, String value,
    {required Color primary, bool emphasize = false}) {
  final style = TextStyle(
      fontSize: emphasize ? 14 : 13,
      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
      color: emphasize ? primary : Colors.black87);
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    ),
  );
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class _OwnedPetsScreen extends StatelessWidget {
  final List<PetCatalogItem> pets;
  final String title;
  const _OwnedPetsScreen({required this.pets, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: pets.isEmpty
          ? const Center(child: Text('No pets listed yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: pets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final pet = pets[i];
                return Card(
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    leading: PetImage(
                      source: pet.primaryImage,
                      width: 56,
                      height: 56,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    title: Text(normalizePetTitle(pet.title)),
                    subtitle: Text(pet.location),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                PetDetailsScreen(item: pet.toItem())),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
