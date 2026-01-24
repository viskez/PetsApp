import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/call_stats_store.dart';
import '../models/message_stats_store.dart';
import '../models/notification_store.dart';
import '../models/pet_catalog.dart';
import '../models/pet_data.dart';
import '../models/pet_utils.dart';
import '../models/session.dart';
import '../models/user_profile.dart';
import '../models/user_profile_store.dart';
import '../models/wishlist.dart';
import '../models/plan_store.dart';
import '../app_shell.dart';
import 'pet_details.dart';
import 'owner_orders_screen.dart';
import 'owner_expense_screen.dart';
import '../tabs/sell_tab.dart';
import '../widgets/pet_image.dart';

enum AdminSection { panel, users, pets, experts, queries }

class AdminDashboardScreen extends StatefulWidget {
  final AdminSection initialSection;
  const AdminDashboardScreen(
      {super.key, this.initialSection = AdminSection.panel});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late List<AdminUser> _users;
  late List<AdminUserArchive> _userHistory;
  late List<PetCatalogItem> _pets;
  late List<AdminExpert> _experts;
  late List<AdminQuery> _queries;
  String _selectedPeriod = 'Day';
  static const _storageKey = 'admin_dashboard_state_v1';
  late final VoidCallback _catalogListener;
  bool get _isOwner =>
      Session.currentUser.role.toLowerCase().trim() == 'owner';

  final _stats = const [
    _PeriodStat(period: 'Day', users: 12, pets: 5),
    _PeriodStat(period: 'Week', users: 58, pets: 24),
    _PeriodStat(period: 'Month', users: 232, pets: 96),
    _PeriodStat(period: 'Year', users: 1880, pets: 820),
  ];

  _ChartData _chartDataFor(String period) {
    int points;
    List<String> labels;
    switch (period) {
      case 'Week':
        points = 7;
        labels = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        break;
      case 'Month':
        points = 30;
        labels = List.generate(30, (i) => '${i + 1}');
        break;
      case 'Year':
        points = 12;
        labels = const [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec'
        ];
        break;
      case 'Day':
      default:
        points = 24;
        labels = List.generate(24, (i) => '${i}h');
        break;
    }

    final stat = _stats.firstWhere(
      (s) => s.period == period,
      orElse: () => _stats.first,
    );
    final baseUsers = stat.users / points;
    final basePets = stat.pets / points;

    double wave(int i, int count, {double offset = 0}) {
      final x = (i / count) * math.pi * 2;
      return 1 +
          0.6 * math.sin(x + offset) +
          0.3 * math.sin(x * 2 + offset / 2);
    }

    final users = List<double>.generate(points,
        (i) => (baseUsers * wave(i, points)).clamp(0.2, double.infinity));
    final pets = List<double>.generate(
        points,
        (i) => (basePets * wave(i, points, offset: 0.8))
            .clamp(0.2, double.infinity));

    return _ChartData(users: users, pets: pets, labels: labels);
  }

  _ChartData _ownerChartDataFor(String period,
      {required int buyCount, required int sellCount}) {
    int points;
    List<String> labels;
    switch (period) {
      case 'Week':
        points = 7;
        labels = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        break;
      case 'Month':
        points = 30;
        labels = List.generate(30, (i) => '${i + 1}');
        break;
      case 'Year':
        points = 12;
        labels = const [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec'
        ];
        break;
      case 'Day':
      default:
        points = 24;
        labels = List.generate(24, (i) => '${i}h');
        break;
    }

    double wave(int i, int count, {double offset = 0}) {
      final x = (i / count) * math.pi * 2;
      return 1 +
          0.6 * math.sin(x + offset) +
          0.3 * math.sin(x * 2 + offset / 2);
    }

    if (buyCount <= 0 && sellCount <= 0) {
      return _ChartData(
          users: List.filled(points, 0),
          pets: List.filled(points, 0),
          labels: labels);
    }

    final baseBuys = buyCount <= 0 ? 0 : buyCount / points;
    final baseSells = sellCount <= 0 ? 0 : sellCount / points;
    final buysList = List<double>.generate(
        points,
        (i) => buyCount <= 0
            ? 0
            : (baseBuys * wave(i, points, offset: 0.4))
                .clamp(0.1, double.infinity));
    final sellsList = List<double>.generate(
        points,
        (i) => sellCount <= 0
            ? 0
            : (baseSells * wave(i, points, offset: 1.0))
                .clamp(0.1, double.infinity));

    return _ChartData(users: buysList, pets: sellsList, labels: labels);
  }

  void _seedDefaults() {
    _users = [
      const AdminUser(
          name: 'Asha Singh',
          email: 'asha@example.com',
          phone: '+91 90000 12345',
          role: 'User',
          city: 'BENGALURU',
          memberSince: 'Member since 2021'),
      const AdminUser(
          name: 'Ravi Kumar',
          email: 'ravi@example.com',
          phone: '+91 98765 43210',
          role: 'Owner',
          city: 'BENGALURU',
          memberSince: 'Member since 2020'),
      const AdminUser(
          name: 'Divya R',
          email: 'divya@example.com',
          phone: '+91 93333 22211',
          role: 'User',
          city: 'MYSURU',
          memberSince: 'Member since 2022'),
    ];
    _pets = List<PetCatalogItem>.of(PetCatalog.all);
    _userHistory = [];
    _experts = const [
      AdminExpert(
          name: 'Dr. Anita',
          specialty: 'Vet',
          phone: '+91 90000 67890',
          city: 'BENGALURU'),
      AdminExpert(
          name: 'Rohit S',
          specialty: 'Logistics',
          phone: '+91 95555 11223',
          city: 'HUBLI'),
    ];
    _queries = [
      AdminQuery(
          title: 'Payment issue',
          user: 'Asha Singh',
          detail: 'UPI payment stuck',
          location: 'UPI checkout',
          channel: 'In-app support',
          reasons: ['Payment gateway timeout', 'User attempted retry'],
          extraDetails:
              'User reported repeated failures at confirmation step. Suggested retry after 5 minutes.',
          createdAt: DateTime(2025, 1, 1, 10, 0),
          dueDate: DateTime(2025, 1, 3, 18, 0),
          assignee: 'Rohit',
          status: QueryStatus.inProgress,
          acknowledged: true),
      AdminQuery(
          title: 'Delivery delay',
          user: 'Ravi Kumar',
          detail: 'Logistics slot needed',
          location: 'Last-mile delivery',
          channel: 'Call center',
          reasons: ['No rider availability', 'High order volume in area'],
          extraDetails:
              'Escalated to logistics partner. Expect update by EOD.',
          createdAt: DateTime(2025, 1, 2, 14, 30),
          dueDate: DateTime(2025, 1, 4, 12, 0),
          assignee: 'Logistics team',
          status: QueryStatus.resolved,
          acknowledged: true),
    ];
  }

