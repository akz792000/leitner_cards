import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:leitner_cards/entity/card_entity.dart';

/// Draggable modal bottom sheet showing a card's optional description text.
///
/// Call [DescriptionSheet.show] from a button in [LeitnerScreen]; the static
/// helper keeps each call site to one line while ensuring the sheet is always
/// presented with consistent sizing and rounding.
class DescriptionSheet extends StatelessWidget {
  final CardEntity card;

  const DescriptionSheet({
    super.key,
    required this.card,
  });

  static Future<void> show(
    BuildContext context, {
    required CardEntity card,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DescriptionSheet(card: card),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          // Drag handle
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Icon(Icons.notes_rounded, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Description',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          Divider(height: 24, color: colorScheme.outlineVariant),

          // Description — rendered as Markdown so bold, lists, tables etc. work.
          MarkdownBody(
            data: card.desc,
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              p: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface,
                height: 1.7,
              ),
              strong: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                height: 1.7,
              ),
              tableHead: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
              tableBody: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
              tableBorder: TableBorder.all(
                color: colorScheme.outlineVariant,
                width: 1,
              ),
              blockquoteDecoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
                border: Border(
                    left: BorderSide(color: colorScheme.primary, width: 3)),
              ),
            ),
            selectable: true,
          ),
        ],
      ),
    );
  }
}
