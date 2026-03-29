import 'package:flutter/material.dart';
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
    print('[RecentActivity] currentUser id: $userId');
    if (userId == null) {
      print('[RecentActivity] No user logged in, aborting fetch');
      setState(() => _loading = false);
      return;
    }

    try {
      print('[RecentActivity] Calling get_user_actions(user_id: $userId, limit: 5)');
      final response = await SupabaseClientManager().client.rpc(
        'get_user_actions',
        params: {'p_user_id': userId, 'p_limit': 5},
      );

      print('[RecentActivity] Raw response type: ${response.runtimeType}');
      print('[RecentActivity] Raw response: $response');

      final List<Map<String, dynamic>> actions =
          (response as List).cast<Map<String, dynamic>>();

      print('[RecentActivity] Parsed ${actions.length} actions');
      if (actions.isNotEmpty) {
        print('[RecentActivity] First action keys: ${actions.first.keys.toList()}');
        print('[RecentActivity] First action: ${actions.first}');
      }

      if (mounted) setState(() { _actions = actions; _loading = false; });
    } catch (e, stack) {
      print('[RecentActivity] Error fetching actions: $e');
      print('[RecentActivity] Stack: $stack');
      if (mounted) setState(() { _actions = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final actions = _actions ?? [];
    if (actions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 32, 20, 16),
          child: Text(
            'Recent',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: PinitColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: actions.map((action) => _ActivityItem(action: action)).toList(),
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
        return _ActionMeta(
          icon: Icons.bookmark_rounded,
          iconColor: PinitColors.primary,
          bgColor: PinitColors.primary,
        );
      case 'like':
        return _ActionMeta(
          icon: Icons.favorite_rounded,
          iconColor: const Color(0xFFE85D4C),
          bgColor: const Color(0xFFE85D4C),
        );
      case 'dislike':
        return _ActionMeta(
          icon: Icons.thumb_down_rounded,
          iconColor: PinitColors.textSecondary,
          bgColor: PinitColors.textMuted,
        );
      case 'visit':
        return _ActionMeta(
          icon: Icons.place_rounded,
          iconColor: const Color(0xFF34A853),
          bgColor: const Color(0xFF34A853),
        );
      case 'bubble_save':
        return _ActionMeta(
          icon: Icons.group_rounded,
          iconColor: const Color(0xFF5B4DC7),
          bgColor: const Color(0xFF5B4DC7),
        );
      default:
        return _ActionMeta(
          icon: Icons.push_pin_outlined,
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
    print('[RecentActivity] actionType=$actionType placeName="$placeName" keys=${action.keys.toList()}');
    final timeAgo = _timeAgo(action['created_at']);
    final bubbleName = action['bubble_name']?.toString() ?? '';
    final meta = _meta(actionType);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
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
              color: meta.bgColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(meta.icon, size: 18, color: meta.iconColor),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: _buildActivityText(actionType, placeName, bubbleName)),
          Text(
            timeAgo,
            style: const TextStyle(fontSize: 13, color: PinitColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityText(String actionType, String placeName, String bubbleName) {
    final TextSpan nameSpan = TextSpan(
      text: placeName,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        color: PinitColors.textPrimary,
      ),
    );

    final TextSpan bubbleNameSpan = TextSpan(
      text: ' "$bubbleName"',
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        color: PinitColors.textPrimary,
      ),
    );

    const base = TextStyle(
      fontSize: 14,
      color: PinitColors.textSecondary,
      height: 1.3,
    );

    late List<InlineSpan> children;

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
          bubbleNameSpan,
          
        ];
        break;
      default:
        children = [const TextSpan(text: 'Pinned '), nameSpan];
    }

    return RichText(
      text: TextSpan(style: base, children: children),
    );
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