  Future<void> _loadLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final users =
          (map['users'] as List?)?.map((e) => AdminUser.fromJson(e)).toList();
      final userHistory = (map['userHistory'] as List?)
          ?.map((e) => AdminUserArchive.fromJson(
              (e as Map).map((k, v) => MapEntry('$k', v))))
          .toList();
      final pets = (map['pets'] as List?)?.map((e) => _petFromJson(e)).toList();
      final experts = (map['experts'] as List?)
          ?.map((e) => AdminExpert.fromJson(e))
          .toList();
      final queries = (map['queries'] as List?)
          ?.map((e) => AdminQuery.fromJson(e))
          .toList();
      if (!mounted) return;
      setState(() {
        if (users != null) _users = users;
        if (userHistory != null) _userHistory = userHistory;
        if (pets != null) _pets = _dedupePets(pets);
        if (experts != null) _experts = experts;
        if (queries != null) _queries = queries;
        _mergeCatalogIntoPets();
        _mergeCatalogIntoUsers();
      });
    } catch (_) {
      // ignore malformed cache
    }
  }

  Future<void> _saveLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'users': _users.map((e) => e.toJson()).toList(),
      'userHistory': _userHistory.map((e) => e.toJson()).toList(),
      'pets': _pets.map(_petToJson).toList(),
      'experts': _experts.map((e) => e.toJson()).toList(),
      'queries': _queries.map((e) => e.toJson()).toList(),
    });
    await prefs.setString(_storageKey, payload);
  }

  void _mutate(VoidCallback fn) {
    setState(() {
      fn();
      _pets = _dedupePets(_pets);
    });
    _saveLocalState();
  }

  @override
  void initState() {
    super.initState();
    PetCatalog.pruneAndSaveOnce();
    _seedDefaults();
    _mergeCatalogIntoPets();
    _mergeCatalogIntoUsers();
    _loadLocalState();
    _catalogListener = () {
      if (!mounted) return;
      setState(() {
        _mergeCatalogIntoPets();
        _mergeCatalogIntoUsers();
      });
      _saveLocalState();
    };
    PetCatalog.version.addListener(_catalogListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (widget.initialSection) {
        case AdminSection.users:
          _openUsersScreen(context);
          break;
        case AdminSection.pets:
          _openPetsScreen(context);
          break;
        case AdminSection.experts:
          _openExpertsScreen(context);
          break;
        case AdminSection.queries:
          _openQueriesScreen(context);
          break;
        case AdminSection.panel:
          break;
      }
    });
  }

  @override
  void dispose() {
    PetCatalog.version.removeListener(_catalogListener);
    super.dispose();
  }

  void _mergeCatalogIntoPets() {
    // Prefer the latest in-memory catalog (user edits) over any cached copy.
    _pets = _dedupePets([..._pets, ...PetCatalog.all]);
  }

  void _mergeCatalogIntoUsers() {
    final merged = [..._users];
    for (final pet in PetCatalog.all) {
      final phone = pet.phone.trim();
      final name = pet.sellerName.trim().isEmpty ? 'Seller' : pet.sellerName;
      final city = pet.location.trim();
      final exists = merged.any((u) =>
          u.phone.trim() == phone ||
          (u.name.toLowerCase() == name.toLowerCase() && phone.isNotEmpty));
      if (exists) continue;
      merged.add(AdminUser(
        name: name,
        email: '${name.replaceAll(' ', '.').toLowerCase()}@example.com',
        phone: phone.isEmpty ? '+91 00000 00000' : phone,
        role: 'Owner',
        city: city.isEmpty ? 'UNKNOWN' : city,
        memberSince: 'Catalog seller',
      ));
    }
    _users = merged;
  }


  List<PetCatalogItem> _dedupePets(List<PetCatalogItem> pets) {
    final byNorm = <String, PetCatalogItem>{};
    for (final pet in pets) {
      byNorm[normalizePetTitle(pet.title)] = pet;
    }
    return byNorm.values.toList(growable: true);
  }

  Future<bool> _addOrEditUser(BuildContext ctx, {AdminUser? existing}) async {
    final result = await Navigator.push<AdminUser>(
      ctx,
      MaterialPageRoute(
        builder: (_) => AdminUserFormScreen(initial: existing),
      ),
    );
    if (result == null) return false;
    _mutate(() {
      if (existing == null) {
        _users.add(result);
      } else {
        final idx = _users.indexOf(existing);
        if (idx != -1) _users[idx] = result;
      }
    });
    return true;
  }

  Future<bool> _addOrEditPet(BuildContext ctx,
      {PetCatalogItem? existing, PetCatalogItem? updated}) async {
    PetCatalogItem? result = updated;
    result ??= await showModalBottomSheet<PetCatalogItem>(
        context: ctx,
        isScrollControlled: true,
        builder: (_) => _PetForm(initial: existing),
      );
    if (result == null) return false;
    // Keep shared catalog in sync
    await PetCatalog.upsertAndSave(result, previousTitle: existing?.title);
    _mutate(() {
      if (existing == null) {
        _pets.add(result!);
      } else {
        var idx = _pets.indexOf(existing);
        if (idx == -1) {
          idx = _pets.indexWhere((p) => p.title == existing.title);
        }
        if (idx != -1) {
          _pets[idx] = result!;
        } else {
          _pets.add(result!);
        }
      }
    });
    return true;
  }

  void _removeUser(AdminUser user) {
    _mutate(() {
      _users.remove(user);
      _userHistory.insert(
          0, AdminUserArchive(user: user, removedAt: DateTime.now()));
      _removePetsForSeller(user);
    });
  }

  void _removePetsForSeller(AdminUser user) {
    final phoneDigits = user.phone.replaceAll(RegExp(r'[^0-9]'), '');
    final toRemove = _pets.where((p) {
      final sellerDigits = p.phone.replaceAll(RegExp(r'[^0-9]'), '');
      final nameMatch =
          p.sellerName.toLowerCase() == user.name.toLowerCase();
      final phoneMatch =
          phoneDigits.isNotEmpty && sellerDigits == phoneDigits;
      return nameMatch || phoneMatch;
    }).toList();
    for (final pet in toRemove) {
      _pets.remove(pet);
      PetCatalog.removeAndSave(pet.title); 
    }
  }
  void _removePet(PetCatalogItem pet) {
    _mutate(() => _pets.remove(pet));
    PetCatalog.removeAndSave(pet.title);
  }

  void _addOrEditExpert({AdminExpert? existing}) async {
    final result = await Navigator.push<AdminExpert>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminExpertFormScreen(initial: existing),
      ),
    );
    if (result == null) return;
    _mutate(() {
      if (existing == null) {
        _experts.add(result);
      } else {
        final idx = _experts.indexOf(existing);
        if (idx != -1) _experts[idx] = result;
      }
    });
  }

  void _removeExpert(AdminExpert expert) =>
      _mutate(() => _experts.remove(expert));

  void _addOrEditQuery({AdminQuery? existing}) async {
    final result = await Navigator.push<AdminQuery>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminQueryFormScreen(initial: existing),
      ),
    );
    if (result == null) return;
    _mutate(() {
      if (existing == null) {
        _queries.add(result);
      } else {
        final idx = _queries.indexOf(existing);
        if (idx != -1) _queries[idx] = result;
      }
    });
  }

  void _removeQuery(AdminQuery query) => _mutate(() => _queries.remove(query));
  void _setQueryPending(AdminQuery query, {String? reason, String? note}) =>
      _setQueryStatus(query, QueryStatus.pending,
          reason: reason, note: note);
  void _setQueryInProgress(AdminQuery query,
          {DateTime? dueDate, String? assignee, String? note}) =>
      _setQueryStatus(query, QueryStatus.inProgress,
          dueDate: dueDate, assignee: assignee, note: note);
  void _setQueryResolved(AdminQuery query) =>
      _setQueryStatus(query, QueryStatus.resolved);

  void _clearQueryStatus(AdminQuery query) {
    _mutate(() {
      final idx = _queries.indexOf(query);
      if (idx != -1) {
        _queries[idx] = _queries[idx].copyWith(
          status: QueryStatus.pending,
          acknowledged: false,
          assignee: '',
          dueDate: null,
        );
      }
    });
  }

  void _setQueryStatus(AdminQuery query, QueryStatus status,
      {String? reason, String? note, DateTime? dueDate, String? assignee}) {
    _mutate(() {
      final idx = _queries.indexOf(query);
      if (idx != -1) {
        var updatedReasons = [..._queries[idx].reasons];
        if (reason != null && reason.trim().isNotEmpty) {
          updatedReasons.add(reason.trim());
        }
        var extra = _queries[idx].extraDetails;
        if (note != null && note.trim().isNotEmpty) {
          extra = extra.isEmpty ? note.trim() : '$extra\n$note';
        }
        _queries[idx] = _queries[idx].copyWith(
          status: status,
          acknowledged: true,
          reasons: updatedReasons,
          extraDetails: extra,
          dueDate: status == QueryStatus.inProgress
              ? (dueDate ?? _queries[idx].dueDate)
              : _queries[idx].dueDate,
          assignee: status == QueryStatus.inProgress
              ? (assignee ?? _queries[idx].assignee)
              : _queries[idx].assignee,
        );
      }
    });
  }

  void _openUsersScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminUsersScreen(
          users: _users,
          userHistory: _userHistory,
          onAddOrEdit: ({existing}) =>
              _addOrEditUser(context, existing: existing),
          onDelete: _removeUser,
          onUpdate: _updateUser,
        ),
      ),
    );
  }

  void _updateUser(AdminUser updated) {
    _mutate(() {
      final idx = _users.indexWhere((u) => u.email == updated.email);
      if (idx != -1) {
        _users[idx] = updated;
      }
    });
  }

  void _openPetsScreen(BuildContext context) {
    setState(_mergeCatalogIntoPets);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminPetsScreen(
          pets: _pets,
          onAddOrEdit: ({existing, updated}) =>
              _addOrEditPet(context, existing: existing, updated: updated),
          onDelete: _removePet,
          onAddNew: _goToSellTab,
        ),
      ),
    );
  }

  void _goToSellTab() {
    Navigator.of(context).pop(); // close AdminPetsScreen
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const SellTab(startInForm: true, closeOnSave: true),
    ));
  }

  void _openExpertsScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminExpertsScreen(
          experts: _experts,
          onAddOrEdit: ({existing}) async {
            _addOrEditExpert(existing: existing);
            return;
          },
          onDelete: _removeExpert,
        ),
      ),
    );
  }

  void _openQueriesScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminQueriesScreen(
          queries: _queries,
          onAddOrEdit: ({existing}) async {
            _addOrEditQuery(existing: existing);
            return;
          },
          onDelete: _removeQuery,
          onSetPending: _setQueryPending,
          onSetInProgress: _setQueryInProgress,
          onSetResolved: _setQueryResolved,
          onClearStatus: _clearQueryStatus,
        ),
      ),
    );
  }

  void _showOwnerOrdersInfo(BuildContext context) {
    Navigator.push(context, OwnerOrdersScreen.route());
  }

  @override
  Widget build(BuildContext context) {
    final role = Session.currentUser.role;
    final isOwner = _isOwner;
    final soldCount =
        _pets.where((p) => p.status == PetStatus.sold).length;
    final chartData = isOwner
        ? _ownerChartDataFor(_selectedPeriod,
            buyCount: _pets.length, sellCount: soldCount)
        : _chartDataFor(_selectedPeriod);
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        leadingWidth: 38,
        title: Row(
          children: [
            Text(isOwner ? 'Owner Dashboard' : 'Admin Dashboard',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            if (role.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text('($role)',
                  style: const TextStyle(
                      fontSize: 14, color: Colors.black54)),
            ],
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _StatsCard(
            stats: _stats,
            data: chartData,
            title: isOwner ? 'Pets Bought & Sold' : 'Users & Pets',
            primaryLabel: isOwner ? 'Bought' : 'Users',
            secondaryLabel: isOwner ? 'Sold' : 'Pets',
            selectedPeriod: _selectedPeriod,
            onSelect: (p) => setState(() => _selectedPeriod = p),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: isOwner
                ? [
                    _DashboardTile(
                        icon: Icons.agriculture_outlined,
                        label: 'Farm',
                        count: _pets.length,
                        onTap: () => _openPetsScreen(context)),
                    _DashboardTile(
                        icon: Icons.receipt_long_outlined,
                        label: 'Orders',
                        count: _queries.length,
                        onTap: () => _showOwnerOrdersInfo(context)),
                    _DashboardTile(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Expense Trackers',
                        count: _users.length,
                        onTap: () => Navigator.push(
                              context, OwnerExpenseScreen.route(_pets))),
                    _DashboardTile(
                        icon: Icons.local_shipping_outlined,
                        label: 'Transport',
                        count: _experts.length,
                        onTap: () => _openExpertsScreen(context)),
                  ]
                : [
                    _DashboardTile(
                        icon: Icons.people_outline,
                        label: 'Users',
                        count: _users.length,
                        onTap: () => _openUsersScreen(context)),
                    _DashboardTile(
                        icon: Icons.pets_outlined,
                        label: 'Pets',
                        count: _pets.length,
                        onTap: () => _openPetsScreen(context)),
                    _DashboardTile(
                        icon: Icons.support_agent_outlined,
                        label: 'Experts',
                        count: _experts.length,
                        onTap: () => _openExpertsScreen(context)),
                    _DashboardTile(
                        icon: Icons.forum_outlined,
                        label: 'Queries / Complaints',
                        count: _queries.length,
                        onTap: () => _openQueriesScreen(context)),
                  ],
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final List<_PeriodStat> stats;
  final _ChartData data;
  final String title;
  final String primaryLabel;
  final String secondaryLabel;
  final String selectedPeriod;
  final ValueChanged<String> onSelect;
  const _StatsCard(
      {required this.stats,
      required this.data,
      required this.title,
      required this.primaryLabel,
      required this.secondaryLabel,
      required this.selectedPeriod,
      required this.onSelect});
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final totalUsers =
        data.users.fold<double>(0, (prev, e) => prev + e).round();
    final totalPets = data.pets.fold<double>(0, (prev, e) => prev + e).round();

    OutlinedButton periodButton(String label, String period) {
      final isSelected = selectedPeriod == period;
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(40, 36),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            backgroundColor:
                isSelected ? primary.withOpacity(0.12) : Colors.white,
            foregroundColor: isSelected ? primary : Colors.grey.shade800,
            side:
                BorderSide(color: isSelected ? primary : Colors.grey.shade300),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))),
        onPressed: () => onSelect(period),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w700))),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('$totalUsers ${primaryLabel.toLowerCase()}',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, color: primary)),
                Text('$totalPets ${secondaryLabel.toLowerCase()}',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700)),
              ]),
            ],
          ),
          const SizedBox(height: 12),
          _LineAreaChart(
              users: data.users,
              pets: data.pets,
              labels: data.labels,
              userColor: primary,
              petColor: Colors.orange),
          const SizedBox(height: 14),
          Row(children: [
            _LegendDot(color: primary, label: primaryLabel),
            const SizedBox(width: 12),
            _LegendDot(color: Colors.orange, label: secondaryLabel),
            const Spacer(),
            Wrap(
              spacing: 6,
              children: [
                periodButton('D', 'Day'),
                periodButton('W', 'Week'),
                periodButton('M', 'Month'),
                periodButton('Y', 'Year'),
              ],
            ),
          ]),
        ]),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label),
    ]);
  }
}

class _UserStatsCard extends StatelessWidget {
  final _ChartData dataTransactions;
  final _ChartData dataCalls;
  final _ChartData dataMessages;
  final int buysCount;
  final int sellsCount;
  final int callsMade;
  final int callsReceived;
  final int messagesSent;
  final int messagesReceived;
  final String mode; // transactions, calls, messages
  final String selectedPeriod;
  final ValueChanged<String> onSelectPeriod;
  final ValueChanged<String> onModeChange;
  const _UserStatsCard(
      {required this.dataTransactions,
      required this.dataCalls,
      required this.dataMessages,
      required this.buysCount,
      required this.sellsCount,
      required this.callsMade,
      required this.callsReceived,
      required this.messagesSent,
      required this.messagesReceived,
      required this.mode,
      required this.selectedPeriod,
      required this.onSelectPeriod,
      required this.onModeChange});
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isTxn = mode == 'transactions';
    final isCalls = mode == 'calls';
    final isMessages = mode == 'messages';
    final isWhatsApp = mode == 'whatsapp';
    final data = isTxn
        ? dataTransactions
        : isCalls
            ? dataCalls
            : dataMessages;

    OutlinedButton periodButton(String label, String period) {
      final isSelected = selectedPeriod == period;
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(40, 36),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            backgroundColor:
                isSelected ? primary.withOpacity(0.12) : Colors.white,
            foregroundColor: isSelected ? primary : Colors.grey.shade800,
            side:
                BorderSide(color: isSelected ? primary : Colors.grey.shade300),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))),
        onPressed: () => onSelectPeriod(period),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      );
    }

    Widget _iconModeButton(
        {required bool selected,
        required Widget icon,
        required Color color,
        required VoidCallback onTap}) {
      final bg = selected ? color.withOpacity(0.16) : Colors.grey.shade200;
      final fg = selected ? color : Colors.grey.shade700;
      Widget iconChild = icon is Image
          ? icon
          : IconTheme(
              data: IconThemeData(color: fg, size: 22),
              child: icon,
            );
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(
                color: selected ? color.withOpacity(0.45) : Colors.grey.shade300),
          ),
          child: iconChild,
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      isTxn
                          ? 'Buys & Sells'
                          : isCalls
                              ? 'Calls'
                              : isWhatsApp
                                  ? 'WhatsApp'
                                  : 'Messages',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('Buys/Sells'),
                        selected: isTxn,
                        showCheckmark: false,
                        selectedColor: primary.withOpacity(.15),
                        labelStyle: TextStyle(
                            color: isTxn ? primary : Colors.grey.shade700,
                            fontWeight:
                                isTxn ? FontWeight.w700 : FontWeight.w500),
                        onSelected: (_) => onModeChange('transactions'),
                      ),
                      _iconModeButton(
                          selected: isCalls,
                          icon: const Icon(Icons.call),
                          color: Colors.blue,
                          onTap: () => onModeChange('calls')),
                      _iconModeButton(
                          selected: isMessages,
                          icon: const Icon(Icons.chat_bubble_outline),
                          color: Colors.purple,
                          onTap: () => onModeChange('messages')),
                      _iconModeButton(
                          selected: isWhatsApp,
                          icon: Image.asset(
                            'assets/icons/whatsapp.png',
                            width: 20,
                            height: 20,
                          ),
                          color: Colors.green,
                          onTap: () => onModeChange('whatsapp')),
                    ],
                  ),
                ],
              )),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(
                    isTxn
                        ? '$buysCount buys'
                        : isCalls
                            ? '$callsMade calls'
                            : isWhatsApp
                                ? '$messagesSent WA msgs'
                                : '$messagesSent sent',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isTxn
                            ? primary
                            : isCalls
                                ? Colors.blue
                                : isWhatsApp
                                    ? Colors.green.shade700
                                    : Colors.purple)),
                Text(
                    isTxn
                        ? '$sellsCount sells'
                        : isCalls
                            ? '$callsReceived received'
                            : isWhatsApp
                                ? '$messagesReceived WA msgs'
                                : '$messagesReceived received',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isTxn
                            ? Colors.orange.shade700
                            : isCalls
                                ? Colors.green.shade700
                                : isWhatsApp
                                    ? primary
                                    : Colors.orange)),
              ]),
            ],
          ),
          const SizedBox(height: 12),
          _LineAreaChart(
              users: data.users,
              pets: data.pets,
              labels: data.labels,
              userColor: isTxn
                  ? primary
                  : isCalls
                      ? Colors.blue
                      : isWhatsApp
                          ? Colors.green
                          : Colors.purple,
              petColor: isTxn
                  ? Colors.orange
                  : isCalls
                      ? Colors.green
                      : isWhatsApp
                          ? primary
                          : Colors.orange),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 6,
              children: [
                periodButton('D', 'Day'),
                periodButton('W', 'Week'),
                periodButton('M', 'Month'),
                periodButton('Y', 'Year'),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _LineAreaChart extends StatelessWidget {
  final List<double> users;
  final List<double> pets;
  final List<String> labels;
  final Color userColor;
  final Color petColor;
  const _LineAreaChart(
      {required this.users,
      required this.pets,
      required this.labels,
      required this.userColor,
      required this.petColor});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.hasBoundedWidth && constraints.maxWidth > 0
          ? constraints.maxWidth
          : MediaQuery.of(context).size.width - 48;
      return SizedBox(
        height: 220,
        width: width,
        child: CustomPaint(
          painter: _LineAreaChartPainter(
              users: users,
              pets: pets,
              labels: labels,
              userColor: userColor,
              petColor: petColor),
        ),
      );
    });
  }
}

