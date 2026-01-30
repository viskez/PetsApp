/*import 'package:flutter/material.dart';

import '../models/wishlist.dart';



class PetItem {

  final String title; final String image; final int price; final String location; final String description;

  const PetItem({required this.title, required this.image, required this.price, required this.location, required this.description});

}



class PetDetailsScreen extends StatelessWidget {

  final PetItem item;

  const PetDetailsScreen({super.key, required this.item});



  @override

  Widget build(BuildContext context) {

    final wishlist = WishlistStore();

    return Scaffold(

      appBar: AppBar(title: Text(item.displayTitle)),

      body: ListView(

        children: [

          AspectRatio(aspectRatio: 16/10, child: Image.asset(item.image, fit: BoxFit.cover)),

          Padding(

            padding: const EdgeInsets.all(16.0),

            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              Row(children: [

                Text('?${item.price}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),

                const Spacer(),

                const Icon(Icons.location_on, size: 18, color: Colors.grey),

                const SizedBox(width: 4),

                Text(item.location, style: const TextStyle(color: Colors.grey)),

              ]),

              const SizedBox(height: 12),

              Text(item.description),

              const SizedBox(height: 16),

              Row(children: [

                Expanded(child: ValueListenableBuilder<Set<String>>(

                  valueListenable: wishlist.ids,

                  builder: (_, ids, __) => OutlinedButton.icon(

                    onPressed: () => wishlist.toggle(item.title),

                    icon: Icon(ids.contains(item.title) ? Icons.favorite : Icons.favorite_border),

                    label: Text(ids.contains(item.title) ? 'Wishlisted' : 'Add to wishlist'),

                  ),

                )),

                const SizedBox(width: 12),

                Expanded(child: FilledButton.icon(onPressed: () {

                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Buying ${item.displayTitle}...')));

                }, icon: const Icon(Icons.shopping_cart_checkout), label: const Text('Buy'))),

              ]),

            ]),

          ),

        ],

      ),

    );

  }

}

*/

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import '../models/wishlist.dart';
import '../models/call_stats_store.dart';
import '../models/session.dart';
import '../models/plan_store.dart';
import '../utils/plan_access.dart';
import '../utils/whatsapp_launcher.dart';

import '../models/pet_utils.dart';
import 'chat_screen.dart';

class PetItem {
  final String title;

  final List<String> images;

  final List<String> videos;

  final int price;

  final String location;

  final String description;
  final DateTime? availableFrom;
  final String? address;
  final String? pincode;
  final String? contactPreference;
  final String? color;
  final int ageYears;
  final int ageMonths;
  final String? gender;
  final String? countType;
  final String? sizeValue;
  final String? sizeUnit;
  final String? weightKg;
  final bool negotiable;
  final bool vaccinated;
  final bool dewormed;
  final bool trained;
  final bool deliveryAvailable;
  final int pairCount;
  final int pairTotalPrice;
  final int groupMaleCount;
  final int groupFemaleCount;
  final int groupMalePrice;
  final int groupFemalePrice;
  final int groupTotalPets;
  final int groupTotalPrice;

  final String? sellerName;

  final String? sellerPhone;
  final String? vaccineDetails;

  PetItem({
    required this.title,
    required List<String> images,
    List<String> videos = const [],
    required this.price,
    required this.location,
    required this.description,
    this.availableFrom,
    this.address,
    this.pincode,
    this.contactPreference,
    this.sellerName,
    this.sellerPhone,
    this.color,
    this.ageYears = 0,
    this.ageMonths = 0,
    this.gender,
    this.countType,
    this.sizeValue,
    this.sizeUnit,
    this.weightKg,
    this.negotiable = true,
    this.vaccinated = false,
    this.dewormed = false,
    this.trained = false,
    this.deliveryAvailable = false,
    this.vaccineDetails,
    this.pairCount = 0,
    this.pairTotalPrice = 0,
    this.groupMaleCount = 0,
    this.groupFemaleCount = 0,
    this.groupMalePrice = 0,
    this.groupFemalePrice = 0,
    this.groupTotalPets = 0,
    this.groupTotalPrice = 0,
  })  : images = List.unmodifiable(
            (images.isEmpty ? [kPetPlaceholderImage] : images)
                .take(kMaxPetImages)
                .toList()),
        videos = List.unmodifiable(videos.take(kMaxPetVideos).toList());

  String get displayTitle => normalizePetTitle(title);

