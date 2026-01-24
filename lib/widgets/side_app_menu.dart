import 'package:flutter/material.dart';

class SideMenuItem<T> {
  final IconData icon;
  final String label;
  final T value;
  final Color? iconColor;

  const SideMenuItem({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });
}

Future<T?> showSideAppMenu<T>({
  required BuildContext context,
  required List<SideMenuItem<T>> items,
  required String headline,
  String? subtitle,
  String? caption,
  ImageProvider? avatarImage,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierLabel: 'App menu',
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) {
      final size = MediaQuery.of(context).size;
      return Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: size.width * 0.8,
          height: size.height,
          child: _SideMenuPanel<T>(
            items: items,
            headline: headline,
            subtitle: subtitle ?? '',
            caption: caption ?? '',
            avatarImage: avatarImage,
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(-0.15, 0), end: Offset.zero)
              .animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _SideMenuPanel<T> extends StatelessWidget {
  final List<SideMenuItem<T>> items;
  final String headline;
  final String subtitle;
  final String caption;
  final ImageProvider? avatarImage;

  const _SideMenuPanel({
    required this.items,
    required this.headline,
    required this.subtitle,
    required this.caption,
    this.avatarImage,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = _menuGradient(Theme.of(context).colorScheme.primary);
    final textColor = Colors.white.withValues(alpha: 0.95);
    final mutedText = Colors.white.withValues(alpha: 0.75);

    SideMenuItem<T>? logoutItem;
    final menuItems = <SideMenuItem<T>>[];
    for (final item in items) {
      if (item.label.toLowerCase().contains('logout')) {
        logoutItem = item;
      } else {
        menuItems.add(item);
      }
    }

    return Material(
      color: Colors.transparent,
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        child: SafeArea(
          minimum: EdgeInsets.zero,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 24,
                  offset: const Offset(8, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 10, 14),
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        child: IconButton(
                          tooltip: 'Back',
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              Navigator.of(context, rootNavigator: true).pop(),
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white),
                        ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.topCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 38,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.22),
                              child: CircleAvatar(
                                radius: 34,
                                backgroundColor: Colors.white,
                                backgroundImage: avatarImage,
                                foregroundColor: const Color(0xFF1C8D83),
                                child: avatarImage != null
                                    ? null
                                    : Text(
                                        _initials(headline),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 20,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              headline,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            if (caption.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                caption,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: mutedText,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: mutedText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(color: Colors.white24, height: 1),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                    itemCount: menuItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = menuItems[index];
                      return _MenuTile<T>(
                        item: item,
                        textColor: textColor,
                        mutedText: mutedText,
                      );
                    },
                  ),
                ),
                if (logoutItem != null)
                  Container(
                    width: double.infinity,
                    color: Colors.white.withValues(alpha: 0.14),
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
                    child: _MenuTile<T>(
                      item: logoutItem!,
                      textColor: textColor,
                      mutedText: mutedText,
                      highlight: true,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'P';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}

LinearGradient _menuGradient(Color primary) {
  Color adjust(double delta) {
    final hsl = HSLColor.fromColor(primary);
    final lightness = (hsl.lightness + delta).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  final start = adjust(-0.08);
  final mid = primary;
  final end = adjust(0.08);

  return LinearGradient(
    colors: [start, mid, end],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class _MenuTile<T> extends StatelessWidget {
  final SideMenuItem<T> item;
  final Color textColor;
  final Color mutedText;
  final bool highlight;

  const _MenuTile({
    required this.item,
    required this.textColor,
    required this.mutedText,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(item.value),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 20,
                color: item.iconColor ?? Colors.white,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