class _LineAreaChartPainter extends CustomPainter {
  final List<double> users;
  final List<double> pets;
  final List<String> labels;
  final Color userColor;
  final Color petColor;
  _LineAreaChartPainter(
      {required this.users,
      required this.pets,
      required this.labels,
      required this.userColor,
      required this.petColor});

  @override
  void paint(Canvas canvas, Size size) {
    const double padding = 12;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding * 2;
    final maxVal = [
      ...users,
      ...pets,
      1.0,
    ].reduce((a, b) => a > b ? a : b);

    final basePaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1;
    // Grid lines
    const gridLines = 4;
    for (int i = 0; i <= gridLines; i++) {
      final y = padding + (chartHeight / gridLines) * i;
      canvas.drawLine(
          Offset(padding, y), Offset(padding + chartWidth, y), basePaint);
    }

    Path buildPath(List<double> values) {
      final step = chartWidth / (values.length - 1);
      Path path = Path();
      for (int i = 0; i < values.length; i++) {
        final x = padding + step * i;
        final y = padding + chartHeight - (values[i] / maxVal) * chartHeight;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          final prevX = padding + step * (i - 1);
          final prevY =
              padding + chartHeight - (values[i - 1] / maxVal) * chartHeight;
          final midX = (prevX + x) / 2;
          path.quadraticBezierTo(prevX, prevY, midX, (prevY + y) / 2);
          path.quadraticBezierTo(midX, y, x, y);
        }
      }
      return path;
    }

    void drawSeries(List<double> values, Color color) {
      final linePath = buildPath(values);
      final areaPath = Path.from(linePath)
        ..lineTo(padding + chartWidth, padding + chartHeight)
        ..lineTo(padding, padding + chartHeight)
        ..close();

      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withOpacity(0.12);
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color.withOpacity(0.85);

      canvas.drawPath(areaPath, fillPaint);
      canvas.drawPath(linePath, strokePaint);
    }

    drawSeries(pets, petColor);
    drawSeries(users, userColor);

    // Markers
    final step = chartWidth / (users.length - 1);
    for (int i = 0; i < users.length; i++) {
      final ux = padding + step * i;
      final uy = padding + chartHeight - (users[i] / maxVal) * chartHeight;
      canvas.drawCircle(
          Offset(ux, uy),
          3,
          Paint()
            ..color = userColor
            ..style = PaintingStyle.fill);
      final px =
          padding + step * i; // same step used above; pets list is same length
      final py = padding + chartHeight - (pets[i] / maxVal) * chartHeight;
      canvas.drawCircle(
          Offset(px, py),
          3,
          Paint()
            ..color = petColor
            ..style = PaintingStyle.fill);
    }

    // X labels
    final labelPainter = TextPainter(
        textDirection: TextDirection.ltr, textAlign: TextAlign.center);
    final interval = (labels.length / 6).ceil().clamp(1, labels.length);
    for (int i = 0; i < labels.length; i += interval) {
      final text = labels[i];
      final x = padding + step * i;
      labelPainter.text = TextSpan(
          text: text, style: const TextStyle(fontSize: 10, color: Colors.grey));
      labelPainter.layout();
      labelPainter.paint(canvas,
          Offset(x - labelPainter.width / 2, padding + chartHeight + 4));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;
  const _DashboardTile(
      {required this.icon,
      required this.label,
      required this.count,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        width: 155,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                blurRadius: 10,
                color: Colors.black.withOpacity(0.04),
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: primary),
            const SizedBox(width: 10),
            Flexible(
                child: Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13))),
          ]),
          const SizedBox(height: 6),
          Text('$count total',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ]),
      ),
    );
  }
}

class AdminUser {
  final String name;
  final String email;
  final String phone;
  final String role;
  final String city;
  final String memberSince;
  const AdminUser(
      {required this.name,
      required this.email,
      required this.phone,
      required this.role,
      required this.city,
      required this.memberSince});
  AdminUser copyWith(
          {String? name,
          String? email,
          String? phone,
          String? role,
          String? city,
          String? memberSince}) =>
      AdminUser(
          name: name ?? this.name,
          email: email ?? this.email,
          phone: phone ?? this.phone,
          role: role ?? this.role,
          city: city ?? this.city,
          memberSince: memberSince ?? this.memberSince);
  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'city': city,
        'memberSince': memberSince
      };
  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'User',
      city: json['city'] ?? '',
      memberSince: json['memberSince'] ?? 'Member since 2022');
}

class AdminUserArchive {
  final AdminUser user;
  final DateTime removedAt;

  AdminUserArchive({required this.user, required this.removedAt});

  Map<String, dynamic> toJson() =>
      {'user': user.toJson(), 'removedAt': removedAt.toIso8601String()};

  factory AdminUserArchive.fromJson(Map<String, dynamic> json) =>
      AdminUserArchive(
          user: AdminUser.fromJson(
              (json['user'] as Map).map((k, v) => MapEntry('$k', v))),
          removedAt: DateTime.tryParse(json['removedAt'] as String? ?? '') ??
              DateTime.now());

  String get removedAtFormatted =>
      '${removedAt.year}-${removedAt.month.toString().padLeft(2, '0')}-${removedAt.day.toString().padLeft(2, '0')}';
}

class AdminExpert {
  final String name;
  final String specialty;
  final String phone;
  final String city;
  const AdminExpert(
      {required this.name,
      required this.specialty,
      required this.phone,
      required this.city});
  AdminExpert copyWith(
          {String? name, String? specialty, String? phone, String? city}) =>
      AdminExpert(
          name: name ?? this.name,
          specialty: specialty ?? this.specialty,
          phone: phone ?? this.phone,
          city: city ?? this.city);
  Map<String, dynamic> toJson() =>
      {'name': name, 'specialty': specialty, 'phone': phone, 'city': city};
  factory AdminExpert.fromJson(Map<String, dynamic> json) => AdminExpert(
      name: json['name'] ?? '',
      specialty: json['specialty'] ?? '',
      phone: json['phone'] ?? '',
      city: json['city'] ?? '');
}

enum QueryStatus { pending, inProgress, resolved }

QueryStatus _queryStatusFromString(dynamic value) {
  switch ('${value ?? ''}') {
    case 'inProgress':
    case 'in_progress':
    case 'in-progress':
      return QueryStatus.inProgress;
    case 'resolved':
      return QueryStatus.resolved;
    case 'pending':
    default:
      return QueryStatus.pending;
  }
}

class AdminQuery {
  final String title;
  final String user;
  final String detail;
  final String location; // where
  final String channel; // how
  final List<String> reasons; // why
  final String extraDetails; // additional context
  final DateTime createdAt;
  final DateTime? dueDate;
  final String assignee;
  final QueryStatus status;
  final bool acknowledged;
  bool get resolved => status == QueryStatus.resolved;
  AdminQuery(
      {required this.title,
      required this.user,
      required this.detail,
      this.location = '',
      this.channel = '',
      this.reasons = const [],
      this.extraDetails = '',
      DateTime? createdAt,
      this.dueDate,
      this.assignee = '',
      QueryStatus? status,
      bool? resolved,
      this.acknowledged = false})
      : createdAt = createdAt ?? DateTime.now(),
        status = status ??
            (resolved == true ? QueryStatus.resolved : QueryStatus.pending);
  AdminQuery copyWith(
          {String? title,
          String? user,
          String? detail,
          String? location,
          String? channel,
          List<String>? reasons,
          String? extraDetails,
          DateTime? createdAt,
          DateTime? dueDate,
          String? assignee,
          QueryStatus? status,
          bool? resolved,
          bool? acknowledged}) =>
      AdminQuery(
          title: title ?? this.title,
          user: user ?? this.user,
          detail: detail ?? this.detail,
          location: location ?? this.location,
          channel: channel ?? this.channel,
          reasons: reasons ?? this.reasons,
          extraDetails: extraDetails ?? this.extraDetails,
          createdAt: createdAt ?? this.createdAt,
          dueDate: dueDate ?? this.dueDate,
          assignee: assignee ?? this.assignee,
          acknowledged: acknowledged ?? this.acknowledged,
          status: status ??
              (resolved != null
                  ? (resolved ? QueryStatus.resolved : QueryStatus.pending)
                  : this.status));
  Map<String, dynamic> toJson() => {
        'title': title,
        'user': user,
        'detail': detail,
        'location': location,
        'channel': channel,
        'reasons': reasons,
        'extraDetails': extraDetails,
        'createdAt': createdAt.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'assignee': assignee,
        'status': status.name,
        'resolved': resolved,
        'acknowledged': acknowledged
      };
  factory AdminQuery.fromJson(Map<String, dynamic> json) => AdminQuery(
      title: json['title'] ?? '',
      user: json['user'] ?? '',
      detail: json['detail'] ?? '',
      location: json['location'] ?? '',
      channel: json['channel'] ?? '',
      reasons: (json['reasons'] as List?)
              ?.map((e) => '$e'.trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
      extraDetails: json['extraDetails'] ?? '',
      createdAt: (() {
        final raw = json['createdAt'];
        if (raw is String) {
          final parsed = DateTime.tryParse(raw);
          if (parsed != null) return parsed;
        }
        return DateTime.now();
      })(),
      dueDate: (() {
        final raw = json['dueDate'];
        if (raw is String) return DateTime.tryParse(raw);
        return null;
      })(),
      assignee: json['assignee'] ?? '',
      acknowledged: json['acknowledged'] ?? false,
      status: json['status'] != null
          ? _queryStatusFromString(json['status'])
          : ((json['resolved'] ?? false)
              ? QueryStatus.resolved
              : QueryStatus.pending));
}

class _PeriodStat {
  final String period;
  final int users;
  final int pets;
  const _PeriodStat(
      {required this.period, required this.users, required this.pets});
}

class _ChartData {
  final List<double> users;
  final List<double> pets;
  final List<String> labels;
  const _ChartData(
      {required this.users, required this.pets, required this.labels});
}

Map<String, dynamic> _petToJson(PetCatalogItem p) => {
      'title': p.title,
      'images': p.images,
      'videos': p.videos,
      'price': p.price,
      'location': p.location,
      'description': p.description,
      'sellerName': p.sellerName,
      'phone': p.phone,
      'category': p.category.name,
      'addedAt': p.addedAt?.toIso8601String(),
      'status': p.status.name,
    };

PetCatalogItem _petFromJson(Map<String, dynamic> json) => PetCatalogItem(
      title: json['title'] ?? '',
      images:
          (json['images'] as List?)?.cast<String>() ?? [kPetPlaceholderImage],
      videos: (json['videos'] as List?)?.cast<String>() ?? const [],
      price: json['price'] ?? 0,
      location: json['location'] ?? '',
      description: json['description'] ?? '',
      sellerName: json['sellerName'] ?? '',
      phone: json['phone'] ?? '',
      category: PetCategory.values.firstWhere(
          (c) => c.name == (json['category'] ?? 'animals'),
          orElse: () => PetCategory.animals),
      addedAt: DateTime.tryParse(json['addedAt'] ?? ''),
      status: () {
        final raw = (json['status'] ?? PetStatus.active.name)
            .toString()
            .toLowerCase()
            .replaceAll(' ', '')
            .replaceAll('_', '');
        return PetStatus.values.firstWhere(
            (s) => s.name.toLowerCase().replaceAll('_', '') == raw,
            orElse: () => PetStatus.active);
      }(),
    );

// Screens
class AdminUserDetailScreen extends StatefulWidget {
  final AdminUser user;
  final ValueChanged<AdminUser>? onUpdated;
  const AdminUserDetailScreen({super.key, required this.user, this.onUpdated});
  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  late AdminUser _user;
  late UserProfile _profile;
  bool _loadingProfile = true;
  bool _loadingStats = true;
  String _profileId = '';
  int _callsMade = 0;
  int _callsReceived = 0;
  int _messagesSent = 0;
  int _messagesReceived = 0;
  int _wishlistCount = 0;
  List<PetCatalogItem> _ownedPets = const [];
  String _userChartPeriod = 'Day';
  String _userChartMode = 'transactions'; // transactions, calls, messages
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _memberSinceCtrl;

