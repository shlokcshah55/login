import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recent',
                style: TextStyle(
                  fontFamily: 'Rova',
                  fontSize: 28,
                  fontWeight: FontWeight.w100,
                  color: PinitColors.aubergine,
                  letterSpacing: 1.9,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your latest activity',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: PinitColors.aubergineSoft,
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
        return const _ActionMeta(label: 'SAVED', accentColor: PinitColors.primary);
      case 'like':
        return const _ActionMeta(label: 'LIKED', accentColor: Color(0xFFE85D4C));
      case 'dislike':
        return const _ActionMeta(label: 'PASSED', accentColor: PinitColors.textMuted);
      case 'visit':
        return const _ActionMeta(label: 'VISITED', accentColor: Color(0xFF34A853));
      case 'bubble_save':
        return const _ActionMeta(label: 'PINNED TO BUBBLE', accentColor: Color(0xFF5B4DC7));
      default:
        return const _ActionMeta(label: 'PINNED', accentColor: PinitColors.primary);
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
      margin: const EdgeInsets.only(bottom: 10),
      decoration: const BoxDecoration(
        color: PinitColors.cream,
        border: Border.fromBorderSide(
          BorderSide(color: PinitColors.aubergine, width: 1.5),
        ),
        borderRadius: BorderRadius.all(Radius.circular(10)),
        boxShadow: [
          BoxShadow(
            color: PinitColors.aubergine,
            blurRadius: 0,
            offset: Offset(4, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.5),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar
              Container(width: 3, color: meta.accentColor),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            meta.label,
                            style: GoogleFonts.dmSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                              color: meta.accentColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            placeName,
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: PinitColors.aubergine,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (bubbleName.isNotEmpty && actionType == 'bubble_save')
                            Text(
                              bubbleName,
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: PinitColors.aubergineSoft,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      timeAgo,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: PinitColors.mute,
                      ),
                    ),
                  ],
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

class _ActionMeta {
  final String label;
  final Color accentColor;
  const _ActionMeta({
    required this.label,
    required this.accentColor,
  });
}
