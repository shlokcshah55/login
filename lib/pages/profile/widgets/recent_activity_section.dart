import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:login/supabase/supabase_client.dart';
import 'pinit_colors.dart';

class RecentActivitySection extends StatefulWidget {
  const RecentActivitySection({Key? key}) : super(key: key);

  @override
  State<RecentActivitySection> createState() => _RecentActivitySectionState();
}

class _RecentActivitySectionState extends State<RecentActivitySection> {
  List<Map<String, dynamic>>? _actions;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchActions();
  }

  Future<void> _fetchActions() async {
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final response = await SupabaseClientManager().client.rpc(
        'get_user_actions',
        params: {'p_user_id': userId, 'p_limit': 5},
      );
      final List<Map<String, dynamic>> actions =
          (response as List).cast<Map<String, dynamic>>();
      if (mounted) {
        setState(() {
          _actions = actions;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _actions = [];
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: PinitColors.primary,
          ),
        ),
      );
    }

    final actions = _actions ?? [];
    if (actions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: PinitColors.surfaceLight,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  FeatherIcons.clock,
                  size: 17,
                  color: PinitColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Recent',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: PinitColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),

        // ── Items ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: actions
                .map((action) => _ActivityItem(action: action))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final Map<String, dynamic> action;
  const _ActivityItem({required this.action});

  String _timeAgo(dynamic createdAt) {
    if (createdAt == null) return '';
    final dt = DateTime.tryParse(createdAt.toString());
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  _ActionMeta _meta(String actionType) {
    switch (actionType) {
      case 'save':
        return const _ActionMeta(
          icon: FeatherIcons.bookmark,
          iconColor: PinitColors.primary,
          bgColor: PinitColors.primary,
        );
      case 'like':
        return const _ActionMeta(
          icon: FeatherIcons.heart,
          iconColor: Color(0xFFE85D4C),
          bgColor: Color(0xFFE85D4C),
        );
      case 'dislike':
        return const _ActionMeta(
          icon: FeatherIcons.thumbsDown,
          iconColor: PinitColors.textSecondary,
          bgColor: PinitColors.textMuted,
        );
      case 'visit':
        return const _ActionMeta(
          icon: FeatherIcons.mapPin,
          iconColor: Color(0xFF34A853),
          bgColor: Color(0xFF34A853),
        );
      case 'bubble_save':
        return const _ActionMeta(
          icon: FeatherIcons.users,
          iconColor: Color(0xFF5B4DC7),
          bgColor: Color(0xFF5B4DC7),
        );
      default:
        return const _ActionMeta(
          icon: FeatherIcons.mapPin,
          iconColor: PinitColors.primary,
          bgColor: PinitColors.primary,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionType = action['action_type']?.toString() ?? '';
    final placeName = action['location_name']?.toString() ??
        action['place_name']?.toString() ??
        action['name']?.toString() ??
        '';
    final timeAgo = _timeAgo(action['created_at']);
    final bubbleName = action['bubble_name']?.toString() ?? '';
    final meta = _meta(actionType);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: PinitColors.surfaceLight, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: meta.bgColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(meta.icon, size: 16, color: meta.iconColor),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: _buildActivityText(actionType, placeName, bubbleName)),
          Text(
            timeAgo,
            style: const TextStyle(
                fontSize: 12, color: PinitColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityText(
      String actionType, String placeName, String bubbleName) {
    final nameSpan = TextSpan(
      text: placeName,
      style: const TextStyle(
          fontWeight: FontWeight.w600, color: PinitColors.textPrimary),
    );
    final bubbleSpan = TextSpan(
      text: ' "$bubbleName"',
      style: const TextStyle(
          fontWeight: FontWeight.w600, color: PinitColors.textPrimary),
    );
    const base = TextStyle(
        fontSize: 14, color: PinitColors.textSecondary, height: 1.3);

    final List<InlineSpan> children;
    switch (actionType) {
      case 'save':
        children = [const TextSpan(text: 'You saved '), nameSpan];
        break;
      case 'like':
        children = [const TextSpan(text: 'You liked '), nameSpan];
        break;
      case 'dislike':
        children = [const TextSpan(text: 'You passed on '), nameSpan];
        break;
      case 'visit':
        children = [const TextSpan(text: 'You visited '), nameSpan];
        break;
      case 'bubble_save':
        children = [
          const TextSpan(text: 'Added '),
          nameSpan,
          const TextSpan(text: ' to bubble'),
          bubbleSpan,
        ];
        break;
      default:
        children = [const TextSpan(text: 'Pinned '), nameSpan];
    }

    return RichText(text: TextSpan(style: base, children: children));
  }
}

class _ActionMeta {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  const _ActionMeta({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
  });
}