  bool get _isVerified =>
      _profile.isVerified || _user.role.toLowerCase() != 'user';

  String _prefer(String value, String fallback) =>
      value.trim().isEmpty ? fallback : value;

  String get _displayName => _prefer(_profile.name, _user.name);
  String get _displayEmail => _prefer(_profile.email, _user.email);
  String get _displayPhone => _prefer(_profile.phone, _user.phone);
  String get _displayCity => _prefer(_profile.city, _user.city);
  String get _displayMemberSince =>
      _prefer(_profile.memberSince, _user.memberSince);
  String get _roleLabel => _prefer(_profile.role, _user.role);

  Future<void> _impersonateUser() async {
    final profile = UserProfile(
      name: _user.name,
      email: _user.email,
      phone: _user.phone,
      city: _user.city,
      memberSince: _user.memberSince,
      isVerified: _isVerified,
      role: _user.role,
    );
    await Session.setUser(profile);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AppShell()),
      (route) => false,
    );
  }

  UserProfile _profileFromUser(AdminUser user) {
    final base = UserProfiles.forRole(user.role);
    return base.copyWith(
      name: user.name,
      email: user.email,
      phone: user.phone,
      city: user.city,
      memberSince: user.memberSince,
      role: user.role,
    );
  }

  UserProfile _mergeProfileWithAdmin(UserProfile profile, AdminUser user) {
    return profile.copyWith(
      name: profile.name.isEmpty ? user.name : null,
      email: profile.email.isEmpty ? user.email : null,
      phone: profile.phone.isEmpty ? user.phone : null,
      city: profile.city.isEmpty ? user.city : null,
      memberSince:
          profile.memberSince.isEmpty ? user.memberSince : null,
      role: profile.role.isEmpty ? user.role : null,
      isVerified: profile.isVerified || user.role.toLowerCase() != 'user',
    );
  }

  Future<void> _loadProfileFromStore() async {
    try {
      final store = UserProfileStore();
      final loaded = await store.load(_profileFromUser(widget.user));
      if (!mounted) return;
      setState(() {
        _profile = _mergeProfileWithAdmin(loaded, widget.user);
        _user = _user.copyWith(
          name: _profile.name,
          email: _profile.email,
          phone: _profile.phone,
          city: _profile.city,
          role: _profile.role,
          memberSince: _profile.memberSince,
        );
        _loadingProfile = false;
        _ownedPets = _ownedPetsForProfile();
      });
      _syncControllersFromState();
      await _loadProfileId();
      await _loadStats();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingProfile = false;
      });
    }
  }

  Future<void> _toggleVerify() async {
    await _setVerification(!_isVerified);
  }

  Future<void> _setVerification(bool verified) async {
    final updated = _profile.copyWith(isVerified: verified);
    setState(() {
      _profile = updated;
      _user = _user.copyWith(role: updated.role);
    });
    await UserProfileStore().save(updated);
    // If the current session is this user, refresh their profile too.
    if (Session.currentUser.email.toLowerCase() ==
        updated.email.toLowerCase()) {
      await Session.setUser(Session.currentUser.copyWith(isVerified: verified));
    }
  }

  String _idPrefsKey(String email) =>
      'profile_id_${email.toLowerCase().replaceAll(' ', '_')}';

  String _generateProfileId() {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final a = letters[math.Random().nextInt(letters.length)];
    final b = letters[math.Random().nextInt(letters.length)];
    final digits = math.Random().nextInt(10000).toString().padLeft(4, '0');
    return '$a$b$digits';
  }

  Future<void> _loadProfileId() async {
    final email = _displayEmail;
    if (email.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _idPrefsKey(email);
      final existing = prefs.getString(key);
      final id = existing ?? _generateProfileId();
      if (existing == null) {
        await prefs.setString(key, id);
      }
      if (!mounted) return;
      setState(() {
        _profileId = id;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _profileId = '';
      });
    }
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() {
      _loadingStats = true;
    });
    final email = _displayEmail;
    final callsMade = await CallStatsStore().loadCallsMade(email);
    final callsReceived = (await NotificationStore().loadForUser(email)).length;
    final messageStore = MessageStatsStore();
    final messagesSent = await messageStore.loadSent(email);
    final messagesReceived = await messageStore.loadReceived(email);
    await WishlistStore().loadForUser(email);
    final wishlistCount = WishlistStore().ids.value.length;
    final ownedPets = _ownedPetsForProfile();
    if (!mounted) return;
    setState(() {
      _callsMade = callsMade;
      _callsReceived = callsReceived;
      _messagesSent = messagesSent;
      _messagesReceived = messagesReceived;
      _wishlistCount = wishlistCount;
      _ownedPets = ownedPets;
      _loadingStats = false;
    });
  }

  List<PetCatalogItem> _ownedPetsForProfile() {
    final phoneDigits = _profile.phone.replaceAll(RegExp(r'[^0-9]'), '');
    return PetCatalog.all.where((pet) {
      final nameMatch =
          pet.sellerName.toLowerCase() == _profile.name.toLowerCase();
      final sellerDigits = pet.phone.replaceAll(RegExp(r'[^0-9]'), '');
      final phoneMatch =
          phoneDigits.isNotEmpty && sellerDigits == phoneDigits;
      return nameMatch || phoneMatch;
    }).toList(growable: false);
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
    final start = _parseMemberSince(_displayMemberSince) ?? DateTime.now();
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

  void _showInfo(String label) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$label (admin view)')));
  }

  void _showPurchasedPets(List<_UserTransaction> items) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: SizedBox(
          height: 460,
          child: _PurchaseList(
            items: items,
            icon: Icons.shopping_bag_outlined,
          ),
        ),
      ),
    );
  }

  void _syncControllersFromState() {
    _nameCtrl.text = _displayName;
    _emailCtrl.text = _displayEmail;
    _phoneCtrl.text = _displayPhone;
    _cityCtrl.text = _displayCity;
    _memberSinceCtrl.text = _displayMemberSince;
  }

  void _handleFieldChanged() {
    final updatedUser = _user.copyWith(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      memberSince: _memberSinceCtrl.text.trim(),
    );
    final updatedProfile = _profile.copyWith(
      name: updatedUser.name,
      email: updatedUser.email,
      phone: updatedUser.phone,
      city: updatedUser.city,
      memberSince: updatedUser.memberSince,
    );
    setState(() {
      _user = updatedUser;
      _profile = updatedProfile;
      _ownedPets = _ownedPetsForProfile();
    });
    widget.onUpdated?.call(_user);
  }

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _profile = _profileFromUser(widget.user);
    _nameCtrl = TextEditingController(text: _displayName);
    _emailCtrl = TextEditingController(text: _displayEmail);
    _phoneCtrl = TextEditingController(text: _displayPhone);
    _cityCtrl = TextEditingController(text: _displayCity);
    _memberSinceCtrl = TextEditingController(text: _displayMemberSince);
    _ownedPets = _ownedPetsForProfile();
    _loadProfileId();
    _loadStats();
    _loadProfileFromStore();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _memberSinceCtrl.dispose();
    super.dispose();
  }

  Future<void> _editProfile() async {
    final result = await showModalBottomSheet<_EditUserResult>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _EditUserSheet(user: _user),
    );
    if (result != null) {
      setState(() {
        _user = result.user;
        _profile = _profile.copyWith(
          name: result.user.name,
          email: result.user.email,
          phone: result.user.phone,
          city: result.user.city,
          memberSince: result.user.memberSince,
          role: result.user.role,
        );
        _ownedPets = _ownedPetsForProfile();
      });
      _syncControllersFromState();
      _loadProfileId();
      _loadStats();
      widget.onUpdated?.call(_user);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    Widget verificationStatus() {
      final Color accent =
          _isVerified ? Colors.green.shade700 : Colors.orange.shade700;
      final Color background =
          _isVerified ? Colors.green.shade50 : Colors.orange.shade50;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withOpacity(0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_isVerified ? Icons.verified : Icons.info_outline,
                color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isVerified
                        ? 'Verified $_roleLabel'
                        : '$_roleLabel not verified yet',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isVerified
                        ? 'Profile is confirmed so buyers can trust listings.'
                        : 'Get verified to earn buyer trust and stand out.',
                    style: const TextStyle(color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Example filtered lists; in a real setup these would be fetched per user.
    final sourcePets = _ownedPets.isNotEmpty ? _ownedPets : PetCatalog.all;
    final buys = _mockTransactions(
      type: 'buy',
      user: _user,
      catalog: sourcePets,
      verified: _isVerified,
    );
    final sells = _mockTransactions(
      type: 'sell',
      user: _user,
      catalog: sourcePets,
      verified: _isVerified,
    );

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.pop(context, _user)),
        title: const Text('User Detail'),
      ),
      body: WillPopScope(
        onWillPop: () async {
          Navigator.pop(context, _user);
          return false;
        },
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              Container(
                color: Colors.white,
                child: TabBar(
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  tabs: const [
                    Tab(text: 'Profile'),
                    Tab(text: 'Buy'),
                    Tab(text: 'Sell'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_loadingProfile)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: LinearProgressIndicator(minHeight: 3),
                            ),
                          _profileSummaryCard(verificationStatus),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: primary,
                                    side: BorderSide(
                                        color: primary, width: 1.2),
                                    backgroundColor:
                                        primary.withOpacity(0.07),
                                  ),
                                  icon: Icon(
                                      _isVerified
                                          ? Icons.verified
                                          : Icons.verified_outlined,
                                      color: primary),
                                  label: Text(_isVerified
                                      ? 'Mark unverified'
                                      : 'Verify user'),
                                  onPressed: _toggleVerify,
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _UserStatsCard(
                            mode: _userChartMode,
                            dataTransactions: _userChartDataFor(
                              _userChartPeriod,
                              buyCount: buys.length,
                              sellCount: sells.length,
                            ),
                            dataCalls: _userChartDataFor(
                              _userChartPeriod,
                              buyCount: _callsMade,
                              sellCount: _callsReceived,
                            ),
                            dataMessages: _userChartDataFor(
                              _userChartPeriod,
                              buyCount: _messagesSent,
                              sellCount: _messagesReceived,
                            ),
                            buysCount: buys.length,
                            sellsCount: sells.length,
                            callsMade: _callsMade,
                            callsReceived: _callsReceived,
                            messagesSent: _messagesSent,
                            messagesReceived: _messagesReceived,
                            selectedPeriod: _userChartPeriod,
                            onSelectPeriod: (p) =>
                                setState(() => _userChartPeriod = p),
                            onModeChange: (m) =>
                                setState(() => _userChartMode = m),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _journeyText(),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4F6D68)),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _statTile(
                                  icon: Icons.pets,
                                  label: 'Pets Listed',
                                  value: '${_ownedPets.length}'),
                              _statTile(
                                  icon: Icons.call_made,
                                  label: 'Calls Made',
                                  value: _countLabel(_callsMade)),
                              _statTile(
                                  icon: Icons.call_received,
                                  label: 'Calls Received',
                                  value: _countLabel(_callsReceived)),
                              _statTile(
                                  icon: Icons.chat_outlined,
                                  label: 'Messages Sent',
                                  value: _countLabel(_messagesSent)),
                              _statTile(
                                  icon: Icons.chat_bubble_outline,
                                  label: 'Messages Received',
                                  value: _countLabel(_messagesReceived)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _pointsUsedCard(),
                          const SizedBox(height: 16),
                          const Text('Selling Related',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: 8),
                          _sectionCard([
                            _menuTile(
                                icon: Icons.currency_rupee,
                                title: 'My Plan',
                                onTap: () => _showInfo('Plan')),
                            _menuTile(
                                icon: Icons.pets,
                                title: 'Pets (${_ownedPets.length})',
                                onTap: () => _showInfo('Pets listed')),
                            _menuTile(
                                icon: Icons.call_received,
                                title:
                                    'Calls Received (${_countLabel(_callsReceived)})',
                                onTap: () => _showInfo('Calls received')),
                          ]),
                          const SizedBox(height: 16),
                          const Text('Buying Related',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: 8),
                          _sectionCard([
                            _menuTile(
                                icon: Icons.shopping_bag,
                                title: 'Pets bought (${buys.length})',
                                onTap: () => _showPurchasedPets(buys)),
                            _menuTile(
                                icon: Icons.call_made,
                                title:
                                    'Calls Made (${_countLabel(_callsMade)})',
                                onTap: () => _showInfo('Calls made')),
                            _menuTile(
                                icon: Icons.favorite_border,
                                title:
                                    'Wishlist (${_loadingStats ? '-' : _wishlistCount})',
                                onTap: () => _showInfo('Wishlist')),
                          ]),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: _PurchaseList(
                          items: buys, icon: Icons.shopping_bag_outlined),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: _PurchaseList(
                          items: sells, icon: Icons.sell_outlined),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileSummaryCard(Widget Function() verificationStatus) {
    final badgeColor =
        _isVerified ? Colors.green.shade50 : Colors.grey.shade200;
    final badgeIcon =
        _isVerified ? Icons.verified : Icons.verified_outlined;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6ECEB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person,
                          size: 28, color: Colors.black54),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _nameCtrl,
                            onChanged: (_) => _handleFieldChanged(),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'Name',
                              hintStyle: TextStyle(color: Colors.grey),
                            ),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _cityCtrl,
                                  onChanged: (_) => _handleFieldChanged(),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    hintText: 'City',
                                  ),
                                  style: const TextStyle(
                                      color: Colors.black87, fontSize: 13),
                                ),
                              ),
                              Icon(Icons.location_on_outlined,
                                  size: 16,
                                  color:
                                      Theme.of(context).colorScheme.primary),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _emailCtrl,
                            onChanged: (_) => _handleFieldChanged(),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'Email',
                            ),
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13),
                          ),
                          TextField(
                            controller: _phoneCtrl,
                            onChanged: (_) => _handleFieldChanged(),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'Phone',
                            ),
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Text('ID: ${_profileId.isEmpty ? '--' : _profileId}',
                              style: const TextStyle(color: Colors.black54)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                verificationStatus(),
              ],
            ),
            Positioned(
              top: 0,
              right: 0,
              child: InkWell(
                onTap: _openVerifySheet,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        _isVerified ? 'Verified' : 'Not verified',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _statTile(
    {required IconData icon, required String label, required String value}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 110, maxWidth: 140),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F7F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 6),
            Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _pointsUsedCard() {
    final callPts =
        ((_callsMade + _callsReceived) * PlanStore.callCost).toDouble();
    final msgPts =
        ((_messagesSent + _messagesReceived) * PlanStore.chatCost).toDouble();
    final listPts = (_ownedPets.length * PlanStore.addPetCost).toDouble();
    final total = callPts + msgPts + listPts;

    return Card(
      elevation: 0,
      color: const Color(0xFFF4F9F8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Points used',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            if (total == 0)
              const Text('No points spent yet.',
                  style: TextStyle(color: Colors.grey))
            else ...[
              _pointsRow('Calls made', callPts),
              _pointsRow('Messages', msgPts),
              _pointsRow('Pets listed', listPts),
              const Divider(),
              _pointsRow('Total', total, bold: true),
            ],
          ],
        ),
      ),
    );
  }

