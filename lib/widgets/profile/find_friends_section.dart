import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
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
  List<UserModel> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchSuggestedUsers();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
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

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _runSearch(value.trim());
    });
  }

  Future<void> _runSearch(String query) async {
    setState(() => _isSearching = true);
    try {
      final service = Provider.of<SupabaseService>(context, listen: false);
      final results = await service.users.searchUsers(query);
      if (mounted && _searchQuery.trim() == query) {
        setState(() => _searchResults = results);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _searchResults = [];
      _isSearching = false;
    });
    _searchFocus.unfocus();
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
                    fontFamilyFallback: ['Naria'],
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: PinitColors.creamSunk,
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: PinitColors.creamDeep, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh_rounded,
                          size: 13, color: PinitColors.aubergine),
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

        // ── Search bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Container(
            decoration: BoxDecoration(
              color: PinitColors.cream,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: PinitColors.aubergine, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: PinitColors.aubergine,
                  blurRadius: 0,
                  offset: Offset(3, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                const Icon(FeatherIcons.search,
                    size: 16, color: PinitColors.aubergine),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: PinitColors.aubergine,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      border: InputBorder.none,
                      hintText: 'SEARCH PEOPLE',
                      hintStyle: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: PinitColors.aubergineSoft,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: _clearSearch,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.close_rounded,
                          size: 16, color: PinitColors.aubergineSoft),
                    ),
                  ),
              ],
            ),
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
    if (_searchQuery.trim().isNotEmpty) {
      if (_isSearching) {
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
      if (_searchResults.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              'No people found for "${_searchQuery.trim()}"',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: PinitColors.aubergineSoft,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      return Column(
        children: _searchResults
            .map((user) => Padding(
                  padding: const EdgeInsets.only(bottom: 16, right: 4),
                  child: UserCard(
                    user: user,
                    onTap: widget.onUserTap,
                  ),
                ))
            .toList(),
      );
    }

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
                fontFamilyFallback: ['Naria'],
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
      children: _suggestedUsers
          .map((user) => Padding(
                padding: const EdgeInsets.only(bottom: 16, right: 4),
                child: UserCard(
                  user: user,
                  onTap: widget.onUserTap,
                ),
              ))
          .toList(),
    );
  }
}
