import 'package:flutter/material.dart';

import '../models/pet_catalog.dart';
import '../models/pet_data.dart';
import 'dart:convert';

import '../models/pet_utils.dart';
import '../models/wishlist.dart';
import '../models/notification_store.dart';
import '../models/session.dart';
import '../models/plan_store.dart';
import '../models/user_profile.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/pet_image.dart';
import 'chat_screen.dart';
import 'pet_details.dart';
import 'pet_expert.dart' as expert;
import 'wishlist_screen.dart';
import '../utils/plan_access.dart';

/// Central place that shows chats, wishlist updates and expert tips.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _QueryNotification {
  final String title;
  final String message;
  final String status;
  const _QueryNotification(
      {required this.title, required this.message, required this.status});
}

class _QueryTile extends StatelessWidget {
  final _QueryNotification data;
  const _QueryTile({required this.data});

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'inprogress':
      case 'in_progress':
      case 'in-progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'inprogress':
      case 'in_progress':
      case 'in-progress':
        return Icons.autorenew;
      case 'resolved':
        return Icons.check_circle;
      case 'pending':
      default:
        return Icons.error_outline;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'inprogress':
      case 'in_progress':
      case 'in-progress':
        return 'In progress';
      case 'resolved':
        return 'Resolved';
      case 'pending':
      default:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(data.status);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      leading: Icon(_statusIcon(data.status), color: color),
      title: Text(
        data.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(data.message),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _statusLabel(data.status),
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 11),
        ),
      ),
    );
  }
}

class _NotificationScreenState extends State<NotificationScreen> {
  final WishlistStore wishlist = WishlistStore();
  bool _chatsExpanded = false;
  bool _wishlistExpanded = false;
  bool _expertsExpanded = false;
   bool _queriesExpanded = false;
  List<_ChatNotificationData> _chats = const [];
  List<_QueryNotification> _queries = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final store = NotificationStore();
    final email = Session.currentUser.email;
    final stored = await store.loadForUser(email);
    List<_ChatNotificationData> data;
    if (stored.isEmpty) {
      data = _buildChatNotifications();
      await store.saveForUser(
          email,
          data
              .map((c) => StoredNotification(
                  title: c.petTitle,
                  message: c.message,
                  timeLabel: c.timeLabel,
                  image: c.imageAsset))
              .toList());
    } else {
      data = stored
          .map((s) => _ChatNotificationData(
              pet: PetCatalog.all.isNotEmpty
                  ? PetCatalog.all.first
                  : PET_CATALOG.first,
              petTitle: s.title,
              message: s.message,
              timeLabel: s.timeLabel,
              imageAsset: s.image.isEmpty
                  ? PET_CATALOG.first.primaryImage
                  : s.image))
          .toList();
    }
    if (mounted) setState(() => _chats = data);