Widget _pointsRow(String label, double value, {bool bold = false}) {
  final style = TextStyle(
    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
  );
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text('${value.toStringAsFixed(0)} pts', style: style),
      ],
    ),
  );
}

void _openVerifySheet() {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isVerified ? Icons.verified : Icons.verified_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _isVerified ? 'User is verified' : 'User not verified',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _isVerified
                  ? 'Mark as unverified to remove the badge.'
                  : 'Verify to grant the badge and increase trust.',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.block, color: Colors.red),
                    label: const Text('Unverify'),
                    onPressed: _isVerified
                        ? () {
                            Navigator.pop(context);
                            _setVerification(false);
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.verified),
                    label: const Text('Verify'),
                    onPressed: _isVerified
                        ? null
                        : () {
                            Navigator.pop(context);
                            _setVerification(true);
                          },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _sectionCard(List<Widget> children) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(children: children),
    );
  }

  Widget _menuTile(
      {required IconData icon,
      required String title,
      required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  _ChartData _userChartDataFor(String period,
      {required int buyCount, required int sellCount}) {
    int points;
    List<String> labels;
    switch (period) {
      case 'Week':
        points = 7;
        labels = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        break;
      case 'Month':
        points = 30;
        labels = List.generate(30, (i) => '${i + 1}');
        break;
      case 'Year':
        points = 12;
        labels = const [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec'
        ];
        break;
      case 'Day':
      default:
        points = 24;
        labels = List.generate(24, (i) => '${i}h');
        break;
    }

    double wave(int i, int count, {double offset = 0}) {
      final x = (i / count) * math.pi * 2;
      return 1 +
          0.6 * math.sin(x + offset) +
          0.3 * math.sin(x * 2 + offset / 2);
    }

    if (buyCount <= 0 && sellCount <= 0) {
      return _ChartData(
          users: List.filled(points, 0), pets: List.filled(points, 0), labels: labels);
    }

    final baseBuys = buyCount <= 0 ? 0 : buyCount / points;
    final baseSells = sellCount <= 0 ? 0 : sellCount / points;
    final buysList = List<double>.generate(
        points,
        (i) => buyCount <= 0
            ? 0
            : (baseBuys * wave(i, points, offset: 0.4))
                .clamp(0.1, double.infinity));
    final sellsList = List<double>.generate(
        points,
        (i) => sellCount <= 0
            ? 0
            : (baseSells * wave(i, points, offset: 1.0))
                .clamp(0.1, double.infinity));

    return _ChartData(users: buysList, pets: sellsList, labels: labels);
  }
}

class _EditUserResult {
  final AdminUser user;
  _EditUserResult({required this.user});
}

class _EditUserSheet extends StatefulWidget {
  final AdminUser user;
  const _EditUserSheet({required this.user});
  @override
  State<_EditUserSheet> createState() => _EditUserSheetState();
}

class _EditUserSheetState extends State<_EditUserSheet> {
  late TextEditingController _name;
  late TextEditingController _email;
  late TextEditingController _phone;
  late TextEditingController _city;
  late TextEditingController _memberSince;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.name);
    _email = TextEditingController(text: widget.user.email);
    _phone = TextEditingController(text: widget.user.phone);
    _city = TextEditingController(text: widget.user.city);
    _memberSince = TextEditingController(text: widget.user.memberSince);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _city.dispose();
    _memberSince.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
      return;
    }
    final updated = widget.user.copyWith(
      name: _name.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      city: _city.text.trim(),
      memberSince: _memberSince.text.trim().isEmpty
          ? widget.user.memberSince
          : _memberSince.text.trim(),
    );
    Navigator.pop(context, _EditUserResult(user: updated));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding:
          EdgeInsets.only(left: 16, right: 16, top: 16, bottom: bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Profile',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            TextField(
              controller: _city,
              decoration: const InputDecoration(labelText: 'City'),
            ),
            TextField(
              controller: _memberSince,
              decoration: const InputDecoration(labelText: 'Member since'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: _save, child: const Text('Save changes')),
            ),
          ],
        ),
      ),
    );
  }
}

List<PetCatalogItem> _ownedPetsFor(
    AdminUser user, List<PetCatalogItem> source) {
  final phoneDigits = user.phone.replaceAll(RegExp(r'[^0-9]'), '');
  return source
      .where((p) {
        final nameMatch =
            p.sellerName.toLowerCase() == user.name.toLowerCase();
        final sellerDigits = p.phone.replaceAll(RegExp(r'[^0-9]'), '');
        final phoneMatch =
            phoneDigits.isNotEmpty && sellerDigits == phoneDigits;
        return nameMatch || phoneMatch;
      })
      .toList(growable: false);
}

List<PetCatalogItem> _purchasedPetsFor(
  AdminUser user,
  List<PetCatalogItem> catalog,
  List<PetCatalogItem> owned,
) {
  if (catalog.isEmpty) return const [];
  final ownedKeys =
      owned.map((p) => normalizePetTitle(p.title).toLowerCase()).toSet();
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

  final seed = seedForName(user.name);
  final maxCount = math.min(5, catalog.length);
  final List<PetCatalogItem> purchases = [];
  var idx = seed % catalog.length;
  while (purchases.length < maxCount) {
    final pet = catalog[idx];
    final key = normalizePetTitle(pet.title).toLowerCase();
    if (!ownedKeys.contains(key)) {
      purchases.add(pet);
    }
    idx = (idx + 1) % catalog.length;
    if (purchases.length < maxCount && idx == seed % catalog.length) break;
  }
  return purchases;
}

List<_UserTransaction> _mockTransactions({
  required String type,
  required AdminUser user,
  required List<PetCatalogItem> catalog,
  required bool verified,
}) {
  final pets = catalog.isNotEmpty ? catalog : PET_CATALOG;
  if (pets.isEmpty) return const [];

  final owned = _ownedPetsFor(user, pets);
  final now = DateTime.now();

  if (type == 'sell') {
    final List<_UserTransaction> txns = [];
    for (var i = 0; i < owned.length; i++) {
      final pet = owned[i];
      txns.add(_UserTransaction(
        pet: pet,
        counterparty: 'Interested buyer',
        roleLabel: 'Buyer',
        time: now.subtract(Duration(minutes: 15 * (i + 1))),
        verified: verified,
      ));
    }
    return txns;
  }

  // Purchases: choose items not owned by this user, deterministic by name.
  final purchases = _purchasedPetsFor(user, pets, owned);
  final List<_UserTransaction> txns = [];
  for (var i = 0; i < purchases.length; i++) {
    final pet = purchases[i];
    txns.add(_UserTransaction(
      pet: pet,
      counterparty: pet.sellerName.isEmpty ? 'Seller' : pet.sellerName,
      roleLabel: 'Seller',
      time: now.subtract(Duration(minutes: 18 * (i + 1))),
      verified: verified,
    ));
  }
  return txns;
}

class _PurchaseList extends StatelessWidget {
  final List<_UserTransaction> items;
  final IconData icon;
  const _PurchaseList({required this.items, required this.icon});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
          child: Text('No records yet', style: TextStyle(color: Colors.grey)));
    }
    String _formatTime(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      physics: const BouncingScrollPhysics(),
      shrinkWrap: true,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final txn = items[i];
        final pet = txn.pet;
        final time = _formatTime(txn.time);

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PetDetailsScreen(item: pet.toItem())),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: PetImage(
                    source: pet.primaryImage,
                    width: 68,
                    height: 68,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pet.displayTitle,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '${txn.roleLabel}: ${txn.counterparty}',
                            style:
                                const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            txn.verified
                                ? Icons.verified
                                : Icons.verified_outlined,
                            size: 14,
                            color: txn.verified
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(pet.location,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: List.generate(
                            5,
                            (idx) => Icon(Icons.star,
                                size: 14,
                                color: idx < 4
                                    ? Colors.amber
                                    : Colors.grey.shade300)),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(time,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 6),
                    Icon(
                      txn.verified ? Icons.check_circle : Icons.radio_button_checked,
                      color: txn.verified
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UserTransaction {
  final PetCatalogItem pet;
  final String counterparty;
  final String roleLabel; // Buyer or Seller
  final DateTime time;
  final bool verified;
  const _UserTransaction({
    required this.pet,
    required this.counterparty,
    required this.roleLabel,
    required this.time,
    required this.verified,
  });
}

class AdminExpertDetailScreen extends StatelessWidget {
  final AdminExpert expert;
  const AdminExpertDetailScreen({super.key, required this.expert});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expert Detail')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const CircleAvatar(
                    radius: 28,
                    child: Icon(Icons.support_agent,
                        size: 28, color: Colors.orange)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(expert.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 18)),
                        Text(expert.specialty,
                            style: const TextStyle(color: Colors.grey)),
                      ]),
                ),
              ]),
              const SizedBox(height: 16),
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.phone),
                  title: Text(expert.phone)),
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(expert.city)),
            ]),
          ),
        ),
      ),
    );
  }
}