  String get primaryImage => images.first;
}

class PetDetailsScreen extends StatefulWidget {
  final PetItem item;

  const PetDetailsScreen({super.key, required this.item});

  @override
  State<PetDetailsScreen> createState() => _PetDetailsScreenState();
}

class _PetDetailsScreenState extends State<PetDetailsScreen> {
  bool _unlockedContact = false;

  @override
  void initState() {
    super.initState();
    _loadUnlockedStatus();
  }

  String _usageKey(String action) {
    final phone = widget.item.sellerPhone ?? '';
    return buildUnlockKey(
        action: action, phone: phone, title: widget.item.title);
  }

  Future<void> _loadUnlockedStatus() async {
    final callKey = _usageKey('call');
    final waKey = _usageKey('whatsapp');
    final unlocked = await isTargetUnlockedForCurrentUser(callKey) ||
        await isTargetUnlockedForCurrentUser(waKey);
    if (!mounted) return;
    setState(() => _unlockedContact = unlocked);
  }

  String _maskedPhoneLabel() {
    final phone = widget.item.sellerPhone ?? '';
    if (phone.trim().isEmpty) return '';
    if (_unlockedContact) {
      return phone;
    }
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final tail =
        digits.length >= 3 ? digits.substring(digits.length - 3) : digits;
    return '+91 .......$tail';
  }

  Future<void> _callSeller(BuildContext context) async {
    final phone = widget.item.sellerPhone;

    if (phone == null || phone.isEmpty) return;
    final allowed = await requirePlanPointsForTarget(
        context, PlanAction.call, _usageKey('call'));
    if (!allowed) return;
    if (!_unlockedContact && mounted) {
      setState(() => _unlockedContact = true);
    }

    final uri = Uri(scheme: 'tel', path: phone);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      await CallStatsStore().incrementCallsMade(Session.currentUser.email);
    }
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final phone = widget.item.sellerPhone;

    if (phone == null || phone.isEmpty) return;
    final allowed = await requirePlanPointsForTarget(
        context, PlanAction.whatsapp, _usageKey('whatsapp'));
    if (!allowed) return;
    if (!_unlockedContact && mounted) {
      setState(() => _unlockedContact = true);
    }

