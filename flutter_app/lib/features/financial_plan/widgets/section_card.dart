import 'package:flutter/material.dart';

/// Common shell for every section in the financial plan: a colored header
/// strip with title + index, optional subtitle, body and footnote. Mirrors
/// the look from the PDF reference.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.index,
    required this.title,
    this.caption,
    this.footnote,
    required this.color,
    required this.child,
  });

  final int index;
  final String title;
  final String? caption;
  final String? footnote;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onColor = ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: color,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$index. $title',
                    style: TextStyle(
                      color: onColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (caption != null && caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                caption!,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
            child: child,
          ),
          if (footnote != null && footnote!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                footnote!,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