class AdminQueryDetailScreen extends StatelessWidget {
  final AdminQuery query;
  const AdminQueryDetailScreen({super.key, required this.query});
  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (query.status) {
      case QueryStatus.inProgress:
        statusColor = Colors.blue;
        statusLabel = 'In progress';
        statusIcon = Icons.autorenew;
        break;
      case QueryStatus.pending:
        statusColor = Colors.orange;
        statusLabel = 'Pending';
        statusIcon = Icons.error_outline;
        break;
      case QueryStatus.resolved:
        statusColor = Colors.green;
        statusLabel = 'Resolved';
        statusIcon = Icons.check_circle;
        break;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Query / Complaint')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(statusIcon, color: statusColor, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(query.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 18)),
                ),
              ]),
              const SizedBox(height: 12),
              Text('User: ${query.user}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(query.detail),
              const SizedBox(height: 8),
              Row(children: [
                const Text('Status: ',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text(statusLabel,
                    style: TextStyle(color: statusColor)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Text('Created: ',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text(intl.DateFormat('dd MMM yyyy, HH:mm').format(query.createdAt)),
              ]),
              if (query.reasons.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Reasons:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: query.reasons
                      .map((r) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(r,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ))
                      .toList(),
                ),
              ],
              if (query.location.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Where:',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(query.location),
              ],
              if (query.channel.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('How:',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(query.channel),
              ],
              if (query.extraDetails.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Extra details:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(query.extraDetails),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class AdminUsersScreen extends StatefulWidget {
  final List<AdminUser> users;
  final Future<bool> Function({AdminUser? existing}) onAddOrEdit;
  final void Function(AdminUser user) onDelete;
  final void Function(AdminUser updated) onUpdate;
  final List<AdminUserArchive> userHistory;
  const AdminUsersScreen(
      {super.key,
      required this.users,
      required this.onAddOrEdit,
      required this.onDelete,
      required this.onUpdate,
      required this.userHistory});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  String _roleFilter = 'All';

  Future<void> _handleAdd({AdminUser? existing}) async {
    final changed = await widget.onAddOrEdit(existing: existing);
    if (changed && mounted) setState(() {});
  }

  void _handleDelete(AdminUser user) {
    widget.onDelete(user);
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    _tabCtrl.addListener(() {
      if (_tabCtrl.indexIsChanging) return;
      setState(() {
        _roleFilter = _tabFilterLabel(_tabCtrl.index);
      });
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Widget build(BuildContext context) {
    List<AdminUser> filtered = _filteredUsers();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => _handleAdd())
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.black54,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Retailers'),
            Tab(text: 'Individuals'),
            Tab(text: 'Blocked'),
            Tab(text: 'Deleted'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildUserList(_filteredUsers()), // All
          _buildUserList(_filteredUsers('Retailers')),
          _buildUserList(_filteredUsers('Individuals')),
          _buildUserList(_filteredUsers('Blocked')),
          _buildDeletedList(),
        ],
      ),
    );
  }

  String _tabFilterLabel(int index) {
    switch (index) {
      case 1:
        return 'Retailers';
      case 2:
        return 'Individuals';
      case 3:
        return 'Blocked';
      case 4:
        return 'Deleted';
      default:
        return 'All';
    }
  }

  List<AdminUser> _filteredUsers([String? override]) {
    final filter = override ?? _roleFilter;
    if (filter == 'Retailers') {
      return widget.users
          .where((u) => u.role.toLowerCase().contains('owner'))
          .toList();
    }
    if (filter == 'Individuals') {
      return widget.users
          .where((u) => u.role.toLowerCase() == 'user')
          .toList();
    }
    if (filter == 'Blocked') {
      return widget.users
          .where((u) => u.role.toLowerCase().contains('blocked'))
          .toList();
    }
    return widget.users;
  }

  Future<void> _blockUser(AdminUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Block user'),
        content: Text(
            'Block ${user.name}? They will be unable to make changes.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Block')),
        ],
      ),
    );
    if (confirm != true) return;
    final blockedUser = user.copyWith(
      role: 'Blocked',
      email: '',
      phone: '',
      city: 'Blocked',
    );
    widget.onUpdate(blockedUser);
    setState(() {});
  }

  Widget _buildUserList(List<AdminUser> users) {
    if (users.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: const [
          Card(
            child: ListTile(
              title: Text('No users found'),
              subtitle: Text('Add a user to get started.'),
            ),
          )
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: users.map((u) {
        final isBlocked = u.role.toLowerCase().contains('blocked');
        final textColor = isBlocked ? Colors.grey.shade500 : Colors.black87;
        final subtitleColor =
            isBlocked ? Colors.grey.shade500 : Colors.black54;
        return Card(
          child: ListTile(
            onTap: () async {
              final updated = await Navigator.push<AdminUser>(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        AdminUserDetailScreen(user: u, onUpdated: widget.onUpdate)),
              );
              if (updated != null) {
                widget.onUpdate(updated);
                setState(() {});
              }
            },
            leading: CircleAvatar(
              backgroundColor:
                  isBlocked
                      ? Colors.grey.shade300
                      : Theme.of(context).colorScheme.primary.withOpacity(.12),
              child:
                  Icon(Icons.person,
                      color: isBlocked
                          ? Colors.grey
                          : Theme.of(context).colorScheme.primary),
            ),
            title: Text('${u.name} (${u.role})',
                style:
                    TextStyle(fontWeight: FontWeight.w700, color: textColor)),
            subtitle: Text('${u.email}\n${u.phone}\n${u.city}',
                style: TextStyle(color: subtitleColor)),
            isThreeLine: true,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                  icon: Icon(Icons.edit_outlined,
                      color: isBlocked ? Colors.grey : null),
                  onPressed: isBlocked ? null : () => _handleAdd(existing: u)),
              IconButton(
                tooltip: 'Block user',
                icon: Icon(Icons.block,
                    color: isBlocked ? Colors.grey : Colors.orange),
                onPressed: () => _blockUser(u),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _handleDelete(u),
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDeletedList() {
    if (widget.userHistory.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: const [
          Card(
            child: ListTile(
              leading: Icon(Icons.history),
              title: Text('No deleted users'),
              subtitle: Text('Deleted users will appear here.'),
            ),
          )
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: widget.userHistory.map(
        (h) => Card(
          child: ListTile(
            leading: const Icon(Icons.history, color: Colors.grey),
            title: Text('${h.user.name} (${h.user.role})',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
                '${h.user.email}\n${h.user.phone}\n${h.user.city}\nRemoved: ${h.removedAtFormatted}'),
            isThreeLine: true,
          ),
        ),
      ).toList(),
    );
  }
}

class AdminPetsScreen extends StatefulWidget {
  final List<PetCatalogItem> pets;
  final Future<bool> Function(
      {PetCatalogItem? existing, PetCatalogItem? updated}) onAddOrEdit;
  final void Function(PetCatalogItem pet) onDelete;
  final VoidCallback onAddNew;
  final PetCategory Function(String label)? categoryFromLabel;
  const AdminPetsScreen(
      {super.key,
      required this.pets,
      required this.onAddOrEdit,
      required this.onDelete,
      required this.onAddNew,
      this.categoryFromLabel});
  @override
  State<AdminPetsScreen> createState() => _AdminPetsScreenState();
}

class _AdminPetsScreenState extends State<AdminPetsScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _listCtrl = ScrollController();
  final GlobalKey _inventoryAnchor = GlobalKey();
  late final TabController _tabCtrl;
  bool get _isOwner =>
      Session.currentUser.role.toLowerCase().trim() == 'owner';

  Future<void> _handleAdd({PetCatalogItem? existing}) async {
    if (existing != null) {
      final updated = await Navigator.push<PetCatalogItem>(
        context,
        MaterialPageRoute(
            builder: (_) =>
                AdminPetEditScreen(pet: existing, onSave: widget.onAddOrEdit)),
      );
      if (updated != null && mounted) setState(() {});
    } else {
      final changed = await widget.onAddOrEdit(existing: existing);
      if (changed && mounted) setState(() {});
    }
  }

  void _handleDelete(PetCatalogItem pet) {
    widget.onDelete(pet);
    setState(() {});
  }

  Future<void> _updateStatus(
      PetCatalogItem pet, PetStatus status) async {
    final updated = pet.copyWith(status: status);
    final changed =
        await widget.onAddOrEdit(existing: pet, updated: updated);
    if (changed && mounted) setState(() {});
  }

  Color _statusColor(PetStatus status) {
    switch (status) {
      case PetStatus.active:
        return Theme.of(context).colorScheme.primary;
      case PetStatus.inactive:
        return Colors.grey.shade700;
      case PetStatus.sold:
        return Colors.blueGrey;
      case PetStatus.pendingApproval:
        return Colors.orange.shade700;
      case PetStatus.deleted:
        return Colors.red.shade400;
    }
  }

  Widget _statusDropdown(PetCatalogItem pet) {
    final color = _statusColor(pet.status);
    return DropdownButtonHideUnderline(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.35)),
          color: color.withOpacity(0.08),
        ),
        child: DropdownButton<PetStatus>(
          value: pet.status,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 13),
          onChanged: (status) {
            if (status != null) _updateStatus(pet, status);
          },
          items: PetStatus.values
              .map(
                (status) => DropdownMenuItem(
                  value: status,
                  child: Text(status.label,
                      style: TextStyle(
                          color: _statusColor(status),
                          fontWeight: FontWeight.w600)),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _listCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  void _scrollToInventory() {
    final ctx = _inventoryAnchor.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut);
    } else {
      _listCtrl.animateTo(0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farm'),
        actions: [
          IconButton(
              icon: const Icon(Icons.add),
              onPressed: widget.onAddNew), // go to Sell tab
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.black54,
          tabs: const [
            Tab(text: 'Farm'),
            Tab(text: 'Inventory'),
            Tab(text: 'Pet Food'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _petList(widget.pets),
          _inventoryList(widget.pets),
          _petFoodTab(),
        ],
      ),
    );
  }

  Widget _petList(List<PetCatalogItem> pets) {
    final summary = _farmDashboardCard(widget.pets);
    if (pets.isEmpty) {
      return ListView(
        controller: _listCtrl,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          summary,
          const SizedBox(height: 12),
          _actionsRow(),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              title: Text('No pets available'),
              subtitle: Text('Add a pet to populate the list.'),
            ),
          )
        ],
      );
    }
    return ListView(
      controller: _listCtrl,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        summary,
        const SizedBox(height: 12),
        _actionsRow(),
        const SizedBox(height: 12),
        _inventoryPreview(pets.take(2).toList()),
      ],
    );
  }

  Widget _inventoryList(List<PetCatalogItem> pets) {
    if (pets.isEmpty) {
      return ListView(
        controller: _listCtrl,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: const [
          Card(
            child: ListTile(
              title: Text('No inventory yet'),
              subtitle: Text('Add animals to see them here.'),
            ),
          )
        ],
      );
    }
    return ListView.separated(
      controller: _listCtrl,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: pets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final p = pets[index];
        return Card(
          child: ListTile(
            isThreeLine: true,
            contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => PetDetailsScreen(item: p.toItem())),
            ),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: PetImage(
                source: p.primaryImage,
                width: 46,
                height: 46,
                fit: BoxFit.cover,
              ),
            ),
            title: Text(
              normalizePetTitle(p.title),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Location: ${p.location}'),
                Text('Cost: Rs ${p.price}'),
                Text('Status: ${p.status.label}'),
                Text(_statusDateLabel(p)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit listing',
                      onPressed: () => _handleAdd(existing: p),
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      splashRadius: 20,
                    ),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        shape: const StadiumBorder(),
                        foregroundColor: Colors.blueGrey.shade800,
                        backgroundColor: Colors.blueGrey.shade50,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.sell_outlined, size: 16),
                      label: const Text('Sold'),
                      onPressed: () => _updateStatus(p, PetStatus.sold),
                    ),
                  ],
                ),
              ],
            ),
            trailing: _statusDropdown(p),
          ),
        );
      },
    );
  }

  Widget _actionsRow() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Animal'),
            onPressed: widget.onAddNew,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.list_alt_outlined),
            label: const Text('View Inventory'),
            onPressed: () => _tabCtrl.animateTo(1),
          ),
        ),
      ],
    );
  }

  Widget _inventoryPreview(List<PetCatalogItem> preview) {
    if (preview.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent in Inventory',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 8),
        ...preview.map((p) => Card(
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                onTap: () => _tabCtrl.animateTo(1),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: PetImage(
                    source: p.primaryImage,
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                  ),
                ),
                title: Text(normalizePetTitle(p.title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('Rs ${p.price} • ${p.location}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54)),
              ),
            )),
      ],
    );
  }
  Widget _adminGrid(List<PetCatalogItem> pets) {
    if (pets.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: ListTile(
              title: Text('No pets yet'),
              subtitle: Text('Add a pet to populate your catalog.'),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      controller: _listCtrl,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: pets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final p = pets[index];
        return Card(
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => PetDetailsScreen(item: p.toItem())),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: PetImage(
                      source: p.primaryImage,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                normalizePetTitle(p.title),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                p.status.label,
                                style: TextStyle(
                                    color: Colors.blueGrey.shade800,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Rs ${p.price}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(p.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(
                            'Owner: ${p.sellerName.isNotEmpty ? p.sellerName : 'Unknown'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.black87, fontSize: 12)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Edit',
                              onPressed: () => _handleAdd(existing: p),
                              constraints: const BoxConstraints(
                                  minWidth: 36, minHeight: 36),
                              splashRadius: 20,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              tooltip: 'Delete',
                              onPressed: () => _handleDelete(p),
                              constraints: const BoxConstraints(
                                  minWidth: 36, minHeight: 36),
                              splashRadius: 20,
                            ),
                            const Spacer(),
                            FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                shape: const StadiumBorder(),
                                foregroundColor: Colors.blueGrey.shade800,
                                backgroundColor: Colors.blueGrey.shade50,
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.sell_outlined, size: 16),
                              label: const Text('Sold'),
                              onPressed: () =>
                                  _updateStatus(p, PetStatus.sold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _petFoodTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Card(
          child: ListTile(
            leading: Icon(Icons.restaurant_outlined,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('Pet Food'),
            subtitle: const Text(
                'Track and add feed supplies here. Coming soon with inventory tracking.'),
          ),
        ),
      ],
    );
  }

  String _statusDateLabel(PetCatalogItem pet) {
    final date = pet.addedAt;
    final verb = pet.status == PetStatus.sold ? 'Sold on' : 'Listed on';
    if (date == null) return '$verb: date not available';
    return '$verb ${intl.DateFormat('dd MMM yyyy').format(date)}';
  }

  Card _farmDashboardCard(List<PetCatalogItem> allPets) {
    final total = allPets.length;
    final soldList = allPets.where((p) => p.status == PetStatus.sold).toList();
    final sold = soldList.length;
    final setForSale =
        allPets.where((p) => p.status == PetStatus.active).length;
    final bought =
        total - sold - setForSale < 0 ? 0 : total - sold - setForSale;
    final unsoldOwned = allPets
        .where((p) =>
            p.status != PetStatus.sold && p.status != PetStatus.deleted)
        .length;
    final listedValue =
        allPets.fold<int>(0, (sum, p) => sum + (p.price > 0 ? p.price : 0));
    final soldValue =
        soldList.fold<int>(0, (sum, p) => sum + (p.price > 0 ? p.price : 0));
    final lastSoldDate = soldList
        .map((p) => p.addedAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (prev, date) {
      if (prev == null) return date;
      return date.isAfter(prev) ? date : prev;
    });
    final purchaseValue = (listedValue - soldValue).clamp(0, 1 << 31);
    final lastActivityDate = [
      ...allPets.map((p) => p.addedAt).whereType<DateTime>(),
      if (lastSoldDate != null) lastSoldDate
    ].fold<DateTime?>(null, (prev, date) {
      if (prev == null) return date;
      return date.isAfter(prev) ? date : prev;
    });

    String dateLabel(DateTime? value) =>
        value == null ? 'Not available' : intl.DateFormat('dd MMM yyyy').format(value);

    String money(int value) => 'Rs $value';

    Widget statCard({
      required String label,
      required String value,
      required IconData icon,
      required Color color,
      bool compact = false,
      VoidCallback? onTap,
    }) {
      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: compact ? 32 : 40,
                height: compact ? 32 : 40,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: compact ? 18 : 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: compact ? 16 : 18,
                            color: color)),
                    const SizedBox(height: 2),
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black87)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Animal Summary',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: statCard(
                        label: 'Your Pets',
                        value: '$unsoldOwned',
                        icon: Icons.pets,
                        color: Theme.of(context).colorScheme.primary,
                        onTap: () =>
                            _openFilteredList(
                                'Your Pets',
                                allPets
                                    .where((p) =>
                                        p.status != PetStatus.sold &&
                                        p.status != PetStatus.deleted)
                                    .toList())),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: statCard(
                        label: 'Available',
                        value: '$setForSale',
                        icon: Icons.sell_outlined,
                        color: Colors.green.shade700,
                        onTap: () => _openFilteredList(
                            'Available Animals',
                            allPets
                                .where((p) => p.status == PetStatus.active)
                                .toList())),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: statCard(
                        label: 'Sold',
                        value: '$sold',
                        icon: Icons.check_circle_outline,
                        color: Colors.blueGrey.shade700,
                        onTap: () => _openFilteredList(
                            'Sold Animals',
                            allPets
                                .where((p) => p.status == PetStatus.sold)
                                .toList())),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: statCard(
                        label: 'Pets Bought',
                        value: '$bought',
                        icon: Icons.shopping_bag_outlined,
                        color: Colors.purple.shade600,
                        onTap: () => _openFilteredList(
                            'Pets Bought',
                            allPets
                                .where((p) =>
                                    p.status != PetStatus.sold &&
                                    p.status != PetStatus.deleted)
                                .toList())),
                  ),
                ],
              );
            }),
            const SizedBox(height: 14),
            const Text('Business Summary',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: statCard(
                        compact: true,
                        label: 'Listing Value',
                        value: money(listedValue),
                        icon: Icons.account_balance_wallet_outlined,
                        color: Theme.of(context).colorScheme.primary,
                        onTap: () => _openValuation(
                            'Listing Value', listedValue, allPets)),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: statCard(
                        compact: true,
                        label: 'Sales Value',
                        value: money(soldValue),
                        icon: Icons.attach_money,
                        color: Theme.of(context).colorScheme.primary,
                        onTap: () => _openValuation(
                            'Sales Value', soldValue, soldList)),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: statCard(
                        compact: true,
                        label: 'Purchase Value',
                        value: money(purchaseValue),
                        icon: Icons.shopping_cart_checkout_outlined,
                        color: Theme.of(context).colorScheme.primary,
                        onTap: () => _openValuation(
                            'Purchase Value', purchaseValue, allPets)),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: statCard(
                        compact: true,
                        label: 'Last Activity',
                        value: lastActivityDate == null
                            ? 'Not available'
                            : dateLabel(lastActivityDate),
                        icon: Icons.event_available_outlined,
                        color: Colors.blueGrey.shade600,
                        onTap: () => _openActivityDetail(
                            'Last Activity', allPets, lastActivityDate)),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  void _openFilteredList(String title, List<PetCatalogItem> items) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _MetricDetailScreen(
          title: title,
          items: items,
        ),
      ),
    );
  }

  void _openValuation(
      String title, int amount, List<PetCatalogItem> items) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _MetricDetailScreen(
          title: title,
          items: items,
          extraInfo: 'Total: Rs $amount',
        ),
      ),
    );
  }

  void _openActivityDetail(
      String title, List<PetCatalogItem> items, DateTime? date) {
    final label = date == null
        ? 'Not available'
        : intl.DateFormat('dd MMM yyyy, h:mm a').format(date);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _MetricDetailScreen(
          title: title,
          items: items,
          extraInfo: 'Last activity: $label',
        ),
      ),
    );
  }
}

