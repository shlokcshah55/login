import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:login/models/users.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/supabase/service.dart';
import 'package:login/widgets/profile/user_card.dart';
import 'package:provider/provider.dart';

class FindFriendsSection extends StatefulWidget {
  final ThemeData theme;
  final Function(UserModel)? onUserTap;

  const FindFriendsSection({
    Key? key,
    required this.theme,
    this.onUserTap,
  }) : super(key: key);

  @override
  State<FindFriendsSection> createState() => _FindFriendsSectionState();
}

class _FindFriendsSectionState extends State<FindFriendsSection> {
  List<UserModel> _suggestedUsers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchSuggestedUsers();
  }

  Future<void> _fetchSuggestedUsers() async {
    setState(() => _isLoading = true);
    try {
      final service = Provider.of<SupabaseService>(context, listen: false);
      final users = await service.users.getSuggestedUsers();
      if (mounted) setState(() => _suggestedUsers = users);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
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
                  FeatherIcons.users,
                  size: 17,
                  color: PinitColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Find Friends',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: PinitColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'People with similar taste',
                      style: TextStyle(
                        fontSize: 13,
                        color: PinitColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Content ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          color: PinitColors.primary,
        ),
      );
    }

    if (_suggestedUsers.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: PinitColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: PinitColors.cardShadow,
        ),
        child: const Column(
          children: [
            Icon(
              FeatherIcons.users,
              size: 40,
              color: PinitColors.textMuted,
            ),
            SizedBox(height: 14),
            Text(
              'No suggestions yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: PinitColors.textPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Check back later for recommendations',
              style: TextStyle(
                fontSize: 13,
                color: PinitColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final cardWidth =
        (MediaQuery.of(context).size.width - 20 * 2 - 12) / 2;

    return SizedBox(
      height: cardWidth / 0.7,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _suggestedUsers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => SizedBox(
          width: cardWidth,
          child: UserCard(
            user: _suggestedUsers[index],
            onTap: widget.onUserTap,
          ),
        ),
      ),
    );
  }
}
