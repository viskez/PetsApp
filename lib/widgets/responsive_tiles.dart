import 'package:flutter/material.dart';

/// Lays out card-like tiles in as many columns as the screen width allows,
/// automatically wrapping to additional rows to avoid horizontal overflow.
class ResponsiveTileWrap extends StatelessWidget {
  final List<Widget> tiles;
  final double spacing;
  final double runSpacing;
  final double maxTileWidth;

  const ResponsiveTileWrap({
    super.key,
    required this.tiles,
    this.spacing = 12,
    this.runSpacing = 12,
    this.maxTileWidth = 170,
  });

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final safeWidth = width > 0 ? width : MediaQuery.of(context).size.width;
        final targetWidth = maxTileWidth <= 0 ? 170 : maxTileWidth;

        var columns = (safeWidth / targetWidth).floor();
        if (columns < 1) columns = 1;
        if (columns > tiles.length) columns = tiles.length;

        final horizontalSpacing = spacing * (columns - 1);
        final tileWidth = (safeWidth - horizontalSpacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: tiles
              .map((tile) => SizedBox(
                    width: tileWidth,
                    child: tile,
                  ))
              .toList(),
        );
      },
    );
  }
}

/// Places form tiles (dropdowns, switches, etc.) in a row on wide screens
/// and stacks them vertically when horizontal space is tight.
class ResponsiveTileRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double breakpoint;
  final CrossAxisAlignment crossAxisAlignment;

  const ResponsiveTileRow({
    super.key,
    required this.children,
    this.spacing = 12,
    this.breakpoint = 520,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final stacked = width < breakpoint;

        if (stacked) {
          return Column(
            crossAxisAlignment: crossAxisAlignment,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                SizedBox(width: double.infinity, child: children[i]),
                if (i != children.length - 1) SizedBox(height: spacing),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: crossAxisAlignment,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1) SizedBox(width: spacing),
            ],
          ],
        );
      },
    );
  }
}