    // Query / complaint notifications from admin stored state (admin_dashboard)
    final prefs = await SharedPreferences.getInstance();
    final rawAdmin = prefs.getString('admin_dashboard_state_v1');
    List<_QueryNotification> queryNotes = [];
    if (rawAdmin != null) {
      try {
        final decoded = jsonDecode(rawAdmin);
        if (decoded is Map) {
          final queries = decoded['queries'] as List?;
          final userName = Session.currentUser.name;
          if (queries != null) {
            for (final item in queries) {
              if (item is Map && item['user'] == userName) {
                final status = '${item['status'] ?? 'pending'}';
                final title = '${item['title'] ?? 'Query'}';
                final detail = '${item['detail'] ?? ''}';
                final reason = (item['reasons'] as List?)
                        ?.map((e) => '$e'.trim())
                        .firstWhere((e) => e.isNotEmpty, orElse: () => '') ??
                    '';
                final dueRaw = item['dueDate'];
                DateTime? due;
                if (dueRaw is String) {
                  due = DateTime.tryParse(dueRaw);
                }
                queryNotes.add(_QueryNotification(
                  title: title,
                  message: _queryMessage(status, detail, reason, due),
                  status: status,
                ));
              }
            }
          }
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _queries = queryNotes;
        _loading = false;
      });
    }
  }

  Future<void> _openChat(_ChatNotificationData data) async {
    final allowed = await requirePlanPoints(context, PlanAction.chat);
    if (!allowed) return;
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          sellerName: data.pet.sellerName,
          sellerPhone: data.pet.phone,
        ),
      ),
    );
  }

  void _openWishlist() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WishlistScreen()),
    );
  }

  void _openExpertMessages() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const expert.PetExpertScreen()),
    );
  }

  List<Widget> _buildSections(List<_ChatNotificationData> chats) {
    final sections = <Widget>[];
    final chatCount = chats.length;
    final queryCount = _queries.length;
    final expertCount = _ExpertMessagesCard._messages.length;
    sections.add(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            icon: Icons.chat_bubble_outline,
            title: 'Chats for added pets',
            badgeCount: chatCount,
            subtitle:
                'Messages from buyers and support for the pets you recently added.',
            trailing: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                _chatsExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
              ),
              onPressed: () => setState(() => _chatsExpanded = !_chatsExpanded),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Card(
              child: chats.isEmpty
                  ? const _EmptyState(
                      icon: Icons.chat_bubble_outline,
                      message:
                          'No chats yet. Buyers will appear here once they message you.',
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < chats.length; i++) ...[
                          _ChatTile(
                            data: chats[i],
                            onTap: () => _openChat(chats[i]),
                          ),
                          if (i != chats.length - 1) const Divider(height: 1),
                        ],
                      ],
                    ),
            ),
            crossFadeState: _chatsExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );

    sections.add(const SizedBox(height: 20));

    // Query notifications
    sections.add(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            icon: Icons.report_problem_outlined,
            title: 'Queries & complaints',
            badgeCount: queryCount,
            subtitle:
                'Track your submitted queries and their latest status.',
            trailing: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                _queriesExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
              ),
              onPressed: () =>
                  setState(() => _queriesExpanded = !_queriesExpanded),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Card(
              child: _queries.isEmpty
                  ? const _EmptyState(
                      icon: Icons.report_problem_outlined,
                      message: 'No query updates yet.',
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < _queries.length; i++) ...[
                          _QueryTile(data: _queries[i]),
                          if (i != _queries.length - 1)
                            const Divider(height: 1),
                        ],
                      ],
                    ),
            ),
            crossFadeState: _queriesExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );

    sections.add(const SizedBox(height: 20));

    sections.addAll([
      ValueListenableBuilder<Set<String>>(
        valueListenable: wishlist.ids,
        builder: (context, ids, _) {
          final wishlistCount = ids.length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeading(
                icon: Icons.favorite_border,
                title: 'Wishlist updates',
                badgeCount: wishlistCount,
                subtitle:
                    'We\'ll notify you when wishlist pets get traction or new info.',
                trailing: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    _wishlistExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
                  onPressed: () =>
                      setState(() => _wishlistExpanded = !_wishlistExpanded),
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: _WishlistUpdatesCard(
                  wishlist: wishlist,
                  onOpenWishlist: _openWishlist,
                ),
                crossFadeState: _wishlistExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 220),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 20),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            icon: Icons.psychology_alt_outlined,
            title: 'Messages from experts',
            badgeCount: expertCount,
            subtitle: 'Care tips curated for the breeds you follow.',
            trailing: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                _expertsExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
              ),
              onPressed: () =>
                  setState(() => _expertsExpanded = !_expertsExpanded),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _ExpertMessagesCard(
              onOpenMessages: _openExpertMessages,
            ),
            crossFadeState: _expertsExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    ]);

    return sections;
  }

  String _queryMessage(
      String status, String detail, String reason, DateTime? due) {
    switch (status.toLowerCase()) {
      case 'inprogress':
      case 'in_progress':
      case 'in-progress':
        final dueLabel =
            due != null ? 'Will be completed by ${intl.DateFormat('dd MMM').format(due)}.' : '';
        return 'Your query is in progress. $dueLabel';
      case 'resolved':
        return 'Your query has been resolved. Thanks for your patience.';
      case 'pending':
      default:
        final reasonPart =
            reason.isNotEmpty ? 'Reason: $reason' : 'We will pick this soon.';
        return 'Your query is pending. $reasonPart';
    }
  }

  @override
  Widget build(BuildContext context) {
    final chats = _chats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            icon: const Icon(Icons.done_all_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All caught up!')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: _loading ? [_loadingCard()] : _buildSections(chats),
      ),
    );
  }

  Widget _loadingCard() =>
      const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));

  List<_ChatNotificationData> _buildChatNotifications() {
    final list = PetCatalog.all.take(3).toList(growable: false);
    if (list.isEmpty) return const [];

    const senders = [
      'Harsha (Buyer)',
      'Dr. Anita (Pets Support)',
      'Logistics Desk',
    ];
    const snippets = [
      'shared updated photos and asked about last vaccination.',
      'is ready for a quick video consult to review your notes.',
      'has delivery slots for the weekend, tap to confirm timing.',
    ];
    const times = ['2m ago', '18m ago', '1h ago'];

    return [
      for (var i = 0; i < list.length; i++)
        _ChatNotificationData(
          pet: list[i],
          petTitle: _formatPetTitle(list[i].title, list[i].location),
          message:
              '${senders[i % senders.length]} ${snippets[i % snippets.length]}',
          timeLabel: times[i % times.length],
          imageAsset: list[i].primaryImage,
        ),
    ];
  }

  String _formatPetTitle(String title, String location) {
    final normalized = normalizePetTitle(title);
    final display = normalized.isEmpty ? title : normalized;
    return '$display - $location';
  }
}