class _MetricDetailScreen extends StatelessWidget {
  final String title;
  final List<PetCatalogItem> items;
  final String? extraInfo;
  const _MetricDetailScreen(
      {required this.title, required this.items, this.extraInfo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (extraInfo != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(extraInfo!,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (items.isEmpty)
            const Card(
              child: ListTile(
                title: Text('No data'),
                subtitle: Text('Nothing to show for this metric yet.'),
              ),
            )
          else
            ...items.map((p) => Card(
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: PetImage(
                        source: p.primaryImage,
                        width: 46,
                        height: 46,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(normalizePetTitle(p.title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rs ${p.price} • ${p.location}'),
                        Text('Status: ${p.status.label}',
                            style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}

class AdminPetEditScreen extends StatelessWidget {
  final PetCatalogItem pet;
  final Future<bool> Function({PetCatalogItem? existing, PetCatalogItem? updated})
      onSave;
  const AdminPetEditScreen(
      {super.key, required this.pet, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return SellTab(
      initial: pet,
      closeOnSave: true,
      onSaved: (updated) async {
        await onSave(existing: pet, updated: updated);
        if (Navigator.canPop(context)) Navigator.pop(context, updated);
      },
    );
  }
}

class AdminExpertsScreen extends StatefulWidget {
  final List<AdminExpert> experts;
  final Future<void> Function({AdminExpert? existing}) onAddOrEdit;
  final void Function(AdminExpert expert) onDelete;
  const AdminExpertsScreen(
      {super.key,
      required this.experts,
      required this.onAddOrEdit,
      required this.onDelete});
  @override
  State<AdminExpertsScreen> createState() => _AdminExpertsScreenState();
}

class _AdminExpertsScreenState extends State<AdminExpertsScreen> {
  Future<void> _handleAdd({AdminExpert? existing}) async {
    await widget.onAddOrEdit(existing: existing);
    if (mounted) setState(() {});
  }

  void _handleDelete(AdminExpert expert) {
    widget.onDelete(expert);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Experts'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => _handleAdd())
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (widget.experts.isEmpty)
            const Card(
              child: ListTile(
                title: Text('No experts added'),
                subtitle: Text('Add an expert to manage support.'),
              ),
            )
          else
            ...widget.experts.map((e) => Card(
                  child: ListTile(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AdminExpertDetailScreen(expert: e)),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.withOpacity(.12),
                      child:
                          const Icon(Icons.support_agent, color: Colors.orange),
                    ),
                    title: Text(e.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${e.specialty} - ${e.phone} - ${e.city}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _handleAdd(existing: e)),
                      IconButton(
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _handleDelete(e),
                      ),
                    ]),
                  ),
                )),
        ],
      ),
    );
  }
}

class AdminQueriesScreen extends StatefulWidget {
  final List<AdminQuery> queries;
  final Future<void> Function({AdminQuery? existing}) onAddOrEdit;
  final void Function(AdminQuery query) onDelete;
  final void Function(AdminQuery query, {String? reason, String? note})
      onSetPending;
  final void Function(AdminQuery query,
          {DateTime? dueDate, String? assignee, String? note})
      onSetInProgress;
  final void Function(AdminQuery query) onSetResolved;
  final void Function(AdminQuery query) onClearStatus;
  const AdminQueriesScreen(
      {super.key,
      required this.queries,
      required this.onAddOrEdit,
      required this.onDelete,
      required this.onSetPending,
      required this.onSetInProgress,
      required this.onSetResolved,
      required this.onClearStatus});
  @override
  State<AdminQueriesScreen> createState() => _AdminQueriesScreenState();
}

class _AdminQueriesScreenState extends State<AdminQueriesScreen> {
  Future<void> _handleAdd({AdminQuery? existing}) async {
    await widget.onAddOrEdit(existing: existing);
    if (mounted) setState(() {});
  }

  void _handleDelete(AdminQuery query) {
    widget.onDelete(query);
    setState(() {});
  }

  void _clearQueryStatus(AdminQuery query) {
    widget.onClearStatus(query);
  }

  Future<void> _handlePending(AdminQuery query) async {
    if (query.status == QueryStatus.pending && query.acknowledged) {
      _clearQueryStatus(query);
      setState(() {});
      return;
    }
    final result = await _askPendingReason();
    if (result == null) return;
    widget.onSetPending(query, reason: result.$1, note: result.$2);
    setState(() {});
  }

  void _handleResolved(AdminQuery query) {
    if (query.status == QueryStatus.resolved && query.acknowledged) {
      _clearQueryStatus(query);
    } else {
      widget.onSetResolved(query);
    }
    setState(() {});
  }

  Future<void> _handleInProgress(AdminQuery query) async {
    if (query.status == QueryStatus.inProgress && query.acknowledged) {
      _clearQueryStatus(query);
      setState(() {});
      return;
    }
    final result = await _askInProgressDetails();
    if (result == null) return;
    widget.onSetInProgress(query,
        dueDate: result.$1, assignee: result.$2, note: result.$3);
    setState(() {});
  }

  List<AdminQuery> _queriesFor(QueryStatus? status) {
    if (status == null) return widget.queries;
    return widget.queries.where((q) => q.status == status).toList();
  }

  IconData _statusIcon(QueryStatus status) {
    switch (status) {
      case QueryStatus.inProgress:
        return Icons.autorenew;
      case QueryStatus.pending:
        return Icons.error_outline;
      case QueryStatus.resolved:
        return Icons.check_circle;
    }
  }

  Color _statusColor(QueryStatus status) {
    switch (status) {
      case QueryStatus.inProgress:
        return Colors.blue;
      case QueryStatus.pending:
        return Colors.orange;
      case QueryStatus.resolved:
        return Colors.green;
    }
  }

  Future<(String, String)?> _askPendingReason() {
    final reasonCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    return showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as pending'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reasonCtrl,
              decoration:
                  const InputDecoration(labelText: 'Why is this on hold?'),
            ),
            TextField(
              controller: noteCtrl,
              decoration:
                  const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(
                  context, (reasonCtrl.text.trim(), noteCtrl.text.trim())),
              child: const Text('Save')),
        ],
      ),
    );
  }

