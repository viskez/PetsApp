import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PlanAction { call, chat, whatsapp, addPet }

class PlanOption {
  final String id;
  final String name;
  final String priceLabel;
  final int amount;
  final int points;
  final int durationDays;

  const PlanOption({
    required this.id,
    required this.name,
    required this.priceLabel,
    required this.amount,
    required this.points,
    required this.durationDays,
  });
}

class PlanStatus {
  final String? planName;
  final int points;
  final DateTime? expiresAt;

  const PlanStatus({
    required this.planName,
    required this.points,
    required this.expiresAt,
  });

  bool get isActive =>
      (expiresAt == null && points > 0) ||
      (expiresAt != null && expiresAt!.isAfter(DateTime.now()));
}

class PlanStore {
  // Notifies listeners whenever points are added/consumed so UI can refresh.
  static final ValueNotifier<int> pointsVersion = ValueNotifier<int>(0);

  static const int welcomePoints = 1000;
  static const int callCost = 5;
  static const int chatCost = 2;
  static const int whatsappCost = 3;
  static const int addPetCost = 10;

  static const List<PlanOption> plans = [
    PlanOption(
      id: 'weekly',
      name: 'Weekly Access',
      priceLabel: 'Rs 99',
      amount: 99,
      points: 50,
      durationDays: 7,
    ),
    PlanOption(
      id: 'monthly',
      name: 'Monthly Access',
      priceLabel: 'Rs 299',
      amount: 299,
      points: 200,
      durationDays: 30,
    ),
    PlanOption(
      id: 'yearly',
      name: 'Yearly Access',
      priceLabel: 'Rs 1999',
      amount: 1999,
      points: 3000,
      durationDays: 365,
    ),
  ];

  String _pointsKey(String email) =>
      'plan_points_${email.toLowerCase().replaceAll(' ', '_')}';

  String _expiresKey(String email) =>
      'plan_expires_${email.toLowerCase().replaceAll(' ', '_')}';

  String _nameKey(String email) =>
      'plan_name_${email.toLowerCase().replaceAll(' ', '_')}';

  String _bonusKey(String email) =>
      'plan_bonus_${email.toLowerCase().replaceAll(' ', '_')}';

  String _spentKey(String email) =>
      'plan_spent_${email.toLowerCase().replaceAll(' ', '_')}';

  void _notifyPointsChanged() {
    pointsVersion.value = pointsVersion.value + 1;
  }

  static int costFor(PlanAction action) {
    switch (action) {
      case PlanAction.call:
        return callCost;
      case PlanAction.chat:
        return chatCost;
      case PlanAction.whatsapp:
        return whatsappCost;
      case PlanAction.addPet:
        return addPetCost;
    }
  }

  Future<PlanStatus> loadForUser(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await ensureWelcomePoints(email);
    final points = prefs.getInt(_pointsKey(email)) ?? 0;
    final name = prefs.getString(_nameKey(email));
    final rawExpires = prefs.getString(_expiresKey(email));
    DateTime? expiresAt;
    if (rawExpires != null && rawExpires.isNotEmpty) {
      expiresAt = DateTime.tryParse(rawExpires);
    }
    return PlanStatus(planName: name, points: points, expiresAt: expiresAt);
  }

  Future<void> ensureWelcomePoints(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final bonusKey = _bonusKey(email);
    if (prefs.getBool(bonusKey) == true) return;
    final pointsKey = _pointsKey(email);
    final existing = prefs.getInt(pointsKey);
    if (existing != null) {
      await prefs.setBool(bonusKey, true);
      return;
    }
    await prefs.setInt(pointsKey, welcomePoints);
    await prefs.setString(_nameKey(email), 'Welcome Bonus');
    await prefs.remove(_expiresKey(email));
    await prefs.setInt(_spentKey(email), 0);
    await prefs.setBool(bonusKey, true);
  }

  Future<void> purchasePlan(String email, PlanOption option) async {
    final prefs = await SharedPreferences.getInstance();
    final currentPoints = prefs.getInt(_pointsKey(email)) ?? 0;
    final rawExpires = prefs.getString(_expiresKey(email));
    final existingExpiry =
        rawExpires == null ? null : DateTime.tryParse(rawExpires);
    final base =
        (existingExpiry != null && existingExpiry.isAfter(DateTime.now()))
            ? existingExpiry
            : DateTime.now();
    final expiresAt = base.add(Duration(days: option.durationDays));
    await prefs.setInt(_pointsKey(email), currentPoints + option.points);
    await prefs.setString(_nameKey(email), option.name);
    await prefs.setString(_expiresKey(email), expiresAt.toIso8601String());
    _notifyPointsChanged();
  }

  Future<bool> consumePoints(String email, int cost) async {
    final status = await loadForUser(email);
    if (status.points < cost) return false;
    final remaining = status.points - cost;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pointsKey(email), remaining);
    final spentKey = _spentKey(email);
    final existingSpent = prefs.getInt(spentKey) ?? 0;
    await prefs.setInt(spentKey, existingSpent + cost);
    _notifyPointsChanged();
    return true;
  }

  Future<int> loadSpent(String email) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_spentKey(email)) ?? 0;
  }

  Future<void> _clear(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pointsKey(email));
    await prefs.remove(_nameKey(email));
    await prefs.remove(_expiresKey(email));
    await prefs.remove(_bonusKey(email));
    await prefs.remove(_spentKey(email));
  }
}
