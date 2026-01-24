import 'package:flutter/material.dart';

import '../models/plan_store.dart';
import '../models/session.dart';
import '../views/plan_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

String buildUnlockKey({
  required String action,
  required String phone,
  required String title,
}) {
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  final normTitle = title.trim().toLowerCase();
  return '$action|$digits|$normTitle';
}

Future<bool> requirePlanPoints(
  BuildContext context,
  PlanAction action,
) async {
  return requirePlanPointsForTarget(context, action, null);
}

Future<bool> requirePlanPointsForTarget(
  BuildContext context,
  PlanAction action,
  String? targetKey,
) async {
  final store = PlanStore();
  final email = Session.currentUser.email;
  final unlocked = targetKey == null
      ? <String>{}
      : await _loadUnlockedKeys(email);
  if (targetKey != null && unlocked.contains(targetKey)) {
    return true;
  }

  final status = await store.loadForUser(email);
  final cost = PlanStore.costFor(action);
  final remaining = status.points - cost;
  if (status.points < cost) {
    return _showPlanPrompt(
      context,
      'Not enough points',
      'This action needs $cost points. You have ${status.points}. Purchase a plan to add more.',
    );
  }

  final confirmed = await _confirmPlanUsage(
    context: context,
    actionLabel: _actionLabel(action),
    cost: cost,
    currentPoints: status.points,
    remainingPoints: remaining,
  );
  if (!confirmed) return false;

  final ok = await store.consumePoints(email, cost);
  if (!ok) {
    return _showPlanPrompt(
      context,
      'Not enough points',
      'Purchase a plan to add points.',
    );
  }
  if (targetKey != null) {
    unlocked.add(targetKey);
    await _saveUnlockedKeys(email, unlocked);
  }
  return true;
}

Future<bool> isTargetUnlockedForCurrentUser(String? targetKey) async {
  if (targetKey == null || targetKey.isEmpty) return false;
  final email = Session.currentUser.email;
  final unlocked = await _loadUnlockedKeys(email);
  return unlocked.contains(targetKey);
}

String _unlockedKeyFor(String email) =>
    'plan_unlocked_${email.toLowerCase().replaceAll(' ', '_')}';

Future<Set<String>> _loadUnlockedKeys(String email) async {
  final prefs = await SharedPreferences.getInstance();
  final list = prefs.getStringList(_unlockedKeyFor(email)) ?? const [];
  return list.toSet();
}

Future<void> _saveUnlockedKeys(String email, Set<String> keys) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_unlockedKeyFor(email), keys.toList());
}

Future<bool> _showPlanPrompt(
  BuildContext context,
  String title,
  String message,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('View plans'),
        ),
      ],
    ),
  );
  if (result == true && context.mounted) {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlanScreen()),
    );
  }
  return false;
}

Future<bool> _confirmPlanUsage({
  required BuildContext context,
  required String actionLabel,
  required int cost,
  required int currentPoints,
  required int remainingPoints,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('$actionLabel confirmation'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This will deduct $cost points.'),
          const SizedBox(height: 8),
          Text('Current points: $currentPoints'),
          Text('Points after this: $remainingPoints'),
          const SizedBox(height: 12),
          const Text('Do you want to proceed?'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Proceed'),
        ),
      ],
    ),
  );
  return result ?? false;
}

String _actionLabel(PlanAction action) {
  switch (action) {
    case PlanAction.call:
      return 'Call';
    case PlanAction.chat:
      return 'Chat';
    case PlanAction.whatsapp:
      return 'WhatsApp';
    case PlanAction.addPet:
      return 'Add pet';
  }
}