  Future<(DateTime, String, String)?> _askInProgressDetails() {
    final assigneeCtrl = TextEditingController(text: 'Me');
    DateTime? selectedDate;
    String? error;
    final noteCtrl = TextEditingController();
    return showDialog<(DateTime, String, String)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Mark in progress'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(selectedDate == null
                    ? 'Select due date'
                    : intl.DateFormat('dd MMM yyyy').format(selectedDate!)),
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() {
                      selectedDate = picked;
                      error = null;
                    });
                  }
                },
              ),
              TextField(
                controller: assigneeCtrl,
                decoration:
                    const InputDecoration(labelText: 'Assign to'),
              ),
              TextField(
                controller: noteCtrl,
                decoration:
                    const InputDecoration(labelText: 'Notes (optional)'),
                maxLines: 2,
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(error!,
                      style: const TextStyle(
                          color: Colors.red, fontSize: 12)),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () {
                  if (selectedDate == null ||
                      assigneeCtrl.text.trim().isEmpty) {
                    setState(() =>
                        error = 'Please select date and assignee');
                    return;
                  }
                  Navigator.pop(
                      context,
                      (selectedDate!, assigneeCtrl.text.trim(),
                          noteCtrl.text.trim()));
                },
                child: const Text('Save')),
          ],
        ),
      ),
    );
  }

  Widget _queryTile(AdminQuery q) {
    final pendingSelected = q.acknowledged && q.status == QueryStatus.pending;
    final inProgressSelected =
        q.acknowledged && q.status == QueryStatus.inProgress;
    final resolvedSelected =
        q.acknowledged && q.status == QueryStatus.resolved;
    final statusColor =
        q.acknowledged ? _statusColor(q.status) : Colors.grey;
    final createdLabel =
        intl.DateFormat('dd MMM, HH:mm').format(q.createdAt);
    final showLeading = q.acknowledged;
    return Card(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => AdminQueryDetailScreen(query: q)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              showLeading
                  ? Icon(_statusIcon(q.status), color: statusColor)
                  : const SizedBox(width: 24, height: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.title,
                        style:
                            const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${q.user} - ${q.detail}'),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Created $createdLabel',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black54)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Mark pending',
                        icon: Icon(Icons.error_outline,
                            color: pendingSelected
                                ? Colors.orange
                                : Colors.grey),
                        onPressed: () => _handlePending(q),
                      ),
                      IconButton(
                        tooltip: 'Mark in progress',
                        icon: Icon(Icons.autorenew,
                            color: inProgressSelected
                                ? Colors.blue
                                : Colors.grey),
                        onPressed: () => _handleInProgress(q),
                      ),
                      IconButton(
                        tooltip: 'Mark resolved',
                        icon: Icon(Icons.check,
                            color: resolvedSelected
                                ? Colors.green
                                : Colors.grey),
                        onPressed: () => _handleResolved(q),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabBody(QueryStatus? status) {
    final data = _queriesFor(status);
    if (data.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: const [
          Card(
            child: ListTile(
              title: Text('No queries logged'),
              subtitle: Text('Capture user issues for follow-up.'),
            ),
          )
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: data.map(_queryTile).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('User Queries / Complaints'),
          actions: [
            IconButton(
                icon: const Icon(Icons.add), onPressed: () => _handleAdd())
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'All queries'),
              Tab(text: 'In progress'),
              Tab(text: 'Pending'),
              Tab(text: 'Resolved'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _tabBody(null),
            _tabBody(QueryStatus.inProgress),
            _tabBody(QueryStatus.pending),
            _tabBody(QueryStatus.resolved),
          ],
        ),
      ),
    );
  }

}

class AdminUserFormScreen extends StatelessWidget {
  final AdminUser? initial;
  const AdminUserFormScreen({super.key, this.initial});

  @override
  Widget build(BuildContext context) {
    final isEdit = initial != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit User' : 'Add User')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: _UserForm(initial: initial),
        ),
      ),
    );
  }
}

class _UserForm extends StatefulWidget {
  final AdminUser? initial;
  const _UserForm({this.initial});
  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  late TextEditingController _name;
  late TextEditingController _email;
  late TextEditingController _phone;
  late TextEditingController _city;
  String _role = 'User';
  late TextEditingController _memberSince;
  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _name = TextEditingController(text: init?.name ?? '');
    _email = TextEditingController(text: init?.email ?? '');
    _phone = TextEditingController(text: init?.phone ?? '');
    _city = TextEditingController(text: init?.city ?? '');
    _role = init?.role ?? 'User';
    _memberSince =
        TextEditingController(text: init?.memberSince ?? 'Member since 2022');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _city.dispose();
    _memberSince.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    final user = AdminUser(
      name: _name.text.trim(),
      email:
          _email.text.trim().isEmpty ? 'user@example.com' : _email.text.trim(),
      phone:
          _phone.text.trim().isEmpty ? '+91 99999 99999' : _phone.text.trim(),
      role: _role,
      city: _city.text.trim().isEmpty ? 'BENGALURU' : _city.text.trim(),
      memberSince: _memberSince.text.trim().isEmpty
          ? 'Member since 2022'
          : _memberSince.text.trim(),
    );
    Navigator.pop(context, user);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.initial == null ? 'Add User' : 'Edit User',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 12),
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name')),
            TextField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email')),
            TextField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Phone')),
            TextField(
                controller: _city,
                decoration: const InputDecoration(labelText: 'City')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: const [
                DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                DropdownMenuItem(value: 'Owner', child: Text('Owner')),
                DropdownMenuItem(value: 'User', child: Text('User')),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'User'),
            ),
            TextField(
                controller: _memberSince,
                decoration:
                    const InputDecoration(labelText: 'Member since label')),
            const SizedBox(height: 16),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: _save, child: const Text('Save'))),
          ]),
    );
  }
}

class _PetForm extends StatefulWidget {
  final PetCatalogItem? initial;
  const _PetForm({this.initial});
  @override
  State<_PetForm> createState() => _PetFormState();
}

class _PetFormState extends State<_PetForm> {
  late TextEditingController _title;
  late TextEditingController _price;
  late TextEditingController _location;
  late TextEditingController _seller;
  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _title = TextEditingController(text: init?.title ?? '');
    _price = TextEditingController(text: init?.price.toString() ?? '');
    _location = TextEditingController(text: init?.location ?? '');
    _seller = TextEditingController(text: init?.sellerName ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _location.dispose();
    _seller.dispose();
    super.dispose();
  }

  void _save() {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Title is required')));
      return;
    }
    final priceVal = int.tryParse(_price.text.trim()) ?? 0;
    final pet = PetCatalogItem(
      title: _title.text.trim(),
      images: widget.initial?.images ?? [kPetPlaceholderImage],
      videos: widget.initial?.videos ?? const [],
      price: priceVal,
      location:
          _location.text.trim().isEmpty ? 'BENGALURU' : _location.text.trim(),
      description: widget.initial?.description ?? 'Managed from admin panel.',
      sellerName: _seller.text.trim().isEmpty
          ? Session.currentUser.name
          : _seller.text.trim(),
      phone: widget.initial?.phone ?? '+91 90000 00000',
      category: widget.initial?.category ?? PetCategory.animals,
      addedAt: widget.initial?.addedAt ?? DateTime.now(),
      status: widget.initial?.status ?? PetStatus.active,
    );
    Navigator.pop(context, pet);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title')),
            TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price')),
            TextField(
                controller: _location,
                decoration: const InputDecoration(labelText: 'Location')),
            TextField(
                controller: _seller,
                decoration: const InputDecoration(labelText: 'Seller name')),
            const SizedBox(height: 16),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: _save, child: const Text('Save'))),
          ]),
    );
  }
}

class AdminExpertFormScreen extends StatelessWidget {
  final AdminExpert? initial;
  const AdminExpertFormScreen({super.key, this.initial});

  @override
  Widget build(BuildContext context) {
    final isEdit = initial != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Expert' : 'Add Expert')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: _ExpertForm(initial: initial),
        ),
      ),
    );
  }
}

class _ExpertForm extends StatefulWidget {
  final AdminExpert? initial;
  const _ExpertForm({this.initial});
  @override
  State<_ExpertForm> createState() => _ExpertFormState();
}

class _ExpertFormState extends State<_ExpertForm> {
  late TextEditingController _name;
  late TextEditingController _specialty;
  late TextEditingController _phone;
  late TextEditingController _city;
  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _name = TextEditingController(text: init?.name ?? '');
    _specialty = TextEditingController(text: init?.specialty ?? '');
    _phone = TextEditingController(text: init?.phone ?? '');
    _city = TextEditingController(text: init?.city ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _specialty.dispose();
    _phone.dispose();
    _city.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    final expert = AdminExpert(
      name: _name.text.trim(),
      specialty:
          _specialty.text.trim().isEmpty ? 'Support' : _specialty.text.trim(),
      phone:
          _phone.text.trim().isEmpty ? '+91 90000 00000' : _phone.text.trim(),
      city: _city.text.trim().isEmpty ? 'BENGALURU' : _city.text.trim(),
    );
    Navigator.pop(context, expert);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.initial == null ? 'Add Expert' : 'Edit Expert',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 12),
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name')),
            TextField(
                controller: _specialty,
                decoration: const InputDecoration(labelText: 'Specialty')),
            TextField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Phone')),
            TextField(
                controller: _city,
                decoration: const InputDecoration(labelText: 'City')),
            const SizedBox(height: 16),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: _save, child: const Text('Save'))),
          ]),
    );
  }
}

class AdminQueryFormScreen extends StatelessWidget {
  final AdminQuery? initial;
  const AdminQueryFormScreen({super.key, this.initial});

  @override
  Widget build(BuildContext context) {
    final isEdit = initial != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Query' : 'Add Query')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: _QueryForm(initial: initial),
        ),
      ),
    );
  }
}

class _QueryForm extends StatefulWidget {
  final AdminQuery? initial;
  const _QueryForm({this.initial});
  @override
  State<_QueryForm> createState() => _QueryFormState();
}

class _QueryFormState extends State<_QueryForm> {
  late TextEditingController _title;
  late TextEditingController _user;
  late TextEditingController _detail;
  late TextEditingController _location;
  late TextEditingController _channel;
  late TextEditingController _reasons;
  late TextEditingController _extraDetails;
  late QueryStatus _status;
  late DateTime _createdAt;
  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _title = TextEditingController(text: init?.title ?? '');
    _user = TextEditingController(text: init?.user ?? '');
    _detail = TextEditingController(text: init?.detail ?? '');
    _location = TextEditingController(text: init?.location ?? '');
    _channel = TextEditingController(text: init?.channel ?? '');
    _reasons =
        TextEditingController(text: (init?.reasons ?? []).join('\n'));
    _extraDetails = TextEditingController(text: init?.extraDetails ?? '');
    _status = init?.status ?? QueryStatus.pending;
    _createdAt = init?.createdAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _title.dispose();
    _user.dispose();
    _detail.dispose();
    _location.dispose();
    _channel.dispose();
    _reasons.dispose();
    _extraDetails.dispose();
    super.dispose();
  }

  void _save() {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Title is required')));
      return;
    }
    final query = AdminQuery(
      title: _title.text.trim(),
      user: _user.text.trim().isEmpty ? 'Unknown User' : _user.text.trim(),
      detail: _detail.text.trim().isEmpty
          ? 'No details provided'
          : _detail.text.trim(),
      location: _location.text.trim(),
      channel: _channel.text.trim(),
      reasons: _reasons.text
          .split(RegExp(r'[\n,]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      extraDetails: _extraDetails.text.trim(),
      createdAt: _createdAt,
      status: _status,
    );
    Navigator.pop(context, query);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.initial == null ? 'Add Query' : 'Edit Query',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 12),
            TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title')),
            TextField(
                controller: _user,
                decoration: const InputDecoration(labelText: 'User')),
            TextField(
                controller: _detail,
                decoration: const InputDecoration(labelText: 'Detail')),
            TextField(
                controller: _location,
                decoration: const InputDecoration(
                    labelText: 'Where it happened (e.g. screen/flow)')),
            TextField(
                controller: _channel,
                decoration: const InputDecoration(
                    labelText: 'How it was reported (channel)')),
            TextField(
              controller: _reasons,
              decoration: const InputDecoration(
                  labelText: 'Reasons / causes (one per line)'),
              maxLines: 3,
            ),
            TextField(
              controller: _extraDetails,
              decoration: const InputDecoration(
                  labelText: 'Extra details / notes'),
              maxLines: 3,
            ),
            DropdownButtonFormField<QueryStatus>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              onChanged: (v) {
                if (v != null) setState(() => _status = v);
              },
              items: const [
                DropdownMenuItem(
                    value: QueryStatus.inProgress, child: Text('In progress')),
                DropdownMenuItem(
                    value: QueryStatus.pending, child: Text('Pending')),
                DropdownMenuItem(
                    value: QueryStatus.resolved, child: Text('Resolved')),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: _save, child: const Text('Save'))),
          ]),
    );
  }
}