class _WishlistUpdatesCard extends StatelessWidget {
  final WishlistStore wishlist;
  final VoidCallback onOpenWishlist;

  const _WishlistUpdatesCard(
      {required this.wishlist, required this.onOpenWishlist});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: wishlist.ids,
      builder: (context, ids, _) {
        final items = PetCatalog.selected(ids).reversed.toList(growable: false);
        if (items.isEmpty) {
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onOpenWishlist,
              child: const _EmptyState(
                icon: Icons.favorite_border,
                message:
                    'Add pets to your wishlist to get notified about price drops and demand.',
              ),
            ),
          );
        }

        return Card(
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                _WishlistTile(
                  pet: items[i],
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PetDetailsScreen(item: items[i].toItem()),
                      ),
                    );
                  },
                ),
                if (i != items.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ChatNotificationData {
  final PetCatalogItem pet;
  final String petTitle;
  final String message;
  final String timeLabel;
  final String imageAsset;

  const _ChatNotificationData({
    required this.pet,
    required this.petTitle,
    required this.message,
    required this.timeLabel,
    required this.imageAsset,
  });
}

class _ChatTile extends StatelessWidget {
  final _ChatNotificationData data;
  final VoidCallback onTap;

  const _ChatTile({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: PetImage(
          source: data.imageAsset,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
        ),
      ),
      title: Text(
        data.petTitle,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(data.message),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'New',
              style: TextStyle(
                color: Colors.teal,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.timeLabel,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _WishlistTile extends StatelessWidget {
  final PetCatalogItem pet;
  final VoidCallback onTap;

  const _WishlistTile({required this.pet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priceText = 'Rs ${pet.price.toString()}';
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          pet.primaryImage,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
        ),
      ),
      title: Text(pet.displayTitle,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${pet.location} - ${pet.sellerName} confirmed availability',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          Text(priceText,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.teal)),
        ],
      ),
      trailing: TextButton(
        onPressed: onTap,
        child: const Text('View'),
      ),
    );
  }
}

class _ExpertMessagesCard extends StatelessWidget {
  final VoidCallback onOpenMessages;

  const _ExpertMessagesCard({required this.onOpenMessages});

  static const _messages = [
    _ExpertMessage(
      icon: Icons.medical_services_outlined,
      color: Color(0xFF0EA49D),
      title: 'Vaccination window',
      message:
          'Puppies added last week need their booster in the next 5 days. Keep records ready.',
      timeLabel: 'Today - 09:05 AM',
    ),
    _ExpertMessage(
      icon: Icons.tips_and_updates_outlined,
      color: Color(0xFFFFA000),
      title: 'Wishlist trend',
      message:
          '3 buyers are looking at your wishlist pets in Bengaluru. Reply quickly for better matches.',
      timeLabel: 'Yesterday - 07:40 PM',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < _messages.length; i++) ...[
            _ExpertTile(data: _messages[i], onTap: onOpenMessages),
            if (i != _messages.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _ExpertMessage {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String timeLabel;

  const _ExpertMessage({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.timeLabel,
  });
}

class _ExpertTile extends StatelessWidget {
  final _ExpertMessage data;
  final VoidCallback onTap;

  const _ExpertTile({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: data.color.withOpacity(0.12),
        child: Icon(data.icon, color: data.color),
      ),
      title: Text(
        data.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(data.message),
      trailing: Text(
        data.timeLabel,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final int? badgeCount;

  const _SectionHeading({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final count = (badgeCount ?? 0);
    final primary = Theme.of(context).colorScheme.primary;
    final badgeColor = primary.withOpacity(0.9);
    final badgeTextColor = Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: primary),
              ),
              if (count > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: badgeTextColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                if (subtitle != null)
                  Text(subtitle!,
                      style:
                          TextStyle(color: Colors.grey.shade700, fontSize: 13)),
              ],
            ),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: trailing,
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.grey.shade500, size: 28),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
