import 'dart:math' as math;
import 'package:flutter/material.dart';

class RoundedFooterNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final String profileLabel;

  const RoundedFooterNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.profileLabel,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = <_NavSpec>[
      const _NavSpec(label: 'Pets', asset: 'assets/icons/pets.png'),
      const _NavSpec(label: 'Buy', asset: 'assets/icons/buy.png'),
      const _NavSpec(label: 'Sell', asset: 'assets/icons/sell.png'),
      const _NavSpec(label: 'Help', asset: 'assets/icons/help.png'),
      _NavSpec(
        label: profileLabel.length > 4
            ? '${profileLabel.substring(0, 4)}…'
            : profileLabel,
        iconData: Icons.person,
      ),
    ];
    final Color accent = Theme.of(context).colorScheme.primary;
    final Color navBackground = accent;
    final Color highlightColor = Colors.white;

    Widget item(int index, _NavSpec spec) {
      final bool selected = currentIndex == index;
      final Color color = selected ? accent : const Color.fromARGB(255, 255, 255, 255);

      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onTap(index),
            borderRadius: BorderRadius.circular(16),
            child: SizedBox.expand(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (spec.iconData != null)
                    Icon(spec.iconData, color: color, size: 22)
                  else
                    ImageIcon(AssetImage(spec.asset!), color: color, size: 22),
                  const SizedBox(height: 4),
                  Text(
                    spec.label,
                    style: TextStyle(
                      color: color,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: navBackground,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: navBackground.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double slotWidth = constraints.maxWidth / tabs.length;
              final double highlightWidth = math.max(slotWidth - 12, 48);
              final double highlightHeight = constraints.maxHeight - 12;
              final double baseLeft = currentIndex * slotWidth + (slotWidth - highlightWidth) / 2;
              final double left = baseLeft.clamp(0.0, constraints.maxWidth - highlightWidth);
              final double top = (constraints.maxHeight - highlightHeight) / 2;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 100),
                    curve: Curves.easeOutQuint,
                    left: left,
                    top: top,
                    width: highlightWidth,
                    height: highlightHeight,
                    child: _HighlightCard(color: highlightColor),
                  ),
                  Row(
                    children: [
                      for (int i = 0; i < tabs.length; i++) item(i, tabs[i]),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final Color color;
  const _HighlightCard({required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }
}

class _NavSpec {
  final String label;
  final String? asset;
  final IconData? iconData;
  const _NavSpec({required this.label, this.asset, this.iconData});
}
