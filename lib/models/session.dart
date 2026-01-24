import 'dart:async';

import 'user_profile.dart';
import 'user_profile_store.dart';
import 'wishlist.dart';
import 'notification_store.dart';
import 'plan_store.dart';

/// Minimal in-memory session holder for the currently selected profile.
class Session {
  static UserProfile _currentUser = UserProfiles.defaultProfile;

  static UserProfile get currentUser => _currentUser;

  static Future<void> setUser(UserProfile user) async {
    final merged = await UserProfileStore().load(user);
    _currentUser = merged;
    // Load user-scoped data asynchronously.
    unawaited(WishlistStore().loadForUser(merged.email));
    unawaited(NotificationStore().loadForUser(merged.email));
    unawaited(PlanStore().ensureWelcomePoints(merged.email));
  }
}