    final msg =
        'Hi ${widget.item.sellerName ?? 'Seller'}, I\'m interested in your pet.';
    await launchWhatsAppChat(context, phone, msg);
  }

  void _shareItem() {
    final lines = [
      widget.item.displayTitle,
      'Price: Rs ${widget.item.price}',
      'Location: ${widget.item.location}',
      if (widget.item.description.isNotEmpty) widget.item.description,
    ];
    Share.share(lines.join('\n'));
  }

  void _openShareSheet(BuildContext context) {
    final shareText = [
      widget.item.displayTitle,
      'Price: Rs ${widget.item.price}',
      'Location: ${widget.item.location}',
      if (widget.item.description.isNotEmpty) widget.item.description,
    ].join('\n');

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Share via',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ShareTarget(
                    icon: Image.asset('assets/icons/whatsapp.png',
                        width: 20, height: 20),
                    label: 'WhatsApp',
                    color: const Color(0xFF25D366),
                    onTap: () => _shareToWhatsApp(ctx, shareText),
                  ),
                  _ShareTarget(
                    icon: const Icon(Icons.camera_alt_outlined,
                        color: Color(0xFFE4405F)),
                    label: 'Instagram',
                    color: const Color(0xFFE4405F),
                    onTap: () => Share.share(shareText),
                  ),
                  _ShareTarget(
                    icon: const Icon(Icons.facebook, color: Color(0xFF1877F2)),
                    label: 'Facebook',
                    color: const Color(0xFF1877F2),
                    onTap: () => Share.share(shareText),
                  ),
                  _ShareTarget(
                    icon: const Icon(Icons.share_outlined, color: Colors.teal),
                    label: 'More',
                    color: Colors.teal,
                    onTap: () => Share.share(shareText),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareToWhatsApp(BuildContext context, String text) async {
    final ok =
        await launchWhatsAppChat(context, widget.item.sellerPhone ?? '', text);
    if (!ok) {
      Share.share(text);
    }
  }

  String _ageLabel(int years, int months) {
    final y = years <= 0 ? null : '$years yr${years == 1 ? '' : 's'}';
    final m = months <= 0 ? null : '$months mo${months == 1 ? '' : 's'}';
    if (y == null && m == null) return '--';
    if (y != null && m != null) return '$y $m';
    return y ?? m ?? '--';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.year}';
  }

  String _textOrDash(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? '--' : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final seller = item.sellerName ?? 'Seller';
    final (species, breed) = splitPetTitle(item.displayTitle);
    final ageLabel = _ageLabel(item.ageYears, item.ageMonths);
    final speciesLabel = _textOrDash(species);
    final breedLabel = _textOrDash(breed);
    final genderLabel = _textOrDash(item.gender);
    final countLabel = _textOrDash(item.countType);
    final colorLabel = _textOrDash(item.color);
    final weightLabel = _textOrDash(item.weightKg);
    final sizeLabel = _textOrDash(
      (item.sizeValue ?? '').isNotEmpty
          ? '${item.sizeValue} ${item.sizeUnit ?? ''}'.trim()
          : '',
    );
    final contactLabel = _textOrDash(item.contactPreference);
    final availableLabel =
        item.availableFrom != null ? _formatDate(item.availableFrom!) : '--';
    final addressLabel = [
      if ((item.address ?? '').trim().isNotEmpty) item.address!.trim(),
      if ((item.pincode ?? '').trim().isNotEmpty)
        'PIN: ${item.pincode!.trim()}',
    ].where((e) => e.isNotEmpty).join('\n');
    final resolvedAddress = addressLabel.isEmpty ? '--' : addressLabel;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.displayTitle),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _openShareSheet(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media carousel

            _PetMediaCarousel(item: item),

            const SizedBox(height: 16),

            // Title + price + location

            Text(item.displayTitle,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),

            const SizedBox(height: 8),

            Builder(builder: (context) {
              final isGroup = item.countType == 'Group';
              final isPair = item.countType == 'Pair';
              final groupMale = item.groupMalePrice;
              final groupFemale = item.groupFemalePrice;
              final hasGroupPrices =
                  isGroup && (groupMale > 0 || groupFemale > 0);

              if (hasGroupPrices) {
                return Row(
                  children: [
                    _priceChip(
                        Icons.male, groupMale > 0 ? 'Rs $groupMale' : '--'),
                    const SizedBox(width: 8),
                    _priceChip(Icons.female,
                        groupFemale > 0 ? 'Rs $groupFemale' : '--'),
                    const Spacer(),
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(item.location,
                        style: const TextStyle(color: Colors.grey)),
                  ],
                );
              }

              final mainPrice =
                  isPair ? 'Rs ${item.price} / pair' : 'Rs ${item.price}';

              return Row(
                children: [
                  Text(mainPrice,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal)),
                  const Spacer(),
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(item.location,
                      style: const TextStyle(color: Colors.grey)),
                ],
              );
            }),

            const SizedBox(height: 16),

            // Seller section

            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const CircleAvatar(radius: 22, child: Icon(Icons.person)),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(seller,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          if ((item.sellerPhone ?? '').isNotEmpty)
                            Text(_maskedPhoneLabel(),
                                style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),

                    // Contact Actions

                    _circleAction(
                      tooltip: 'Chat',
                      background: Colors.teal.shade600,
                      icon: const Icon(Icons.chat_bubble,
                          color: Colors.white, size: 20),
                      onTap: () async {
                        final allowed = await requirePlanPointsForTarget(
                            context, PlanAction.chat, _usageKey('chat'));
                        if (!allowed) return;
                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              sellerName: seller,
                              sellerPhone: item.sellerPhone ?? '',
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(width: 10),

                    _circleAction(
                      tooltip: 'Call',
                      background: const Color(0xFF0A84FF),
                      icon:
                          const Icon(Icons.call, color: Colors.white, size: 20),
                      onTap: () => _callSeller(context),
                    ),

                    const SizedBox(width: 10),

                    _circleAction(
                      tooltip: 'WhatsApp',
                      background: const Color(0xFF25D366),
                      icon: Image.asset('assets/icons/whatsapp.png',
                          width: 20, height: 20),
                      onTap: () => _openWhatsApp(context),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // About / Description
            _SectionCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Description',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    item.description.isNotEmpty ? item.description : '--',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            const Text('Pet Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            _SectionCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _InfoTile(
                    icon: Icons.pets,
                    label: 'Species',
                    value: speciesLabel,
                  ),
                  _InfoTile(
                    icon: Icons.badge_outlined,
                    label: 'Breed',
                    value: breedLabel,
                  ),
                  _InfoTile(
                    icon: Icons.cake_outlined,
                    label: 'Age',
                    value: ageLabel,
                  ),
                  _InfoTile(
                    icon: Icons.transgender,
                    label: 'Gender',
                    value: genderLabel,
                  ),
                  _InfoTile(
                    icon: Icons.groups_outlined,
                    label: 'Count',
                    value: countLabel,
                  ),
                  _InfoTile(
                    icon: Icons.palette_outlined,
                    label: 'Color',
                    value: colorLabel,
                  ),
                  if (item.countType == 'Pair') ...[
                    _InfoTile(
                      icon: Icons.all_inclusive,
                      label: 'Pair count',
                      value: item.pairCount > 0 ? '${item.pairCount}' : '--',
                    ),
                    _InfoTile(
                      icon: Icons.currency_rupee,
                      label: 'Pair total price',
                      value: item.pairTotalPrice > 0
                          ? 'Rs ${item.pairTotalPrice}'
                          : '--',
                    ),
                  ],
                  if (item.countType == 'Group') ...[
                    _InfoTile(
                      icon: Icons.male,
                      label: 'Male count',
                      value: item.groupMaleCount > 0
                          ? '${item.groupMaleCount}'
                          : '--',
                    ),
                    _InfoTile(
                      icon: Icons.female,
                      label: 'Female count',
                      value: item.groupFemaleCount > 0
                          ? '${item.groupFemaleCount}'
                          : '--',
                    ),
                    _InfoTile(
                      icon: Icons.format_list_numbered,
                      label: 'Total pets',
                      value: item.groupTotalPets > 0
                          ? '${item.groupTotalPets}'
                          : '--',
                    ),
                    _InfoTile(
                      icon: Icons.price_change_outlined,
                      label: 'Male price/pet',
                      value: item.groupMalePrice > 0
                          ? 'Rs ${item.groupMalePrice}'
                          : '--',
                    ),
                    _InfoTile(
                      icon: Icons.price_check_outlined,
                      label: 'Female price/pet',
                      value: item.groupFemalePrice > 0
                          ? 'Rs ${item.groupFemalePrice}'
                          : '--',
                    ),
                    _InfoTile(
                      icon: Icons.summarize_outlined,
                      label: 'Group total price',
                      value: item.groupTotalPrice > 0
                          ? 'Rs ${item.groupTotalPrice}'
                          : '--',
                    ),
                  ],
                  _InfoTile(
                    icon: Icons.monitor_weight_outlined,
                    label: 'Weight (kg)',
                    value: weightLabel,
                  ),
                  _InfoTile(
                    icon: Icons.straighten,
                    label: 'Size (approx.)',
                    value: sizeLabel,
                  ),
                  _InfoTile(
                    icon: Icons.handshake_outlined,
                    label: 'Negotiable',
                    value: item.negotiable ? 'Yes' : 'No',
                  ),
                  _InfoTile(
                    icon: Icons.local_shipping_outlined,
                    label: 'Delivery available',
                    value: item.deliveryAvailable ? 'Yes' : 'No',
                  ),
                  _InfoTile(
                    icon: Icons.chat_bubble_outline,
                    label: 'Contact via',
                    value: contactLabel,
                  ),
                  _InfoTile(
                    icon: Icons.event_available_outlined,
                    label: 'Available from',
                    value: availableLabel,
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: _InfoTile(
                      icon: Icons.place_outlined,
                      label: 'Address',
                      value: resolvedAddress,
                      multiline: true,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            const Text('Health & Care',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _SectionCard(
              child: Column(
                children: [
                  _HealthRow(
                    icon: Icons.vaccines_outlined,
                    title: 'Vaccinated',
                    subtitle: item.vaccinated ? 'Yes' : 'No',
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _textOrDash(item.vaccineDetails),
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black54),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  _HealthRow(
                    icon: Icons.check_circle_outline,
                    title: 'Dewormed',
                    subtitle: item.dewormed ? 'Yes' : 'No',
                  ),
                  const Divider(height: 1),
                  _HealthRow(
                    icon: Icons.school_outlined,
                    title: 'Trained',
                    subtitle: item.trained ? 'Yes' : 'No',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleAction({
    required String tooltip,
    required Widget icon,
    required Color background,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: icon,
        ),
      ),
    );
  }
}

class _PetMediaCarousel extends StatefulWidget {
  final PetItem item;

  const _PetMediaCarousel({required this.item});

  @override
  State<_PetMediaCarousel> createState() => _PetMediaCarouselState();
}

class _PetMediaCarouselState extends State<_PetMediaCarousel> {
  late final List<_PetMediaEntry> _entries;
  late final int _imageCount;
  late final int _videoCount;

  late final PageController _pageController;

  final Map<int, VideoPlayerController> _videoControllers = {};

  int _index = 0;
  bool _liked = false;
  final wishlist = WishlistStore();

  @override
  void initState() {
    super.initState();

    _entries = [
      ...widget.item.images
          .map((path) => _PetMediaEntry(source: path, isVideo: false)),
      ...widget.item.videos
          .map((path) => _PetMediaEntry(source: path, isVideo: true)),
    ];
    _imageCount = widget.item.images.length;
    _videoCount = widget.item.videos.length;

    _pageController = PageController();

    _initVideos();
  }

  void _initVideos() {
    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];

      if (!entry.isVideo) continue;

      final controller = _buildVideoController(entry.source);

      if (controller == null) continue;

      _videoControllers[i] = controller;

      controller
        ..setLooping(true)
        ..setVolume(0)
        ..initialize().then((_) {
          if (!mounted) return;

          setState(() {});

          controller.play();
        });
    }
  }

  VideoPlayerController? _buildVideoController(String source) {
    try {
      if (source.startsWith('http')) {
        return VideoPlayerController.networkUrl(Uri.parse(source));
      }

      final file = File(source);
      if (file.isAbsolute && file.existsSync()) {
        return VideoPlayerController.file(file);
      }

      return VideoPlayerController.asset(source);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();

    for (final controller in _videoControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries.isEmpty
        ? <_PetMediaEntry>[
            const _PetMediaEntry(source: kPetPlaceholderImage, isVideo: false)
          ]
        : _entries;

    final clampedIndex = _index.clamp(0, entries.length - 1);
    final hasMultiple = entries.length > 1;
    final hasAny = entries.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: (value) => setState(() => _index = value),
              itemCount: entries.length,
              itemBuilder: (_, pageIndex) =>
                  _buildEntry(entries[pageIndex], pageIndex),
            ),
            if (hasMultiple)
              Positioned.fill(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _NavButton(
                      alignment: Alignment.centerLeft,
                      icon: Icons.chevron_left,
                      onTap: () => _goRelative(-1),
                      enabled: clampedIndex > 0,
                    ),
                    _NavButton(
                      alignment: Alignment.centerRight,
                      icon: Icons.chevron_right,
                      onTap: () => _goRelative(1),
                      enabled: clampedIndex < entries.length - 1,
                    ),
                  ],
                ),
              ),
            Positioned(
              top: 10,
              right: 10,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      _liked = !_liked;
                      wishlist.toggle(widget.item.title);
                    });
                  },
                  icon: Icon(
                    wishlist.contains(widget.item.title)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: wishlist.contains(widget.item.title)
                        ? Colors.redAccent
                        : Colors.white,
                  ),
                  tooltip: _liked ? 'Wishlisted' : 'Add to wishlist',
                ),
              ),
            ),
            if (hasAny)
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: _MediaThumbnails(
                  entries: entries,
                  index: clampedIndex,
                  onTap: _jumpTo,
                ),
              ),
            if (entries[clampedIndex].isVideo)
              const Positioned(
                top: 12,
                left: 12,
                child: _MediaLabelChip(label: 'Video'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntry(_PetMediaEntry entry, int index) {
    if (entry.isVideo) {
      final controller = _videoControllers[index];

      if (controller == null) {
        return _unsupported('Video preview unavailable');
      }

      if (!controller.value.isInitialized) {
        return const Center(child: CircularProgressIndicator());
      }

      return Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
          const Align(
            alignment: Alignment.center,
            child:
                Icon(Icons.play_circle_fill, size: 64, color: Colors.white70),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () => _openImageViewer(entry.source),
      child: _buildImage(entry.source),
    );
  }

  Widget _buildImage(String source) {
    if (source.startsWith('http')) {
      return Image.network(
        source,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;

          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (_, __, ___) => _unsupported('Image not available'),
      );
    }

    final file = File(source);
    if (file.isAbsolute && file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _unsupported('Image not available'),
      );
    }

    return Image.asset(
      source.isEmpty ? kPetPlaceholderImage : source,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _unsupported('Image not available'),
    );
  }

  Widget _unsupported(String message) => Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: Text(message, style: const TextStyle(color: Colors.black54)),
      );

  void _goRelative(int delta) {
    if (_entries.isEmpty) return;
    final target = (_index + delta).clamp(0, _entries.length - 1);
    if (target == _index) return;
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _jumpTo(int target) {
    if (target < 0 || target >= _entries.length) return;
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _jumpToFirstVideo() {
    final videoIndex = _entries.indexWhere((entry) => entry.isVideo);
    if (videoIndex == -1) return;
    _pageController.animateToPage(
      videoIndex,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _openImageViewer(String source) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (dialogContext) {
        return Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(dialogContext),
              child: Container(
                color: Colors.transparent,
                alignment: Alignment.center,
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: _FullScreenImage(source: source),
                ),
              ),
            ),
            Positioned(
              top: 32,
              right: 16,
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(10),
                  shape: const CircleBorder(),
                ),
                icon: const Icon(Icons.close, size: 22),
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PetMediaEntry {
  final String source;

  final bool isVideo;

  const _PetMediaEntry({required this.source, required this.isVideo});
}

class _MediaDots extends StatelessWidget {
  final int count;

  final int index;

  const _MediaDots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == index ? 16 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(i == index ? 0.95 : 0.5),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class _MediaLabelChip extends StatelessWidget {
  final String label;

  const _MediaLabelChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }
}

class _MediaQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _MediaQuickAction(
      {required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ],
    );
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: content,
        ),
      ),
    );
  }
}

