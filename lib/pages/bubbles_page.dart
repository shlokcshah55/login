import 'dart:async';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/users.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:provider/provider.dart';
import 'package:login/models/bubble.dart';
import 'package:login/widgets/chat/chat_group_tile.dart';
import 'package:login/widgets/chat/expanded_bubble_view.dart';
import 'package:login/services/analytics_service.dart';
import 'package:login/supabase/service.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:login/providers/bubbles_provider.dart';
import 'package:login/providers/bubble_mode_provider.dart';
import 'package:login/providers/navigation_provider.dart';
import 'package:login/pages/bubble_messaging_page.dart';
import 'package:login/pages/profile/other_user_profile_page.dart';
import 'package:login/utils/route_open_guard.dart';
import 'package:login/widgets/chat/bubble_discover_view.dart';
import 'package:login/widgets/feedback/app_feedback.dart';
import 'package:login/widgets/profile/user_card.dart';

class BubblesPage extends StatefulWidget {
  const BubblesPage({Key? key}) : super(key: key);

  @override
  _BubblesPageState createState() => _BubblesPageState();
}

class _BubblesPageState extends State<BubblesPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late BubblesProvider _bubblesProvider;

  // Search related state
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<UserModel> _searchResults = [];
  List<UserModel> _suggestedUsers = [];
  bool _isSearching = false;
  bool _isLoadingSuggestedUsers = false;
  Timer? _debounceTimer;
  final AnalyticsService _analyticsService = AnalyticsService();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);

    // Initialize BubblesProvider
    final currentUser = SupabaseClientManager().client.auth.currentUser;
    if (currentUser != null) {
      final supabaseProvider =
          Provider.of<SupabaseService>(context, listen: false);
      _bubblesProvider = BubblesProvider(
        userId: currentUser.id,
        bubbleHelper: supabaseProvider.bubbles,
      );
      _bubblesProvider.initialize();
      _fetchSuggestedUsers();
    }
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    _bubblesProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool showingSearch =
        _searchFocusNode.hasFocus || _searchController.text.isNotEmpty;

    return ChangeNotifierProvider.value(
      value: _bubblesProvider,
      child: Consumer<BubblesProvider>(
        builder: (context, bubblesProvider, child) {
          return Scaffold(
            backgroundColor: PinitColors.cream,
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  if (!showingSearch) _buildModernHeader(theme),
                  _buildSearchField(theme),
                  Expanded(
                    child: showingSearch
                        ? _buildSearchResults(theme, bubblesProvider.bubbles)
                        : bubblesProvider.isLoading
                            ? _buildLoadingState(theme)
                            : _buildBubblesList(theme, bubblesProvider),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Animated bubble icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: PinitColors.aubergine,
              borderRadius: BorderRadius.circular(999),
              boxShadow: PinitColors.cardShadow,
            ),
            child: const Icon(
              Icons.bubble_chart_rounded,
              color: PinitColors.cream,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bubbles',
                  style: TextStyle(
                    fontFamily: 'Rova',
                    fontSize: 28,
                    fontWeight: FontWeight.w100,
                    color: PinitColors.aubergine,
                    letterSpacing: 1.7,
                    height: 1.05,
                  ),
                ),
                Text(
                  'Your shared spaces',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: PinitColors.mute,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          // Refresh button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _refreshBubbles,
              borderRadius: BorderRadius.circular(999),
              child: Ink(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: PinitColors.aubergine.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: PinitColors.creamDeep, width: 1.5),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: PinitColors.aubergine,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Create bubble button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showCreateBubbleDialog,
              borderRadius: BorderRadius.circular(999),
              child: Ink(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: PinitColors.aubergine.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: PinitColors.creamDeep, width: 1.5),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: PinitColors.aubergine,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshBubbles() async {
    await Future.wait([
      _bubblesProvider.loadBubbles(),
      _fetchSuggestedUsers(),
    ]);
    if (!mounted) return;
    AppFeedback.showSuccess(
      context,
      message: 'Bubbles refreshed',
      leading: const Icon(
        Icons.refresh_rounded,
        color: PinitColors.cream,
        size: 18,
      ),
      duration: const Duration(seconds: 1),
    );
  }

  Future<void> _fetchSuggestedUsers() async {
    if (_isLoadingSuggestedUsers) return;
    if (mounted) {
      setState(() => _isLoadingSuggestedUsers = true);
    }

    try {
      final service = Provider.of<SupabaseService>(context, listen: false);
      final users = await service.users.getSuggestedUsers();
      if (mounted) {
        setState(() => _suggestedUsers = users);
      }
    } catch (_) {
      // Suggestions are ambient; keep the empty state useful if they fail.
    } finally {
      if (mounted) {
        setState(() => _isLoadingSuggestedUsers = false);
      }
    }
  }

  void _showCreateBubbleDialog() {
    final TextEditingController nameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        List<UserModel> friends = [];
        Set<String> selectedIds = {};
        bool loadingFriends = true;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            // Load friends once
            if (loadingFriends && friends.isEmpty) {
              Provider.of<SupabaseService>(context, listen: false)
                  .users
                  .getFriends()
                  .then((result) {
                setSheetState(() {
                  friends = result;
                  loadingFriends = false;
                });
              });
            }

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: PinitColors.cream,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: PinitColors.creamDeep,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Create New Bubble',
                      style: TextStyle(
                        fontFamily: 'Rova',
                        fontSize: 22,
                        fontWeight: FontWeight.w100,
                        color: PinitColors.aubergine,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a shared space for your group',
                      style: GoogleFonts.dmSans(
                          fontSize: 14, color: PinitColors.mute),
                    ),
                    const SizedBox(height: 24),
                    // Name field
                    TextField(
                      controller: nameController,
                      style: GoogleFonts.dmSans(color: PinitColors.aubergine),
                      decoration: InputDecoration(
                        hintText: 'Bubble name',
                        labelText: 'Name',
                        hintStyle: GoogleFonts.dmSans(color: PinitColors.mute),
                        labelStyle: GoogleFonts.dmSans(
                            color: PinitColors.aubergineSoft),
                        floatingLabelStyle: GoogleFonts.dmSans(
                          color: PinitColors.aubergine,
                          fontWeight: FontWeight.w600,
                        ),
                        prefixIcon: const Icon(Icons.bubble_chart_rounded,
                            color: PinitColors.aubergineSoft),
                        filled: true,
                        fillColor: PinitColors.creamSunk,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(
                              color: PinitColors.creamDeep, width: 1),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(
                              color: PinitColors.creamDeep, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(
                              color: PinitColors.aubergine, width: 1.5),
                        ),
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 20),
                    // Quick add friends section
                    Row(
                      children: [
                        const Icon(Icons.people_outline_rounded,
                            size: 16, color: PinitColors.aubergineSoft),
                        const SizedBox(width: 6),
                        Text(
                          'Quick add friends',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: PinitColors.aubergineSoft,
                          ),
                        ),
                        if (selectedIds.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: PinitColors.aubergine,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              '${selectedIds.length}',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: PinitColors.cream,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (loadingFriends)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  PinitColors.aubergineSoft),
                            ),
                          ),
                        ),
                      )
                    else if (friends.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No friends to add yet',
                          style: GoogleFonts.dmSans(
                              fontSize: 13, color: PinitColors.mute),
                        ),
                      )
                    else
                      SizedBox(
                        height: 80,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: friends.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final friend = friends[index];
                            final id = friend.supabaseId ?? '';
                            final selected = selectedIds.contains(id);
                            return GestureDetector(
                              onTap: () {
                                setSheetState(() {
                                  if (selected) {
                                    selectedIds.remove(id);
                                  } else {
                                    selectedIds.add(id);
                                  }
                                });
                              },
                              child: Column(
                                children: [
                                  Stack(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: selected
                                                ? PinitColors.aubergine
                                                : Colors.transparent,
                                            width: 2.5,
                                          ),
                                        ),
                                        child: ClipOval(
                                          child: friend.profileImageUrl != null
                                              ? Image.network(
                                                  friend.profileImageUrl!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      _friendFallbackAvatar(
                                                          friend),
                                                )
                                              : _friendFallbackAvatar(friend),
                                        ),
                                      ),
                                      if (selected)
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            width: 18,
                                            height: 18,
                                            decoration: const BoxDecoration(
                                              color: PinitColors.aubergine,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.check_rounded,
                                              size: 12,
                                              color: PinitColors.cream,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    width: 52,
                                    child: Text(
                                      friend.username?.isNotEmpty == true
                                          ? friend.username!
                                          : (friend.name ?? ''),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 11,
                                        color: selected
                                            ? PinitColors.aubergine
                                            : PinitColors.mute,
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 24),
                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                              side: const BorderSide(
                                  color: PinitColors.creamDeep),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.dmSans(
                                color: PinitColors.mute,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (nameController.text.trim().isEmpty) return;

                              final supabaseProvider =
                                  Provider.of<SupabaseService>(context,
                                      listen: false);
                              final currentUser = SupabaseClientManager()
                                  .client
                                  .auth
                                  .currentUser;

                              if (currentUser == null) return;

                              final bubbleId =
                                  await supabaseProvider.bubbles.createBubble(
                                name: nameController.text.trim(),
                                createdBy: currentUser.id,
                              );

                              if (bubbleId != null && selectedIds.isNotEmpty) {
                                await Future.wait(selectedIds.map((uid) =>
                                    supabaseProvider.bubbles.addMemberToBubble(
                                      bubbleId: bubbleId,
                                      userId: uid,
                                    )));
                              }

                              Navigator.of(context).pop();

                              if (bubbleId != null) {
                                AppFeedback.showSuccess(
                                  context,
                                  message: selectedIds.isNotEmpty
                                      ? 'Bubble created with ${selectedIds.length} friend${selectedIds.length == 1 ? '' : 's'}'
                                      : 'Bubble created',
                                  duration: const Duration(seconds: 2),
                                );
                              } else {
                                unawaited(
                                  AppFeedback.showError(
                                    context,
                                    title: "Couldn't create bubble",
                                    message: 'Please try again in a moment.',
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PinitColors.aubergine,
                              foregroundColor: PinitColors.cream,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_rounded,
                                    size: 18, color: PinitColors.cream),
                                const SizedBox(width: 8),
                                Text('Create Bubble',
                                    style: GoogleFonts.dmSans(
                                        fontWeight: FontWeight.w600,
                                        color: PinitColors.cream)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _friendFallbackAvatar(UserModel friend) {
    final initials = (friend.name?.isNotEmpty == true
            ? friend.name![0]
            : friend.username?.isNotEmpty == true
                ? friend.username![0]
                : '?')
        .toUpperCase();
    return Container(
      color: PinitColors.creamSunk,
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: PinitColors.aubergineSoft,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: PinitColors.creamSunk,
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(PinitColors.aubergine),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading your bubbles...',
            style: GoogleFonts.dmSans(
              color: PinitColors.mute,
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubblesList(ThemeData theme, BubblesProvider bubblesProvider) {
    final bubbles = bubblesProvider.bubbles;
    if (bubbles.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await _bubblesProvider.loadBubbles();
        },
        color: PinitColors.aubergine,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: _buildEmptyState(theme),
            ),
          ],
        ),
      );
    }

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: () async {
            await _bubblesProvider.loadBubbles();
          },
          color: PinitColors.aubergine,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: bubbles.length,
            itemBuilder: (context, index) {
              final bubble = bubbles[index];
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 300 + (index * 80)),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, 16 * (1 - value)),
                    child: Opacity(opacity: value, child: child),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ChatGroupTile(
                    key: ValueKey(bubble.id),
                    bubble: bubble,
                    onTap: () => _openExpandedChatView(bubble),
                    onOpenChat: () => _openGroupChat(bubble),
                    onActivateBubble: () => _activateBubble(bubble),
                    onDelete: bubble.createdBy == bubblesProvider.userId
                        ? () => _confirmAndDeleteBubble(bubblesProvider, bubble)
                        : null,
                    onRename: bubble.createdBy == bubblesProvider.userId
                        ? () => _promptAndRenameBubble(bubblesProvider, bubble)
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return RefreshIndicator(
      color: PinitColors.aubergine,
      backgroundColor: PinitColors.cream,
      onRefresh: _refreshBubbles,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(32, 16, 32, 36),
        children: [
          Column(
            children: [
              // Animated illustration
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: PinitColors.creamSunk,
                  shape: BoxShape.circle,
                  border: Border.all(color: PinitColors.creamDeep, width: 1.5),
                ),
                child: const Icon(
                  Icons.bubble_chart_rounded,
                  size: 56,
                  color: PinitColors.aubergineSoft,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'No Bubbles Yet',
                style: TextStyle(
                  fontFamily: 'Rova',
                  fontSize: 22,
                  fontWeight: FontWeight.w100,
                  color: PinitColors.aubergine,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Create your first bubble to start sharing\nplaces with your friends!',
                style: GoogleFonts.dmSans(
                  color: PinitColors.mute,
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _showCreateBubbleDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PinitColors.aubergine,
                  foregroundColor: PinitColors.cream,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded,
                        size: 18, color: PinitColors.cream),
                    const SizedBox(width: 8),
                    Text(
                      'Create Your First Bubble',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w600,
                        color: PinitColors.cream,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              _buildRecommendedPeopleSection(theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedPeopleSection(ThemeData theme) {
    if (_isLoadingSuggestedUsers && _suggestedUsers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: PinitColors.aubergine,
          ),
        ),
      );
    }

    if (_suggestedUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Find Friends',
          style: TextStyle(
            fontFamily: 'Rova',
            fontSize: 22,
            fontWeight: FontWeight.w100,
            color: PinitColors.aubergine,
            letterSpacing: 1.0,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 12),
        ..._suggestedUsers.map(
          (user) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: UserCard(
              user: user,
              onTap: _showUserProfileDialog,
            ),
          ),
        ),
      ],
    );
  }

  void _openExpandedChatView(Bubble bubble) {
    _analyticsService.trackFeature(
      'bubble_opened',
      featureName: 'bubble',
      screenName: 'bubbles',
      properties: <String, dynamic>{
        'bubble_id': bubble.id,
        'open_target': 'expanded',
      },
      registerTap: true,
      interactionKey: 'bubble_opened',
    );
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ExpandedChatView(
        bubble: bubble,
        onClose: () => Navigator.of(context).pop(),
        onOpenChat: () => _openBubbleMessagingPage(bubble),
        onOpenPinsChat: () => _openBubbleMessagingPage(
          bubble,
          initialView: BubbleMessageView.pins,
        ),
      ),
    );
  }

  void _openGroupChat(Bubble bubble) {
    _analyticsService.trackFeature(
      'bubble_opened',
      featureName: 'bubble',
      screenName: 'bubbles',
      properties: <String, dynamic>{
        'bubble_id': bubble.id,
        'open_target': 'chat',
      },
      registerTap: true,
      interactionKey: 'bubble_opened',
    );
    _openBubbleMessagingPage(bubble);
  }

  Future<void> _openBubbleMessagingPage(
    Bubble bubble, {
    BubbleMessageView initialView = BubbleMessageView.messages,
  }) async {
    _bubblesProvider.markBubbleReadLocally(bubble.id);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BubbleMessagingPage(
          bubble: bubble.copyWith(unreadCount: 0),
          initialView: initialView,
        ),
      ),
    );
  }

  Future<void> _activateBubble(Bubble bubble) async {
    final effectiveMemberCount = bubble.memberCount > bubble.memberIds.length
        ? bubble.memberCount
        : bubble.memberIds.length;

    if (effectiveMemberCount <= 1) {
      await AppFeedback.showError(
        context,
        title: 'Tiny bubble alert',
        message:
            'This bubble is still a solo mission. Add members first, then fire up bubble mode together.',
        actionLabel: 'Add members',
        onAction: () => _openExpandedChatView(bubble),
      );
      return;
    }

    final bubbleModeProvider =
        Provider.of<BubbleModeProvider>(context, listen: false);
    final navigationProvider =
        Provider.of<NavigationProvider>(context, listen: false);

    bubbleModeProvider.requestBubbleMode(bubble);
    navigationProvider.navigateToTab(0);

    AppFeedback.showSuccess(
      context,
      message: 'Activating ${bubble.name}…',
      leading: const Icon(
        Icons.bubble_chart_rounded,
        color: PinitColors.cream,
        size: 18,
      ),
      duration: const Duration(seconds: 2),
    );
  }

  Future<bool> _confirmAndDeleteBubble(
    BubblesProvider bubblesProvider,
    Bubble bubble,
  ) async {
    if (bubble.createdBy != bubblesProvider.userId) {
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: PinitColors.cream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: PinitColors.aubergine, width: 1.5),
          ),
          title: Text(
            'Delete bubble?',
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w800,
              color: PinitColors.aubergine,
            ),
          ),
          content: Text(
            'This removes the bubble from your list. If you created it, it will be deleted for everyone.',
            style: GoogleFonts.dmSans(
              color: PinitColors.mute,
              height: 1.35,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  color: PinitColors.aubergineSoft,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Delete',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w900,
                  color: PinitColors.accent,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return false;

    final ok = await bubblesProvider.deleteOrLeaveBubble(bubble.id);
    if (!ok && mounted) {
      await AppFeedback.showError(
        context,
        title: "Couldn't delete bubble",
        message: 'Please try again.',
      );
    }
    return ok;
  }

  Future<bool> _promptAndRenameBubble(
    BubblesProvider bubblesProvider,
    Bubble bubble,
  ) async {
    if (bubble.createdBy != bubblesProvider.userId) {
      return false;
    }

    final controller = TextEditingController(text: bubble.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: PinitColors.cream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: PinitColors.aubergine, width: 1.5),
          ),
          title: Text(
            'Rename bubble',
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w800,
              color: PinitColors.aubergine,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            style: GoogleFonts.dmSans(
              color: PinitColors.aubergine,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: 'Bubble name',
              hintStyle: GoogleFonts.dmSans(color: PinitColors.mute),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: PinitColors.creamDeep),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: PinitColors.aubergine),
              ),
            ),
            onSubmitted: (value) =>
                Navigator.of(dialogContext).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: Text(
                'Cancel',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  color: PinitColors.aubergineSoft,
                ),
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: Text(
                'Save',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w900,
                  color: PinitColors.aubergine,
                ),
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();

    final trimmed = (newName ?? '').trim();
    if (trimmed.isEmpty || !mounted) return false;
    if (trimmed == bubble.name.trim()) return true;

    final ok = await bubblesProvider.renameBubble(bubble.id, trimmed);
    if (!ok && mounted) {
      await AppFeedback.showError(
        context,
        title: "Couldn't rename bubble",
        message: 'Please try again.',
      );
    }
    return ok;
  }

  ThemeData get theme => Theme.of(context);

  Widget _buildSearchField(ThemeData theme) {
    final bool isSearching =
        _searchFocusNode.hasFocus || _searchController.text.isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(isSearching ? 8 : 20, 8, 20, 8),
      child: Row(
        children: [
          if (isSearching) ...[
            GestureDetector(
              onTap: () {
                _searchController.clear();
                _searchFocusNode.unfocus();
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Icon(Icons.arrow_back_rounded,
                    color: PinitColors.aubergine, size: 22),
              ),
            ),
          ],
          Expanded(
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
                      focusNode: _searchFocusNode,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: PinitColors.aubergine,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 16),
                        border: InputBorder.none,
                        hintText: 'SEARCH USERS',
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
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _searchFocusNode.unfocus();
                      },
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
        ],
      ),
    );
  }

  Widget _buildSearchResults(ThemeData theme, List<Bubble> bubbles) {
    if (_searchController.text.isEmpty) {
      return BubbleDiscoverView(
        bubbles: bubbles,
        onBubbleTap: _openExpandedChatView,
        onUserTap: _showUserProfileDialog,
      );
    }

    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(PinitColors.aubergine),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Searching...',
              style: GoogleFonts.dmSans(color: PinitColors.mute),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: PinitColors.creamSunk,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_search_rounded,
                  size: 48, color: PinitColors.mute),
            ),
            const SizedBox(height: 20),
            Text(
              'No users found',
              style: GoogleFonts.dmSans(
                color: PinitColors.aubergine,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: GoogleFonts.dmSans(color: PinitColors.mute),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: UserCard(
            user: user,
            onTap: (u) {
              _searchFocusNode.unfocus();
              _showUserProfileDialog(u);
            },
          ),
        );
      },
    );
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.trim().isNotEmpty) {
        _performSearch(_searchController.text.trim());
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    });
  }

  void _onFocusChanged() {
    setState(() {});
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
    });

    try {
      final supabaseProvider =
          Provider.of<SupabaseService>(context, listen: false);
      final results = await supabaseProvider.searchUsers(query);

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      print('Error searching users: $e');
    }
  }

  void _showUserProfileDialog(UserModel user) {
    final userKey = user.supabaseId ?? user.email;
    unawaited(
      RouteOpenGuard.run<void>(
        'other-user-profile:$userKey',
        () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => OtherUserProfilePage(user: user),
          ),
        ),
      ),
    );
  }
}
