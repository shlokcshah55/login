import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
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
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Text(
                  'People',
                  style: TextStyle(
                    fontFamily: 'Rova',
                    fontSize: 28,
                    fontWeight: FontWeight.w100,
                    color: PinitColors.aubergine,
                    letterSpacing: 1.4,
                    height: 1.05,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _fetchSuggestedUsers();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: PinitColors.creamSunk,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: PinitColors.creamDeep, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh_rounded, size: 13, color: PinitColors.aubergine),
                      const SizedBox(width: 5),
                      Text(
                        'Refresh',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: PinitColors.aubergine,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Content ──
        Padding(
          padding: const EdgeInsets.only(left: 24, right: 20),
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: PinitColors.aubergine,
          ),
        ),
      );
    }

    if (_suggestedUsers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            SvgPicture.asset(
              'lib/assets/illustrations/Beep Beep - Food Van.svg',
              height: 160,
            ),
            const SizedBox(height: 20),
            const Text(
              'No one around yet...',
              style: TextStyle(
                fontFamily: 'Rova',
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: PinitColors.aubergine,
                letterSpacing: 1.0,
                height: 1.05,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for people with similar taste to you.',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: PinitColors.aubergineSoft,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: _suggestedUsers.map((user) => Padding(
        padding: const EdgeInsets.only(bottom: 16, right: 4),
        child: UserCard(
          user: user,
          onTap: widget.onUserTap,
        ),
      )).toList(),
    );
  }
}