class _MediaThumbnails extends StatelessWidget {
  final List<_PetMediaEntry> entries;
  final int index;
  final ValueChanged<int> onTap;

  const _MediaThumbnails(
      {required this.entries, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 8),
              for (var i = 0; i < entries.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _MediaThumbTile(
                    entry: entries[i],
                    active: i == index,
                    onTap: () => onTap(i),
                  ),
                ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaThumbTile extends StatelessWidget {
  final _PetMediaEntry entry;
  final bool active;
  final VoidCallback onTap;

  const _MediaThumbTile(
      {required this.entry, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final src = entry.source;
    ImageProvider provider;
    if (src.startsWith('http')) {
      provider = NetworkImage(src);
    } else {
      final file = File(src);
      if (file.isAbsolute && file.existsSync()) {
        provider = FileImage(file);
      } else {
        provider = AssetImage(src);
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active ? Colors.white : Colors.transparent, width: 1.5),
          image: DecorationImage(image: provider, fit: BoxFit.cover),
        ),
        child: entry.isVideo
            ? Align(
                alignment: Alignment.topRight,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.play_arrow,
                      size: 14, color: Colors.white),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _FullScreenImage extends StatelessWidget {
  final String source;
  const _FullScreenImage({required this.source});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: const CircularProgressIndicator(color: Colors.white),
    );

    if (source.startsWith('http')) {
      return Image.network(
        source,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return placeholder;
        },
        errorBuilder: (_, __, ___) => _errorPlaceholder(),
      );
    }

    final file = File(source);
    if (file.isAbsolute && file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _errorPlaceholder(),
      );
    }

    return Image.asset(
      source.isEmpty ? kPetPlaceholderImage : source,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _errorPlaceholder(),
    );
  }

  Widget _errorPlaceholder() => Container(
        color: Colors.black,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: const Text(
          'Image not available',
          style: TextStyle(color: Colors.white70),
        ),
      );
}

class _ShareTarget extends StatelessWidget {
  final Widget icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareTarget(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final Alignment alignment;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  const _NavButton(
      {required this.alignment,
      required this.icon,
      required this.onTap,
      required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.black45,
          shape: const CircleBorder(),
          child: IconButton(
            onPressed: enabled ? onTap : null,
            icon: Icon(icon, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SectionCard(
      {required this.child, this.padding = const EdgeInsets.all(12)});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool multiline;

  const _InfoTile(
      {required this.icon,
      required this.label,
      required this.value,
      this.multiline = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade900,
                  ),
                  maxLines: multiline ? null : 2,
                  overflow:
                      multiline ? TextOverflow.visible : TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _priceChip(IconData icon, String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.teal.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.teal.withOpacity(0.2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.teal.shade700),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
              color: Colors.teal.shade800,
              fontWeight: FontWeight.w700,
              fontSize: 14),
        )
      ],
    ),
  );
}

class _HealthRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _HealthRow(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.teal.shade700, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.black54, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
