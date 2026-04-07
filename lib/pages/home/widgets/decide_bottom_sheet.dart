import 'package:flutter/material.dart';
import 'package:login/themes/app_typography.dart';

/// Polished bottom sheet with decision shortcuts.
///
/// Consolidates the old Quick Actions (Magic Search, Just Decide, Sweet Treat)
/// into one refined decision tool.
class DecideBottomSheet extends StatelessWidget {
  final VoidCallback onQuickPicks;
  final VoidCallback onSweetTreat;
  final VoidCallback onSurpriseMe;

  const DecideBottomSheet({
    Key? key,
    required this.onQuickPicks,
    required this.onSweetTreat,
    required this.onSurpriseMe,
  }) : super(key: key);

  /// Show this sheet using the standard [showModalBottomSheet].
  static Future<void> show(
    BuildContext context, {
    required VoidCallback onQuickPicks,
    required VoidCallback onSweetTreat,
    required VoidCallback onSurpriseMe,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DecideBottomSheet(
        onQuickPicks: onQuickPicks,
        onSweetTreat: onSweetTreat,
        onSurpriseMe: onSurpriseMe,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Title ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'Decide',
                  style: AppTypography.brand(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Let us help you decide where to go',
              style: AppTypography.sans(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Actions ──
          _DecideOption(
            emoji: '⚡',
            label: 'Quick picks',
            subtitle: 'Swipe through nearby recommendations',
            onTap: () {
              Navigator.pop(context);
              onQuickPicks();
            },
          ),
          _DecideOption(
            emoji: '🍰',
            label: 'Sweet treat',
            subtitle: 'Find desserts and sweets near you',
            onTap: () {
              Navigator.pop(context);
              onSweetTreat();
            },
          ),
          _DecideOption(
            emoji: '🎲',
            label: 'Surprise me',
            subtitle: 'We\'ll pick something great for you',
            onTap: () {
              Navigator.pop(context);
              onSurpriseMe();
            },
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }
}

class _DecideOption extends StatelessWidget {
  final String emoji;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _DecideOption({
    required this.emoji,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.brand(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTypography.sans(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
